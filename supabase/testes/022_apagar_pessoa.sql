-- Testes AP1 a AP6: apagar uma pessoa que deixou de participar (LGPD).
--   [AP1] coroinha comum não apaga ninguém (NAO_AUTORIZADO, nada some)
--   [AP2] pessoa inexistente -> PERFIL_INEXISTENTE
--   [AP3] pessoa ATIVA não é apagada (PESSOA_ATIVA): é preciso desativar antes
--   [AP4] admin apaga pessoa inativa: some o perfil, o login, o consentimento
--        do responsável, as escalações dela (e as trocas delas) e as trocas
--        em que ela foi a substituta
--   [AP5] nada de outras pessoas é afetado (perfil, escalação de quem pediu a
--        troca em que ela foi substituta, quem está ativo)
--   [AP6] anon não executa; authenticated executa
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

create or replace function pg_temp.tentar(p_sql text, p_uid uuid)
returns text
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
  execute p_sql;
  reset role;
  return null;
exception
  when others then
    reset role;
    return sqlerrm;
end;
$$;

do $$
declare
  v_adm    uuid := gen_random_uuid();
  v_ana    uuid := gen_random_uuid(); -- inativa, com histórico (será apagada)
  v_bia    uuid := gen_random_uuid(); -- ativa
  v_carla  uuid := gen_random_uuid(); -- ativa
  v_fant   uuid := gen_random_uuid();
  v_local  uuid := gen_random_uuid();
  v_m1     uuid := gen_random_uuid();
  v_m2     uuid := gen_random_uuid();
  v_e_ana  uuid;
  v_e_bia  uuid;
  v_erro   text;
  v_qtd    int;
begin
  insert into auth.users (id) values (v_adm), (v_ana), (v_bia), (v_carla);
  insert into public.perfis (id, nome, papel, ativo) values
    (v_adm,   'Coordenador (teste)', 'admin',    true),
    (v_ana,   'Ana (teste)',         'coroinha', false),
    (v_bia,   'Bia (teste)',         'coroinha', true),
    (v_carla, 'Carla (teste)',       'coroinha', true);
  insert into public.dados_responsavel (perfil_id, responsavel_nome)
    values (v_ana, 'Responsável da Ana (teste)');
  insert into public.locais (id, nome) values (v_local, 'Local (teste ap)');
  insert into public.missas (id, inicio, local_id) values
    (v_m1, '2036-11-22 18:00:00-03', v_local),
    (v_m2, '2036-11-23 18:00:00-03', v_local);
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m1, v_ana, 'turiferário') returning id into v_e_ana;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m2, v_bia, 'cruciferário') returning id into v_e_bia;
  -- Uma troca aberta na escalação da Ana e uma troca da Bia que a Ana aceitou.
  insert into public.trocas (escalacao_id) values (v_e_ana);
  insert into public.trocas (escalacao_id, status, substituto_id, resolvida_em)
    values (v_e_bia, 'aceita', v_ana, now());

  -- ---------- AP1: coroinha comum ----------
  v_erro := pg_temp.tentar(format('select public.apagar_pessoa(%L)', v_ana), v_bia);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [AP1]: coroinha apagando deveria dar NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  select count(*) into v_qtd from public.perfis where id = v_ana;
  if v_qtd <> 1 then
    raise exception 'FALHOU [AP1]: a pessoa não deveria ter sido apagada';
  end if;

  -- ---------- AP2: pessoa inexistente ----------
  v_erro := pg_temp.tentar(format('select public.apagar_pessoa(%L)', v_fant), v_adm);
  if v_erro is distinct from 'PERFIL_INEXISTENTE' then
    raise exception 'FALHOU [AP2]: pessoa inexistente deveria dar PERFIL_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- AP3: pessoa ativa ----------
  v_erro := pg_temp.tentar(format('select public.apagar_pessoa(%L)', v_carla), v_adm);
  if v_erro is distinct from 'PESSOA_ATIVA' then
    raise exception 'FALHOU [AP3]: pessoa ativa deveria dar PESSOA_ATIVA, mas veio: %',
      coalesce(v_erro, '(nenhum erro: a pessoa ativa foi apagada)');
  end if;
  select count(*) into v_qtd from public.perfis where id = v_carla;
  if v_qtd <> 1 then
    raise exception 'FALHOU [AP3]: a pessoa ativa deveria continuar existindo';
  end if;

  -- ---------- AP4: admin apaga pessoa inativa ----------
  v_erro := pg_temp.tentar(format('select public.apagar_pessoa(%L)', v_ana), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [AP4]: o admin deveria conseguir apagar a pessoa inativa, mas veio: %', v_erro;
  end if;
  select count(*) into v_qtd from public.perfis where id = v_ana;
  if v_qtd <> 0 then
    raise exception 'FALHOU [AP4]: o perfil deveria ter sido apagado';
  end if;
  select count(*) into v_qtd from auth.users where id = v_ana;
  if v_qtd <> 0 then
    raise exception 'FALHOU [AP4]: o login (auth.users) deveria ter sido apagado';
  end if;
  select count(*) into v_qtd from public.dados_responsavel where perfil_id = v_ana;
  if v_qtd <> 0 then
    raise exception 'FALHOU [AP4]: os dados do responsável deveriam ter sido apagados';
  end if;
  select count(*) into v_qtd from public.escalacoes where coroinha_id = v_ana;
  if v_qtd <> 0 then
    raise exception 'FALHOU [AP4]: as escalações da pessoa deveriam ter sido apagadas';
  end if;
  select count(*) into v_qtd from public.trocas
   where escalacao_id = v_e_ana or substituto_id = v_ana;
  if v_qtd <> 0 then
    raise exception 'FALHOU [AP4]: as trocas da pessoa (e as que ela aceitou) deveriam ter sido apagadas, mas há %', v_qtd;
  end if;

  -- ---------- AP5: ninguém mais foi afetado ----------
  select count(*) into v_qtd from public.perfis where id in (v_adm, v_bia, v_carla);
  if v_qtd <> 3 then
    raise exception 'FALHOU [AP5]: os outros perfis deveriam continuar, mas só há %', v_qtd;
  end if;
  select count(*) into v_qtd from public.escalacoes where id = v_e_bia;
  if v_qtd <> 1 then
    raise exception 'FALHOU [AP5]: a escalação da Bia deveria continuar existindo';
  end if;

  -- ---------- AP6: direitos de execução ----------
  if has_function_privilege('anon', 'public.apagar_pessoa(uuid)', 'execute') then
    raise exception 'FALHOU [AP6]: anon não deveria executar apagar_pessoa';
  end if;
  if not has_function_privilege('authenticated', 'public.apagar_pessoa(uuid)', 'execute') then
    raise exception 'FALHOU [AP6]: authenticated deveria executar apagar_pessoa';
  end if;

  -- Limpeza
  delete from public.trocas where escalacao_id = v_e_bia;
  delete from public.escalacoes where id = v_e_bia;
  delete from public.missas where id in (v_m1, v_m2);
  delete from public.locais where id = v_local;
  delete from public.perfis where id in (v_adm, v_bia, v_carla);
  delete from auth.users where id in (v_adm, v_bia, v_carla);
end;
$$;
