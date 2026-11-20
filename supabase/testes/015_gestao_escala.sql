-- Testes E1 a E5: o admin corrige a escala e gere membros e missas.
--   [E1] desescalar: só admin; escalação inexistente; missa que já começou é
--        BLOQUEADA (preserva o histórico); missa futura: remove (e leva junto
--        as trocas daquela escalação)
--   [E2] definir_ativo: só admin; perfil inexistente; valor nulo; desativar
--        quem tem missa FUTURA é bloqueado (desescale antes); reativar
--   [E3] remover_missa: só admin; inexistente; com escalados é bloqueado;
--        sem escalados remove
--   [E4] definir_papel: só admin; papel inválido; o ÚLTIMO admin ativo não
--        pode ser rebaixado nem desativado; havendo outro admin, pode
--   [E5] anon não executa nenhuma das quatro funções; authenticated executa
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

-- Ajudante temporário: roda um comando SQL "como" um usuário logado e devolve
-- a mensagem de erro (ou nulo, se deu certo). Some quando a sessão termina.
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
  v_adm     uuid := gen_random_uuid();
  v_ana     uuid := gen_random_uuid();
  v_bia     uuid := gen_random_uuid();
  v_local   uuid := gen_random_uuid();
  v_mfut    uuid := gen_random_uuid();   -- missa futura
  v_mpas    uuid := gen_random_uuid();   -- missa que já começou
  v_mcom    uuid := gen_random_uuid();   -- missa futura COM escalado
  v_msem    uuid := gen_random_uuid();   -- missa futura SEM escalado
  v_e_fut   uuid;
  v_e_pas   uuid;
  v_e_com   uuid;
  v_outros  uuid[];
  v_erro    text;
  v_qtd     int;
  v_ativo   boolean;
  v_papel   text;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana), (v_bia);
  insert into public.perfis (id, nome, papel) values
    (v_adm, 'Coordenador (teste)', 'admin'),
    (v_ana, 'Ana (teste)',         'coroinha'),
    (v_bia, 'Bia (teste)',         'coroinha');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id) values
    (v_mfut, now() + interval '30 days',                    v_local),
    (v_mpas, now() - interval '2 days',                     v_local),
    (v_mcom, now() + interval '31 days',                    v_local),
    (v_msem, now() + interval '32 days',                    v_local);
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_mfut, v_ana, 'turiferário') returning id into v_e_fut;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_mpas, v_bia, 'cruciferário') returning id into v_e_pas;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_mcom, v_bia, 'acólito') returning id into v_e_com;
  -- Uma troca aberta na escalação futura da Ana (deve sumir junto).
  insert into public.trocas (escalacao_id) values (v_e_fut);

  -- ---------- E1: desescalar ----------
  v_erro := pg_temp.tentar(format('select public.desescalar(%L::uuid)', v_e_fut), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [E1]: coroinha comum deveria receber NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  select count(*) into v_qtd from public.escalacoes where id = v_e_fut;
  if v_qtd <> 1 then
    raise exception 'FALHOU [E1]: a escalação não deveria ter sido removida pelo coroinha';
  end if;

  v_erro := pg_temp.tentar(format('select public.desescalar(%L::uuid)', gen_random_uuid()), v_adm);
  if v_erro is distinct from 'ESCALACAO_NAO_ENCONTRADA' then
    raise exception 'FALHOU [E1]: escalação inexistente deveria dar ESCALACAO_NAO_ENCONTRADA, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(format('select public.desescalar(%L::uuid)', v_e_pas), v_adm);
  if v_erro is distinct from 'MISSA_JA_COMECOU' then
    raise exception 'FALHOU [E1]: missa que já começou deveria dar MISSA_JA_COMECOU, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  select count(*) into v_qtd from public.escalacoes where id = v_e_pas;
  if v_qtd <> 1 then
    raise exception 'FALHOU [E1]: a escalação da missa passada deveria continuar (histórico)';
  end if;

  v_erro := pg_temp.tentar(format('select public.desescalar(%L::uuid)', v_e_fut), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [E1]: o admin deveria conseguir desescalar, mas veio o erro: %', v_erro;
  end if;
  select count(*) into v_qtd from public.escalacoes where id = v_e_fut;
  if v_qtd <> 0 then
    raise exception 'FALHOU [E1]: a escalação futura deveria ter sido removida';
  end if;
  select count(*) into v_qtd from public.trocas where escalacao_id = v_e_fut;
  if v_qtd <> 0 then
    raise exception 'FALHOU [E1]: as trocas da escalação removida deveriam sumir junto';
  end if;

  -- ---------- E2: definir_ativo ----------
  v_erro := pg_temp.tentar(format('select public.definir_ativo(%L::uuid, false)', v_bia), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [E2]: coroinha comum deveria receber NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(format('select public.definir_ativo(%L::uuid, false)', gen_random_uuid()), v_adm);
  if v_erro is distinct from 'PERFIL_INEXISTENTE' then
    raise exception 'FALHOU [E2]: perfil inexistente deveria dar PERFIL_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(format('select public.definir_ativo(%L::uuid, null)', v_ana), v_adm);
  if v_erro is distinct from 'VALOR_INVALIDO' then
    raise exception 'FALHOU [E2]: valor nulo deveria dar VALOR_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- A Bia tem missa futura (v_mcom): desativar é bloqueado.
  v_erro := pg_temp.tentar(format('select public.definir_ativo(%L::uuid, false)', v_bia), v_adm);
  if v_erro is distinct from 'TEM_ESCALACOES_FUTURAS' then
    raise exception 'FALHOU [E2]: desativar quem tem missa futura deveria dar TEM_ESCALACOES_FUTURAS, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  select ativo into v_ativo from public.perfis where id = v_bia;
  if not v_ativo then
    raise exception 'FALHOU [E2]: a Bia deveria continuar ativa após o bloqueio';
  end if;

  -- A Ana não tem mais missa futura (foi desescalada): desativar e reativar.
  v_erro := pg_temp.tentar(format('select public.definir_ativo(%L::uuid, false)', v_ana), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [E2]: o admin deveria conseguir desativar a Ana, mas veio o erro: %', v_erro;
  end if;
  select ativo into v_ativo from public.perfis where id = v_ana;
  if v_ativo then
    raise exception 'FALHOU [E2]: a Ana deveria estar inativa';
  end if;
  v_erro := pg_temp.tentar(format('select public.definir_ativo(%L::uuid, true)', v_ana), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [E2]: o admin deveria conseguir reativar a Ana, mas veio o erro: %', v_erro;
  end if;
  select ativo into v_ativo from public.perfis where id = v_ana;
  if not v_ativo then
    raise exception 'FALHOU [E2]: a Ana deveria estar ativa de novo';
  end if;

  -- ---------- E3: remover_missa ----------
  v_erro := pg_temp.tentar(format('select public.remover_missa(%L::uuid)', v_msem), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [E3]: coroinha comum deveria receber NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(format('select public.remover_missa(%L::uuid)', gen_random_uuid()), v_adm);
  if v_erro is distinct from 'MISSA_INEXISTENTE' then
    raise exception 'FALHOU [E3]: missa inexistente deveria dar MISSA_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(format('select public.remover_missa(%L::uuid)', v_mcom), v_adm);
  if v_erro is distinct from 'MISSA_COM_ESCALADOS' then
    raise exception 'FALHOU [E3]: missa com escalados deveria dar MISSA_COM_ESCALADOS, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  select count(*) into v_qtd from public.missas where id = v_mcom;
  if v_qtd <> 1 then
    raise exception 'FALHOU [E3]: a missa com escalados deveria continuar existindo';
  end if;

  v_erro := pg_temp.tentar(format('select public.remover_missa(%L::uuid)', v_msem), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [E3]: o admin deveria conseguir remover a missa vazia, mas veio o erro: %', v_erro;
  end if;
  select count(*) into v_qtd from public.missas where id = v_msem;
  if v_qtd <> 0 then
    raise exception 'FALHOU [E3]: a missa vazia deveria ter sido removida';
  end if;

  -- ---------- E4: definir_papel e o último admin ----------
  -- Para o teste ser previsível mesmo num banco com admins de verdade, os
  -- outros admins ficam inativos só aqui dentro e são reativados no fim.
  select coalesce(array_agg(id), '{}') into v_outros
    from public.perfis where papel = 'admin' and ativo and id <> v_adm;
  update public.perfis set ativo = false where id = any(v_outros);

  v_erro := pg_temp.tentar(format('select public.definir_papel(%L::uuid, %L)', v_bia, 'admin'), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [E4]: coroinha comum deveria receber NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(format('select public.definir_papel(%L::uuid, %L)', v_ana, 'chefe'), v_adm);
  if v_erro is distinct from 'PAPEL_INVALIDO' then
    raise exception 'FALHOU [E4]: papel desconhecido deveria dar PAPEL_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(format('select public.definir_papel(%L::uuid, %L)', gen_random_uuid(), 'admin'), v_adm);
  if v_erro is distinct from 'PERFIL_INEXISTENTE' then
    raise exception 'FALHOU [E4]: perfil inexistente deveria dar PERFIL_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- O único admin ativo não pode se rebaixar nem se desativar.
  v_erro := pg_temp.tentar(format('select public.definir_papel(%L::uuid, %L)', v_adm, 'coroinha'), v_adm);
  if v_erro is distinct from 'ULTIMO_ADMIN' then
    raise exception 'FALHOU [E4]: rebaixar o último admin deveria dar ULTIMO_ADMIN, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.definir_ativo(%L::uuid, false)', v_adm), v_adm);
  if v_erro is distinct from 'ULTIMO_ADMIN' then
    raise exception 'FALHOU [E4]: desativar o último admin deveria dar ULTIMO_ADMIN, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  select papel, ativo into v_papel, v_ativo from public.perfis where id = v_adm;
  if v_papel <> 'admin' or not v_ativo then
    raise exception 'FALHOU [E4]: o admin deveria continuar admin e ativo após os bloqueios';
  end if;

  -- Promover a Ana a admin: permitido. Agora existe outro admin.
  v_erro := pg_temp.tentar(format('select public.definir_papel(%L::uuid, %L)', v_ana, 'admin'), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [E4]: o admin deveria conseguir promover a Ana, mas veio o erro: %', v_erro;
  end if;
  select papel into v_papel from public.perfis where id = v_ana;
  if v_papel <> 'admin' then
    raise exception 'FALHOU [E4]: a Ana deveria ser admin';
  end if;

  -- Com a Ana admin, o primeiro admin pode ser rebaixado (pela Ana).
  v_erro := pg_temp.tentar(format('select public.definir_papel(%L::uuid, %L)', v_adm, 'coroinha'), v_ana);
  if v_erro is not null then
    raise exception 'FALHOU [E4]: havendo outro admin, o rebaixamento deveria funcionar, mas veio o erro: %', v_erro;
  end if;
  select papel into v_papel from public.perfis where id = v_adm;
  if v_papel <> 'coroinha' then
    raise exception 'FALHOU [E4]: o primeiro admin deveria ter virado coroinha';
  end if;

  update public.perfis set ativo = true where id = any(v_outros);

  -- ---------- E5: direitos de execução ----------
  if has_function_privilege('anon', 'public.desescalar(uuid)', 'execute')
     or has_function_privilege('anon', 'public.definir_ativo(uuid, boolean)', 'execute')
     or has_function_privilege('anon', 'public.definir_papel(uuid, text)', 'execute')
     or has_function_privilege('anon', 'public.remover_missa(uuid)', 'execute') then
    raise exception 'FALHOU [E5]: o papel anon (sem login) não deveria executar estas funções';
  end if;
  if not has_function_privilege('authenticated', 'public.desescalar(uuid)', 'execute')
     or not has_function_privilege('authenticated', 'public.definir_ativo(uuid, boolean)', 'execute')
     or not has_function_privilege('authenticated', 'public.definir_papel(uuid, text)', 'execute')
     or not has_function_privilege('authenticated', 'public.remover_missa(uuid)', 'execute') then
    raise exception 'FALHOU [E5]: o papel authenticated (logado) deveria executar estas funções';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where missa_id in (v_mfut, v_mpas, v_mcom, v_msem);
  delete from public.missas where id in (v_mfut, v_mpas, v_mcom, v_msem);
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_adm, v_ana, v_bia); -- remove os perfis junto

  raise notice 'PASSOU: testes E1 a E5';
end;
$$;
