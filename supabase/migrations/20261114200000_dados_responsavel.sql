-- Migration 10 (esqueleto): tabela dos dados do responsável.
-- Só a tabela, com RLS ligada e SEM políticas: ninguém lê pelo app ainda.
-- As políticas entram depois que o teste 010 falhar.
--
-- Guarda o mínimo necessário (princípio da minimização da LGPD): o nome de
-- quem autorizou e quando. Sem telefone, endereço ou data de nascimento.
-- Rode UMA vez no SQL Editor do projeto escala-dev.

create table public.dados_responsavel (
  perfil_id        uuid primary key references public.perfis (id) on delete cascade,
  responsavel_nome text not null,
  consentimento_em timestamptz not null default now()
);

alter table public.dados_responsavel enable row level security;
