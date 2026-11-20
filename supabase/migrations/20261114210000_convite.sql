-- Migration 12: convites (gerar e resgatar).
-- RODE SOMENTE DEPOIS de ver o teste 011 falhar (vermelho).
--
-- Fluxo: o admin gera um código e o entrega ao coroinha (pelo WhatsApp, por
-- exemplo). O coroinha entra com a conta Google e digita o código; a função
-- resgatar_convite cria o perfil dele. O login prova QUEM é a pessoa, e o
-- convite prova que ela PODE entrar.

-- Para o hash (SHA-256) e para sortear o código com aleatoriedade segura.
create extension if not exists pgcrypto with schema extensions;

-- ---------- Tabela ----------
-- Só o HASH do código é guardado: quem lê o banco não consegue usar um
-- convite pendente. O código em texto existe uma única vez, na resposta de
-- gerar_convite().

create table public.convites (
  id          uuid primary key default gen_random_uuid(),
  codigo_hash text not null unique,
  -- "on delete set null": apagar um perfil (admin ou coroinha) nunca pode
  -- ser bloqueado só porque ele aparece num registro de convite.
  criado_por  uuid references public.perfis (id) on delete set null,
  criado_em   timestamptz not null default now(),
  expira_em   timestamptz not null,
  usado_em    timestamptz,
  usado_por   uuid references public.perfis (id) on delete set null
);

alter table public.convites enable row level security;

-- Só o admin lê (e só vê o hash, nunca o código).
create policy convites_leitura on public.convites
  for select to authenticated
  using ((select public.eh_admin()));

-- ---------- Hash do código (função interna) ----------
-- Normaliza antes de calcular: ignora espaços nas pontas e maiúsculas/
-- minúsculas, porque digitar um código no celular costuma errar isso.

create function public.hash_convite(p_codigo text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(extensions.digest(upper(btrim(p_codigo)), 'sha256'), 'hex');
$$;

-- Função interna: ninguém de fora precisa chamá-la.
revoke execute on function public.hash_convite(text) from public, anon, authenticated;

-- ---------- gerar_convite ----------

create function public.gerar_convite()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- 32 símbolos, sem 0/O nem 1/I, para ninguém errar ao digitar no celular.
  -- 256 é múltiplo de 32, então "byte % 32" sorteia todos com a mesma chance.
  v_alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes    bytea := extensions.gen_random_bytes(8);
  v_codigo   text := '';
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  for i in 0..7 loop
    v_codigo := v_codigo || substr(v_alfabeto, (get_byte(v_bytes, i) % 32) + 1, 1);
  end loop;

  insert into public.convites (codigo_hash, criado_por, expira_em)
  values (public.hash_convite(v_codigo), auth.uid(), now() + interval '7 days');

  return v_codigo;
end;
$$;

-- ---------- resgatar_convite ----------
-- Quem resgata vem do login (auth.uid()). Cria três coisas de uma vez, numa
-- transação só: o perfil, os dados do responsável e a marca de "usado".

create function public.resgatar_convite(
  p_codigo           text,
  p_nome             text,
  p_responsavel_nome text
)
returns public.perfis
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_convite public.convites;
  v_perfil  public.perfis;
begin
  -- 1º: precisa estar logado.
  if v_uid is null then
    raise exception 'NAO_AUTORIZADO';
  end if;

  -- 2º: quem já tem perfil não resgata outro convite.
  if exists (select 1 from public.perfis p where p.id = v_uid) then
    raise exception 'JA_TEM_PERFIL';
  end if;

  -- 3º: o convite. "for update" impede que dois resgates simultâneos do
  -- mesmo código passem os dois.
  select c.*
    into v_convite
    from public.convites c
   where c.codigo_hash = public.hash_convite(p_codigo)
     for update;

  if not found then
    raise exception 'CONVITE_INVALIDO';
  end if;
  if v_convite.usado_em is not null then
    raise exception 'CONVITE_USADO';
  end if;
  if v_convite.expira_em <= now() then
    raise exception 'CONVITE_EXPIRADO';
  end if;

  -- 4º: dados informados. Vêm DEPOIS de conferir o convite e ANTES de
  -- gastá-lo: um nome vazio não queima o convite de ninguém.
  if p_nome is null or btrim(p_nome) = '' then
    raise exception 'NOME_INVALIDO';
  end if;
  if p_responsavel_nome is null or btrim(p_responsavel_nome) = '' then
    raise exception 'RESPONSAVEL_OBRIGATORIO';
  end if;

  insert into public.perfis (id, nome)
  values (v_uid, btrim(p_nome))
  returning * into v_perfil;

  insert into public.dados_responsavel (perfil_id, responsavel_nome)
  values (v_uid, btrim(p_responsavel_nome));

  update public.convites
     set usado_em = now(),
         usado_por = v_uid
   where id = v_convite.id;

  return v_perfil;
end;
$$;

revoke execute on function public.gerar_convite() from public, anon;
grant  execute on function public.gerar_convite() to authenticated;

revoke execute on function public.resgatar_convite(text, text, text) from public, anon;
grant  execute on function public.resgatar_convite(text, text, text) to authenticated;
