-- Testes C1 a C6: cadastro de locais e missas pelo admin.
--   [C1] coroinha comum não cria local (NAO_AUTORIZADO, nada é gravado)
--   [C2] admin cria local; o nome é gravado sem espaços nas pontas
--   [C3] nome vazio/nulo -> NOME_INVALIDO; nome repetido -> LOCAL_DUPLICADO
--   [C4] criar_missa: coroinha -> NAO_AUTORIZADO; admin cria; horário nulo ->
--        HORARIO_INVALIDO; local inexistente -> LOCAL_INEXISTENTE
--   [C5] editar_missa: permissão, missa inexistente, validações, mover o
--        horário (período acompanha, presença confirmada é mantida), mover
--        para conflito -> CONFLITO_DE_HORARIO (a missa fica onde estava)
--   [C6] anon não executa nenhuma das três funções; authenticated executa
--
-- Segue a decisão dos testes 003 e 004: mover o horário é PERMITIDO; só o
-- conflito de horário bloqueia.
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
  v_adm    uuid := gen_random_uuid();
  v_ana    uuid := gen_random_uuid();
  v_local  uuid;
  v_local2 uuid;
  v_missa  uuid;
  v_missaB uuid;
  v_erro   text;
  v_qtd    int;
  v_inicio timestamptz;
  v_lid    uuid;
  v_status text;
  v_periodo tstzrange;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana);
  insert into public.perfis (id, nome, papel) values
    (v_adm, 'Coordenador (teste)', 'admin'),
    (v_ana, 'Ana (teste)', 'coroinha');

  -- ---------- C1: coroinha comum não cria local ----------
  v_erro := pg_temp.tentar(format('select public.criar_local(%L)', 'Capela (teste cadastro)'), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [C1]: esperado NAO_AUTORIZADO para coroinha comum, mas veio: %',
      coalesce(v_erro, '(nenhum erro: o coroinha conseguiu criar o local)');
  end if;
  select count(*) into v_qtd from public.locais where nome = 'Capela (teste cadastro)';
  if v_qtd <> 0 then
    raise exception 'FALHOU [C1]: nada deveria ter sido gravado, mas há % local(is)', v_qtd;
  end if;

  -- ---------- C2: admin cria local (nome sem espaços nas pontas) ----------
  v_erro := pg_temp.tentar(format('select public.criar_local(%L)', '  Capela (teste cadastro)  '), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [C2]: o admin deveria conseguir criar o local, mas veio o erro: %', v_erro;
  end if;
  select count(*) into v_qtd from public.locais where nome = 'Capela (teste cadastro)';
  if v_qtd <> 1 then
    raise exception 'FALHOU [C2]: deveria existir 1 local chamado "Capela (teste cadastro)" (sem espaços), mas há %', v_qtd;
  end if;
  select id into v_local from public.locais where nome = 'Capela (teste cadastro)';

  -- ---------- C3: nome inválido e nome repetido ----------
  v_erro := pg_temp.tentar(format('select public.criar_local(%L)', '   '), v_adm);
  if v_erro is distinct from 'NOME_INVALIDO' then
    raise exception 'FALHOU [C3]: nome em branco deveria dar NOME_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar('select public.criar_local(null)', v_adm);
  if v_erro is distinct from 'NOME_INVALIDO' then
    raise exception 'FALHOU [C3]: nome nulo deveria dar NOME_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.criar_local(%L)', 'Capela (teste cadastro)'), v_adm);
  if v_erro is distinct from 'LOCAL_DUPLICADO' then
    raise exception 'FALHOU [C3]: nome repetido deveria dar LOCAL_DUPLICADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- C4: criar_missa ----------
  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L::timestamptz, %L::uuid)', '2026-12-06 18:00:00-03', v_local), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [C4]: coroinha criando missa deveria dar NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L::timestamptz, %L::uuid)', '2026-12-06 18:00:00-03', v_local), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [C4]: o admin deveria conseguir criar a missa, mas veio o erro: %', v_erro;
  end if;
  select m.id, m.inicio, m.local_id into v_missa, v_inicio, v_lid
    from public.missas m where m.local_id = v_local;
  if v_missa is null or v_inicio <> '2026-12-06 18:00:00-03' then
    raise exception 'FALHOU [C4]: a missa criada deveria estar às 18:00 no local de teste';
  end if;

  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L::timestamptz, %L::uuid)', null, v_local), v_adm);
  if v_erro is distinct from 'HORARIO_INVALIDO' then
    raise exception 'FALHOU [C4]: horário nulo deveria dar HORARIO_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L::timestamptz, %L::uuid)',
           '2026-12-06 18:00:00-03', gen_random_uuid()), v_adm);
  if v_erro is distinct from 'LOCAL_INEXISTENTE' then
    raise exception 'FALHOU [C4]: local inexistente deveria dar LOCAL_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- C5: editar_missa ----------
  insert into public.locais (nome) values ('Matriz (teste cadastro)')
    returning id into v_local2;

  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid)',
           v_missa, '2026-12-06 19:00:00-03', v_local), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [C5]: coroinha editando missa deveria dar NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid)',
           gen_random_uuid(), '2026-12-06 19:00:00-03', v_local), v_adm);
  if v_erro is distinct from 'MISSA_INEXISTENTE' then
    raise exception 'FALHOU [C5]: missa inexistente deveria dar MISSA_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid)',
           v_missa, null, v_local), v_adm);
  if v_erro is distinct from 'HORARIO_INVALIDO' then
    raise exception 'FALHOU [C5]: horário nulo deveria dar HORARIO_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid)',
           v_missa, '2026-12-06 19:00:00-03', gen_random_uuid()), v_adm);
  if v_erro is distinct from 'LOCAL_INEXISTENTE' then
    raise exception 'FALHOU [C5]: local inexistente deveria dar LOCAL_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- Ana escalada e CONFIRMADA na missa das 18:00; há outra missa às 20:00.
  insert into public.escalacoes (missa_id, coroinha_id, funcao, status)
    values (v_missa, v_ana, 'turiferário', 'confirmado');
  insert into public.missas (inicio, local_id) values ('2026-12-06 20:00:00-03', v_local)
    returning id into v_missaB;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_missaB, v_ana, 'cruciferário');

  -- Mover a missa das 18:00 para 19:00 (e trocar o local): permitido.
  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid)',
           v_missa, '2026-12-06 19:00:00-03', v_local2), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [C5]: o admin deveria conseguir mover a missa, mas veio o erro: %', v_erro;
  end if;
  select m.inicio, m.local_id into v_inicio, v_lid from public.missas m where m.id = v_missa;
  if v_inicio <> '2026-12-06 19:00:00-03' or v_lid is distinct from v_local2 then
    raise exception 'FALHOU [C5]: a missa deveria estar às 19:00 no segundo local';
  end if;
  select e.status, e.periodo into v_status, v_periodo
    from public.escalacoes e where e.missa_id = v_missa;
  if v_status is distinct from 'confirmado' then
    raise exception 'FALHOU [C5]: a presença confirmada deveria ser mantida, mas o status é %', v_status;
  end if;
  if lower(v_periodo) <> '2026-12-06 19:00:00-03' then
    raise exception 'FALHOU [C5]: o período da escalação deveria acompanhar a missa (19:00)';
  end if;

  -- Mover a missa das 19:00 para 20:30 conflita com a das 20:00 (mesma Ana).
  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid)',
           v_missa, '2026-12-06 20:30:00-03', v_local2), v_adm);
  if v_erro is distinct from 'CONFLITO_DE_HORARIO' then
    raise exception 'FALHOU [C5]: mover para um horário em conflito deveria dar CONFLITO_DE_HORARIO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;
  select m.inicio into v_inicio from public.missas m where m.id = v_missa;
  if v_inicio <> '2026-12-06 19:00:00-03' then
    raise exception 'FALHOU [C5]: após o conflito a missa deveria continuar às 19:00, mas está em %', v_inicio;
  end if;

  -- ---------- C6: direitos de execução ----------
  if has_function_privilege('anon', 'public.criar_local(text)', 'execute')
     or has_function_privilege('anon', 'public.criar_missa(timestamptz, uuid)', 'execute')
     or has_function_privilege('anon', 'public.editar_missa(uuid, timestamptz, uuid)', 'execute') then
    raise exception 'FALHOU [C6]: o papel anon (sem login) não deveria executar as funções de cadastro';
  end if;
  if not has_function_privilege('authenticated', 'public.criar_local(text)', 'execute')
     or not has_function_privilege('authenticated', 'public.criar_missa(timestamptz, uuid)', 'execute')
     or not has_function_privilege('authenticated', 'public.editar_missa(uuid, timestamptz, uuid)', 'execute') then
    raise exception 'FALHOU [C6]: o papel authenticated (logado) deveria executar as funções de cadastro';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where missa_id in (v_missa, v_missaB);
  delete from public.missas where id in (v_missa, v_missaB);
  delete from public.locais where id in (v_local, v_local2);
  delete from auth.users where id in (v_adm, v_ana); -- remove os perfis junto

  raise notice 'PASSOU: testes C1 a C6';
end;
$$;
