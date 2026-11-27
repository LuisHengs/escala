-- Testes LR1 a LR6: renomear e remover local.
--   [LR1] coroinha comum não renomeia nem remove (NAO_AUTORIZADO, nada muda)
--   [LR2] admin renomeia; o nome é gravado sem espaços nas pontas
--   [LR3] renomear: nome vazio -> NOME_INVALIDO; local inexistente ->
--        LOCAL_INEXISTENTE; nome de OUTRO local (em qualquer caixa) ->
--        LOCAL_DUPLICADO; mudar só a caixa do próprio nome é permitido
--   [LR4] admin remove local sem missas; local inexistente -> LOCAL_INEXISTENTE
--   [LR5] local com missa -> LOCAL_EM_USO (o local continua existindo)
--   [LR6] anon não executa as duas funções; authenticated executa
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
  v_adm   uuid := gen_random_uuid();
  v_ana   uuid := gen_random_uuid();
  v_a     uuid := gen_random_uuid();
  v_b     uuid := gen_random_uuid();
  v_c     uuid := gen_random_uuid();
  v_fant  uuid := gen_random_uuid();
  v_erro  text;
  v_nome  text;
  v_qtd   int;
begin
  insert into auth.users (id) values (v_adm), (v_ana);
  insert into public.perfis (id, nome, papel) values
    (v_adm, 'Coordenador (teste)', 'admin'),
    (v_ana, 'Ana (teste)', 'coroinha');
  insert into public.locais (id, nome) values
    (v_a, 'Local A (teste lr)'),
    (v_b, 'Local B (teste lr)'),
    (v_c, 'Local C (teste lr)');
  insert into public.missas (inicio, local_id)
  values ('2036-11-22 18:00:00-03', v_b);

  -- ---------- LR1: coroinha comum ----------
  v_erro := pg_temp.tentar(format('select public.renomear_local(%L, %L)', v_a, 'Outro nome (teste lr)'), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [LR1]: renomear por coroinha deveria dar NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.remover_local(%L)', v_a), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [LR1]: remover por coroinha deveria dar NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  select nome into v_nome from public.locais where id = v_a;
  if v_nome is distinct from 'Local A (teste lr)' then
    raise exception 'FALHOU [LR1]: o local deveria continuar "Local A (teste lr)", mas está: %', coalesce(v_nome, '(removido)');
  end if;

  -- ---------- LR2: admin renomeia ----------
  v_erro := pg_temp.tentar(format('select public.renomear_local(%L, %L)', v_a, '  Capela Nova (teste lr)  '), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [LR2]: o admin deveria conseguir renomear, mas veio: %', v_erro;
  end if;
  select nome into v_nome from public.locais where id = v_a;
  if v_nome is distinct from 'Capela Nova (teste lr)' then
    raise exception 'FALHOU [LR2]: o nome deveria ser "Capela Nova (teste lr)" (sem espaços), mas está: %', v_nome;
  end if;

  -- ---------- LR3: validações ----------
  v_erro := pg_temp.tentar(format('select public.renomear_local(%L, %L)', v_a, '   '), v_adm);
  if v_erro is distinct from 'NOME_INVALIDO' then
    raise exception 'FALHOU [LR3]: nome em branco deveria dar NOME_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.renomear_local(%L, %L)', v_fant, 'Qualquer (teste lr)'), v_adm);
  if v_erro is distinct from 'LOCAL_INEXISTENTE' then
    raise exception 'FALHOU [LR3]: local inexistente deveria dar LOCAL_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.renomear_local(%L, %L)', v_a, 'LOCAL B (TESTE LR)'), v_adm);
  if v_erro is distinct from 'LOCAL_DUPLICADO' then
    raise exception 'FALHOU [LR3]: nome de outro local (outra caixa) deveria dar LOCAL_DUPLICADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.renomear_local(%L, %L)', v_a, 'CAPELA NOVA (TESTE LR)'), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [LR3]: mudar só a caixa do próprio nome deveria ser aceito, mas veio: %', v_erro;
  end if;

  -- ---------- LR4: remover local sem missas ----------
  v_erro := pg_temp.tentar(format('select public.remover_local(%L)', v_c), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [LR4]: o admin deveria conseguir remover o local sem missas, mas veio: %', v_erro;
  end if;
  select count(*) into v_qtd from public.locais where id = v_c;
  if v_qtd <> 0 then
    raise exception 'FALHOU [LR4]: o local removido ainda existe';
  end if;
  v_erro := pg_temp.tentar(format('select public.remover_local(%L)', v_fant), v_adm);
  if v_erro is distinct from 'LOCAL_INEXISTENTE' then
    raise exception 'FALHOU [LR4]: remover local inexistente deveria dar LOCAL_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- LR5: local com missa ----------
  v_erro := pg_temp.tentar(format('select public.remover_local(%L)', v_b), v_adm);
  if v_erro is distinct from 'LOCAL_EM_USO' then
    raise exception 'FALHOU [LR5]: local com missa deveria dar LOCAL_EM_USO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  select count(*) into v_qtd from public.locais where id = v_b;
  if v_qtd <> 1 then
    raise exception 'FALHOU [LR5]: o local com missa deveria continuar existindo';
  end if;

  -- ---------- LR6: direitos de execução ----------
  if has_function_privilege('anon', 'public.renomear_local(uuid, text)', 'execute')
     or has_function_privilege('anon', 'public.remover_local(uuid)', 'execute') then
    raise exception 'FALHOU [LR6]: anon não deveria executar renomear_local/remover_local';
  end if;
  if not has_function_privilege('authenticated', 'public.renomear_local(uuid, text)', 'execute')
     or not has_function_privilege('authenticated', 'public.remover_local(uuid)', 'execute') then
    raise exception 'FALHOU [LR6]: authenticated deveria executar renomear_local e remover_local';
  end if;

  -- Limpeza
  delete from public.missas where local_id = v_b;
  delete from public.locais where id in (v_a, v_b, v_c);
  delete from public.perfis where id in (v_adm, v_ana);
  delete from auth.users where id in (v_adm, v_ana);
end;
$$;

