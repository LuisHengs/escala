-- Migration 9: aceitar_troca.
-- RODE SOMENTE DEPOIS de ver o teste 009 falhar (vermelho).
--
-- Quem aceita é SEMPRE quem está logado (auth.uid()): ninguém aceita uma
-- troca "em nome de" outra pessoa. No Dart, substitutoId era um parâmetro.

create function public.aceitar_troca(p_troca_id uuid)
returns public.trocas
language plpgsql
security definer      -- roda com os poderes do dono, ignorando a RLS
set search_path = ''  -- por isso TODO nome abaixo precisa do prefixo public.
as $$
declare
  v_uid       uuid := auth.uid();
  v_troca     public.trocas;
  v_escalacao public.escalacoes;
  v_inicio    timestamptz;
begin
  -- "for update" trava a troca: de dois aceites simultâneos, o segundo espera
  -- o primeiro terminar e então enxerga a troca já aceita ("o primeiro vence").
  select t.*
    into v_troca
    from public.trocas t
   where t.id = p_troca_id
     for update;

  -- 1º: existe?
  if not found then
    raise exception 'TROCA_NAO_ENCONTRADA';
  end if;

  -- 2º: permissão. Precisa ter perfil ativo, ou seja, ter passado pelo
  -- convite. Sem login, v_uid é nulo e cai aqui também. Vem antes do estado:
  -- quem está de fora não descobre o que aconteceu com a troca.
  if not exists (
    select 1
    from public.perfis p
    where p.id = v_uid
      and p.ativo
  ) then
    raise exception 'NAO_AUTORIZADO';
  end if;

  -- 3º: a troca precisa estar aberta (aceita ou cancelada não volta).
  if v_troca.status <> 'aberta' then
    raise exception 'TROCA_JA_RESOLVIDA';
  end if;

  -- Trava também a escalação (a mesma que abrir_troca trava).
  select e.*
    into v_escalacao
    from public.escalacoes e
   where e.id = v_troca.escalacao_id
     for update;

  -- 4º: a missa não pode ter começado.
  select m.inicio into v_inicio
    from public.missas m
   where m.id = v_escalacao.missa_id;

  if now() >= v_inicio then
    raise exception 'MISSA_JA_COMECOU';
  end if;

  -- 5º: o titular não pode ser o próprio substituto. Vem ANTES da
  -- disponibilidade, senão ele receberia "já está nesta missa".
  if v_escalacao.coroinha_id = v_uid then
    raise exception 'SUBSTITUTO_INVALIDO';
  end if;

  -- 6º: o substituto não pode já estar nesta missa (mesma ordem do escalar:
  -- vem ANTES do conflito de horário, que a mesma missa também dispararia).
  if exists (
    select 1
    from public.escalacoes e
    where e.missa_id = v_escalacao.missa_id
      and e.coroinha_id = v_uid
  ) then
    raise exception 'JA_ESCALADO_NA_MISSA';
  end if;

  -- 7º: transferir a escalação. Quem GARANTE o conflito de horário é a
  -- restrição de exclusão da tabela (vale até para aceites simultâneos de
  -- trocas diferentes pelo mesmo substituto); aqui só traduzimos o erro.
  -- Aceitar já confirma a presença, e o atraso usa a mesma regra do prazo.
  begin
    update public.escalacoes
       set coroinha_id = v_uid,
           status = 'confirmado',
           confirmado_com_atraso = public.passou_do_prazo(v_inicio, now())
     where id = v_escalacao.id;
  exception
    when exclusion_violation then
      raise exception 'CONFLITO_DE_HORARIO';
  end;

  -- 8º: registrar o aceite. Tudo isto roda numa transação só: ou a
  -- escalação muda E a troca fica aceita, ou nada muda.
  update public.trocas
     set status = 'aceita',
         substituto_id = v_uid,
         resolvida_em = now()
   where id = p_troca_id
  returning * into v_troca;

  return v_troca;
end;
$$;

revoke execute on function public.aceitar_troca(uuid) from public, anon;
grant  execute on function public.aceitar_troca(uuid) to authenticated;
