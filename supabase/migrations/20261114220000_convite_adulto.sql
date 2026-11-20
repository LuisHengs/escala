-- Migration 13: o convite pode dispensar o responsável (para adultos).
-- RODE SOMENTE DEPOIS de ver o teste 012 falhar (vermelho).
--
-- ATENÇÃO: o teste 011 ANTIGO passa a falhar no V9 depois desta migration
-- (a assinatura de gerar_convite muda). Use a versão nova do 011.

-- ---------- Nova coluna ----------
-- O padrão é EXIGIR: se alguém esquecer de decidir, o erro cai do lado que
-- protege (pedir o responsável a mais, e não a menos).

alter table public.convites
  add column exige_responsavel boolean not null default true;

-- ---------- gerar_convite com parâmetro ----------
-- A assinatura muda (agora recebe um boolean), então a função antiga é
-- removida e recriada. As chamadas antigas, gerar_convite() sem argumento,
-- continuam funcionando por causa do valor padrão.

drop function public.gerar_convite();

create function public.gerar_convite(p_exige_responsavel boolean default true)
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

  insert into public.convites (codigo_hash, criado_por, expira_em, exige_responsavel)
  values (
    public.hash_convite(v_codigo),
    auth.uid(),
    now() + interval '7 days',
    coalesce(p_exige_responsavel, true) -- nulo conta como "exige"
  );

  return v_codigo;
end;
$$;

revoke execute on function public.gerar_convite(boolean) from public, anon;
grant  execute on function public.gerar_convite(boolean) to authenticated;

-- ---------- resgatar_convite: responsável só quando o convite exige ----------
-- Mesma assinatura de antes, por isso "create or replace".

create or replace function public.resgatar_convite(
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
  -- gastá-lo: um erro de preenchimento não queima o convite de ninguém.
  if p_nome is null or btrim(p_nome) = '' then
    raise exception 'NOME_INVALIDO';
  end if;
  if v_convite.exige_responsavel
     and (p_responsavel_nome is null or btrim(p_responsavel_nome) = '') then
    raise exception 'RESPONSAVEL_OBRIGATORIO';
  end if;

  insert into public.perfis (id, nome)
  values (v_uid, btrim(p_nome))
  returning * into v_perfil;

  -- Só se guarda o responsável quando ele é exigido. Se o convite não exige
  -- (adulto), o que vier no parâmetro é ignorado: dado desnecessário não
  -- entra no banco.
  if v_convite.exige_responsavel then
    insert into public.dados_responsavel (perfil_id, responsavel_nome)
    values (v_uid, btrim(p_responsavel_nome));
  end if;

  update public.convites
     set usado_em = now(),
         usado_por = v_uid
   where id = v_convite.id;

  return v_perfil;
end;
$$;
