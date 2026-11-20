-- Migration 1: esqueleto do banco (fase vermelha do TDD).
-- Cria as tabelas e o cálculo do "periodo", mas AINDA NÃO a restrição de
-- conflito de horário. Ela só entra depois que o teste falhar.
--
-- Rode UMA vez no SQL Editor do projeto escala-dev.

-- ---------- Tabelas ----------

create table public.locais (
  id   uuid primary key default gen_random_uuid(),
  nome text not null unique
);

create table public.perfis (
  id    uuid primary key references auth.users (id) on delete cascade,
  nome  text not null,
  papel text not null default 'coroinha'
        check (papel in ('admin', 'coroinha')),
  ativo boolean not null default true
);

create table public.missas (
  id       uuid primary key default gen_random_uuid(),
  inicio   timestamptz not null,
  local_id uuid not null references public.locais (id)
);

create table public.escalacoes (
  id                    uuid primary key default gen_random_uuid(),
  missa_id              uuid not null references public.missas (id) on delete cascade,
  coroinha_id           uuid not null references public.perfis (id),
  funcao                text not null,
  status                text not null default 'pendente'
                        check (status in ('pendente', 'confirmado')),
  confirmado_com_atraso boolean not null default false,
  -- Intervalo [inicio, inicio + 1h). Preenchido pelo gatilho abaixo.
  periodo               tstzrange not null
);

-- ---------- Cálculo do periodo ----------
-- Não dá para ser coluna "gerada": ela precisaria ler a tabela de missas.
-- A duração (1 hora) é a mesma constante duracaoMissa do código Dart.

create function public.definir_periodo_escalacao()
returns trigger
language plpgsql
as $$
begin
  new.periodo := (
    select tstzrange(m.inicio, m.inicio + interval '1 hour')
    from public.missas m
    where m.id = new.missa_id
  );
  return new;
end;
$$;

create trigger escalacoes_definir_periodo
before insert or update of missa_id on public.escalacoes
for each row execute function public.definir_periodo_escalacao();

-- ---------- Segurança ----------
-- RLS ligada em TODAS as tabelas. Sem nenhuma política, o app (chave pública)
-- não enxerga nada. As políticas de acesso entram numa etapa própria, com
-- testes. O SQL Editor continua funcionando, pois roda como dono do banco.

alter table public.locais     enable row level security;
alter table public.perfis     enable row level security;
alter table public.missas     enable row level security;
alter table public.escalacoes enable row level security;
