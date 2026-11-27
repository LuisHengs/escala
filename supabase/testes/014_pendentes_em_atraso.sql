-- Testes D1 a D4: lista de "pendentes em atraso" para o coordenador.
--   [D1] coroinha comum chama a lista -> NAO_AUTORIZADO
--   [D2] espelha o teste 6 do Dart: fora do prazo a lista vem vazia; dentro
--        do prazo vem só quem está PENDENTE (o confirmado não aparece)
--   [D3] bordas: exatamente 2h antes entra; exatamente no início já não entra
--        (a missa começou); a lista vem ordenada pelo início da missa
--   [D4] anon não executa a função; authenticated executa
--
-- Regra (do Dart, pendentesEmAtraso): status pendente E agora >= início - 2h
-- E agora < início. A função recebe "agora" como parâmetro (padrão: now()),
-- como passou_do_prazo, para o teste usar horas exatas.
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_adm    uuid := gen_random_uuid();
  v_ana    uuid := gen_random_uuid();
  v_bia    uuid := gen_random_uuid();
  v_carlos uuid := gen_random_uuid();
  v_local  uuid := gen_random_uuid();
  v_m1800  uuid := gen_random_uuid();
  v_m1830  uuid := gen_random_uuid();
  v_m1900  uuid := gen_random_uuid();
  v_e_ana  uuid;
  v_e_bia  uuid;
  v_e_car  uuid;
  v_erro   text;
  v_ids    uuid[];
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana), (v_bia), (v_carlos);
  insert into public.perfis (id, nome, papel) values
    (v_adm,    'Coordenador (teste)', 'admin'),
    (v_ana,    'Ana (teste)',         'coroinha'),
    (v_bia,    'Bia (teste)',         'coroinha'),
    (v_carlos, 'Carlos (teste)',      'coroinha');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id) values
    (v_m1800, '2036-11-22 18:00:00-03', v_local),
    (v_m1830, '2036-11-22 18:30:00-03', v_local),
    (v_m1900, '2036-11-22 19:00:00-03', v_local);
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m1800, v_ana, 'turiferário') returning id into v_e_ana;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m1900, v_bia, 'cruciferário') returning id into v_e_bia;
  insert into public.escalacoes (missa_id, coroinha_id, funcao, status)
    values (v_m1830, v_carlos, 'acólito', 'confirmado') returning id into v_e_car;

  -- ---------- D1: coroinha comum NÃO vê a lista ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform * from public.pendentes_em_atraso('2036-11-22 17:00:00-03');
  exception
    when others then
      v_erro := sqlerrm;
  end;
  reset role;
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [D1]: esperado NAO_AUTORIZADO para coroinha comum, mas veio: %',
      coalesce(v_erro, '(nenhum erro: o coroinha conseguiu ver a lista)');
  end if;

  -- A partir daqui, como admin.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- ---------- D2: fora do prazo -> vazia; dentro -> só os pendentes ----------
  -- 15:30: 18:00 começa em 2h30 e 19:00 em 3h30 -> ainda fora do prazo.
  select coalesce(array_agg(p.escalacao_id), '{}') into v_ids
    from public.pendentes_em_atraso('2036-11-22 15:30:00-03') p
   where p.escalacao_id in (v_e_ana, v_e_bia, v_e_car);
  if cardinality(v_ids) <> 0 then
    raise exception 'FALHOU [D2]: às 15:30 a lista deveria estar vazia, mas veio % item(ns)',
      cardinality(v_ids);
  end if;

  -- 17:00: 18:00 em 1h (dentro); 19:00 em exatamente 2h (borda: dentro);
  -- 18:30 não aparece porque está confirmada.
  select coalesce(array_agg(p.escalacao_id order by p.inicio), '{}') into v_ids
    from public.pendentes_em_atraso('2036-11-22 17:00:00-03') p
   where p.escalacao_id in (v_e_ana, v_e_bia, v_e_car);
  if v_ids is distinct from array[v_e_ana, v_e_bia] then
    raise exception 'FALHOU [D2]: às 17:00 deveriam vir a Ana e a Bia (e não o Carlos, confirmado), mas vieram % item(ns)',
      cardinality(v_ids);
  end if;

  -- ---------- D3: bordas ----------
  -- 16:00 em ponto: a missa das 18:00 está a exatamente 2h -> entra.
  select coalesce(array_agg(p.escalacao_id), '{}') into v_ids
    from public.pendentes_em_atraso('2036-11-22 16:00:00-03') p
   where p.escalacao_id in (v_e_ana, v_e_bia, v_e_car);
  if v_ids is distinct from array[v_e_ana] then
    raise exception 'FALHOU [D3]: às 16:00 em ponto só a Ana deveria constar (2h exatas antes das 18:00)';
  end if;

  -- 15:59:59: um segundo antes da borda -> ainda fora.
  select coalesce(array_agg(p.escalacao_id), '{}') into v_ids
    from public.pendentes_em_atraso('2036-11-22 15:59:59-03') p
   where p.escalacao_id in (v_e_ana, v_e_bia, v_e_car);
  if cardinality(v_ids) <> 0 then
    raise exception 'FALHOU [D3]: às 15:59:59 a lista deveria estar vazia';
  end if;

  -- 18:00 em ponto: a missa começou -> sai da lista; a Bia (19:00) segue.
  select coalesce(array_agg(p.escalacao_id), '{}') into v_ids
    from public.pendentes_em_atraso('2036-11-22 18:00:00-03') p
   where p.escalacao_id in (v_e_ana, v_e_bia, v_e_car);
  if v_ids is distinct from array[v_e_bia] then
    raise exception 'FALHOU [D3]: às 18:00 em ponto a Ana não deveria constar (a missa começou), só a Bia';
  end if;

  reset role;

  -- ---------- D4: direitos de execução ----------
  if has_function_privilege('anon', 'public.pendentes_em_atraso(timestamptz)', 'execute') then
    raise exception 'FALHOU [D4]: o papel anon (sem login) não deveria executar pendentes_em_atraso()';
  end if;
  if not has_function_privilege('authenticated', 'public.pendentes_em_atraso(timestamptz)', 'execute') then
    raise exception 'FALHOU [D4]: o papel authenticated (logado) deveria executar pendentes_em_atraso()';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where missa_id in (v_m1800, v_m1830, v_m1900);
  delete from public.missas where id in (v_m1800, v_m1830, v_m1900);
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_adm, v_ana, v_bia, v_carlos); -- remove os perfis junto

  raise notice 'PASSOU: testes D1 a D4';
end;
$$;
