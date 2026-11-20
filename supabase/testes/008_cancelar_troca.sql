-- Testes X1 a X7: cancelar uma troca.
--   [X1]  o titular cancela a própria troca aberta (a escalação não muda)
--   [X2]  quem não é titular nem admin não cancela -> NAO_AUTORIZADO
--   [X3]  o admin cancela a troca aberta de outra pessoa
--   [X4]  troca que já não está aberta -> TROCA_JA_RESOLVIDA
--   [X4b] a permissão vem ANTES do estado: um estranho recebe NAO_AUTORIZADO,
--         e não descobre que a troca já foi resolvida
--   [X5]  troca que não existe -> TROCA_NAO_ENCONTRADA
--   [X6]  depois de cancelar, o titular pode abrir uma nova troca
--   [X7]  só quem está logado tem direito de executar a função
--
-- Ainda NÃO está aqui: cancelar troca já ACEITA (testes 18 e 23 do Dart) e
-- aceitar troca cancelada (19). Dependem de aceitar_troca, que vem no próximo
-- ciclo.
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_local uuid := gen_random_uuid();
  v_adm   uuid := gen_random_uuid();
  v_ana   uuid := gen_random_uuid();
  v_bia   uuid := gen_random_uuid();
  v_m5h   uuid := gen_random_uuid(); -- daqui a 5h
  v_m8h   uuid := gen_random_uuid(); -- daqui a 8h
  v_esca  uuid;
  v_escb  uuid;
  v_ta    uuid; -- troca aberta na escalação A
  v_tb    uuid; -- troca aberta na escalação B
  v_t     public.trocas;
  v_erro  text;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana), (v_bia);
  insert into public.perfis (id, nome, papel) values
    (v_adm, 'Coordenador (teste)', 'admin'),
    (v_ana, 'Ana (teste)', 'coroinha'),
    (v_bia, 'Bia (teste)', 'coroinha');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id) values
    (v_m5h, now() + interval '5 hours', v_local),
    (v_m8h, now() + interval '8 hours', v_local);

  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m5h, v_ana, 'turiferário') returning id into v_esca;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m8h, v_ana, 'cruciferário') returning id into v_escb;

  insert into public.trocas (escalacao_id) values (v_esca) returning id into v_ta;
  insert into public.trocas (escalacao_id) values (v_escb) returning id into v_tb;

  -- ---------- X1: o titular cancela a própria troca ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_t from public.cancelar_troca(v_ta);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [X1]: a titular deveria conseguir cancelar, mas veio o erro: %', v_erro;
  end if;
  if v_t.status is distinct from 'cancelada' or v_t.resolvida_em is null then
    raise exception
      'FALHOU [X1]: a troca deveria ficar cancelada e com data de resolução, mas veio status=% resolvida_em=%',
      v_t.status, v_t.resolvida_em;
  end if;
  if (select coroinha_id from public.escalacoes where id = v_esca) is distinct from v_ana then
    raise exception 'FALHOU [X1]: cancelar a troca não pode mudar o titular da escalação';
  end if;

  -- ---------- X2: quem não é titular nem admin não cancela ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bia, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.cancelar_troca(v_tb);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [X2]: esperado o erro NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: a Bia cancelou a troca da Ana)');
  end if;
  if (select status from public.trocas where id = v_tb) is distinct from 'aberta' then
    raise exception 'FALHOU [X2]: a troca deveria continuar aberta';
  end if;

  -- ---------- X3: o admin cancela a troca aberta de outra pessoa ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_t from public.cancelar_troca(v_tb);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [X3]: o admin deveria conseguir cancelar, mas veio o erro: %', v_erro;
  end if;
  if v_t.status is distinct from 'cancelada' then
    raise exception 'FALHOU [X3]: a troca deveria ficar cancelada, mas veio status=%', v_t.status;
  end if;
  if (select coroinha_id from public.escalacoes where id = v_escb) is distinct from v_ana then
    raise exception 'FALHOU [X3]: cancelar a troca não pode mudar o titular da escalação';
  end if;

  -- ---------- X4: troca que já foi cancelada (a A, no X1) ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.cancelar_troca(v_ta);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'TROCA_JA_RESOLVIDA' then
    raise exception 'FALHOU [X4]: esperado o erro TROCA_JA_RESOLVIDA, mas veio: %',
      coalesce(v_erro, '(nenhum erro: cancelou uma troca que já estava cancelada)');
  end if;

  -- ---------- X4b: permissão antes do estado ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bia, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.cancelar_troca(v_ta);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception
      'FALHOU [X4b]: um estranho deveria receber NAO_AUTORIZADO (e não saber o estado da troca), mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- X5: troca que não existe ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.cancelar_troca(gen_random_uuid());
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'TROCA_NAO_ENCONTRADA' then
    raise exception 'FALHOU [X5]: esperado o erro TROCA_NAO_ENCONTRADA, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- X6: depois de cancelar, dá para abrir uma nova troca ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_t from public.abrir_troca(v_esca);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception
      'FALHOU [X6]: depois de cancelar, a titular deveria poder abrir outra troca, mas veio o erro: %', v_erro;
  end if;
  if v_t.id is not distinct from v_ta or v_t.status is distinct from 'aberta' then
    raise exception 'FALHOU [X6]: deveria nascer uma troca NOVA e aberta';
  end if;

  -- ---------- X7: só quem está logado executa a função ----------
  if has_function_privilege('anon', 'public.cancelar_troca(uuid)', 'execute') then
    raise exception 'FALHOU [X7]: o papel anon (sem login) não deveria poder executar cancelar_troca()';
  end if;
  if not has_function_privilege('authenticated', 'public.cancelar_troca(uuid)', 'execute') then
    raise exception 'FALHOU [X7]: o papel authenticated (logado) deveria poder executar cancelar_troca()';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where coroinha_id in (v_ana, v_bia); -- leva as trocas junto
  delete from public.missas where id in (v_m5h, v_m8h);
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_adm, v_ana, v_bia); -- remove os perfis junto

  raise notice 'PASSOU: testes X1 a X7';
end;
$$;
