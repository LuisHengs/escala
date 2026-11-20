-- Migration 7: tabela de trocas e a função abrir_troca.
-- RODE SOMENTE DEPOIS de ver o teste 007 falhar (vermelho).

-- ---------- Tabela ----------

create table public.trocas (
  id           uuid primary key default gen_random_uuid(),
  escalacao_id uuid not null
               references public.escalacoes (id) on delete cascade,
  status       text not null default 'aberta'
               check (status in ('aberta', 'aceita', 'cancelada')),
  substituto_id uuid references public.perfis (id),
  criada_em    timestamptz not null default now(),
  resolvida_em timestamptz,
  -- Coerência: só uma troca ACEITA tem substituto, e toda aceita tem.
  check ((status = 'aceita') = (substituto_id is not null))
);

-- Uma única troca ABERTA por escalação. Este índice é a garantia do banco
-- (teste 15 do Dart): o estado "duas trocas abertas" simplesmente não existe.
-- Trocas aceitas ou canceladas não contam, por isso o "where".
create unique index trocas_uma_aberta_por_escalacao
  on public.trocas (escalacao_id)
  where status = 'aberta';

-- RLS ligada, sem políticas por enquanto (o app ainda não lê esta tabela).
alter table public.trocas enable row level security;

-- ---------- abrir_troca ----------
-- Quem abre vem do login (auth.uid()), nunca de um parâmetro.

create function public.abrir_troca(p_escalacao_id uuid)
returns public.trocas
language plpgsql
security definer      -- roda com os poderes do dono, ignorando a RLS
set search_path = ''  -- por isso TODO nome abaixo precisa do prefixo public.
as $$
declare
  v_escalacao public.escalacoes;
  v_inicio    timestamptz;
  v_troca     public.trocas;
begin
  -- "for update" trava a escalação: dois pedidos do mesmo titular ao mesmo
  -- tempo passam um de cada vez.
  select e.*
    into v_escalacao
    from public.escalacoes e
   where e.id = p_escalacao_id
     for update;

  -- 1º: existe?
  if not found then
    raise exception 'ESCALACAO_NAO_ENCONTRADA';
  end if;

  -- 2º: só o titular abre. Sem login, auth.uid() é nulo e cai aqui também.
  if v_escalacao.coroinha_id is distinct from auth.uid() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  -- 3º: a missa não pode ter começado.
  select m.inicio into v_inicio
    from public.missas m
   where m.id = v_escalacao.missa_id;

  if now() >= v_inicio then
    raise exception 'MISSA_JA_COMECOU';
  end if;

  -- 4º: só uma troca aberta por escalação.
  if exists (
    select 1
    from public.trocas t
    where t.escalacao_id = p_escalacao_id
      and t.status = 'aberta'
  ) then
    raise exception 'TROCA_JA_ABERTA';
  end if;

  -- O índice único é a rede de segurança; aqui só traduzimos o erro.
  begin
    insert into public.trocas (escalacao_id)
    values (p_escalacao_id)
    returning * into v_troca;
  exception
    when unique_violation then
      raise exception 'TROCA_JA_ABERTA';
  end;

  return v_troca;
end;
$$;

revoke execute on function public.abrir_troca(uuid) from public, anon;
grant  execute on function public.abrir_troca(uuid) to authenticated;
