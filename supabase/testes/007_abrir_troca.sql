-- Testes T1 a T8: abrir uma troca.
--   [T1] o titular abre a troca da própria escalação -> troca aberta
--   [T2] outro coroinha não abre a troca por ele -> NAO_AUTORIZADO
--   [T3] missa que já começou -> MISSA_JA_COMECOU
--   [T4] segunda troca aberta na mesma escalação -> TROCA_JA_ABERTA
--   [T5] escalação que não existe -> ESCALACAO_NAO_ENCONTRADA
--   [T6] [guarda] depois que a troca deixa de estar aberta, dá para abrir outra
--   [T7] só quem está logado tem direito de executar a função
--   [T8] o BANCO recusa duas trocas abertas na mesma escalação, mesmo sem
--        passar pela função (rede de segurança contra pedidos simultâneos)
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_local   uuid := gen_random_uuid();
  v_ana     uuid := gen_random_uuid();
  v_bia     uuid := gen_random_uuid();
  v_m5h     uuid := gen_random_uuid(); -- daqui a 5h
  v_m8h     uuid := gen_random_uuid(); -- daqui a 8h
  v_mpassou uuid := gen_random_uuid(); -- começou há 5 minutos
  v_esc5h   uuid;
  v_esc8h   uuid;
  v_escpass uuid;
  v_t       public.trocas;
  v_primeira uuid;
  v_erro    text;
  v_qtd     int;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_ana), (v_bia);
  insert into public.perfis (id, nome) values
    (v_ana, 'Ana (teste)'), (v_bia, 'Bia (teste)');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id) values
    (v_m5h,     now() + interval '5 hours',   v_local),
    (v_m8h,     now() + interval '8 hours',   v_local),
    (v_mpassou, now() - interval '5 minutes', v_local);

  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m5h, v_ana, 'turiferário') returning id into v_esc5h;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m8h, v_ana, 'turiferário') returning id into v_esc8h;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_mpassou, v_ana, 'cruciferário') returning id into v_escpass;

  -- ---------- T1: o titular abre a troca ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_t from public.abrir_troca(v_esc5h);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [T1]: a titular deveria conseguir abrir a troca, mas veio o erro: %', v_erro;
  end if;
  if v_t.status is distinct from 'aberta'
     or v_t.escalacao_id is distinct from v_esc5h
     or v_t.substituto_id is not null then
    raise exception
      'FALHOU [T1]: a troca deveria nascer aberta, ligada à escalação e sem substituto, mas veio status=% substituto=%',
      v_t.status, v_t.substituto_id;
  end if;
  v_primeira := v_t.id;

  -- ---------- T2: outro coroinha não abre a troca por ela ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bia, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.abrir_troca(v_esc8h);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [T2]: esperado o erro NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: a Bia abriu a troca da Ana)');
  end if;
  select count(*) into v_qtd from public.trocas where escalacao_id = v_esc8h;
  if v_qtd <> 0 then
    raise exception 'FALHOU [T2]: nenhuma troca deveria ter sido criada, mas há %', v_qtd;
  end if;

  -- ---------- T3: missa que já começou ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.abrir_troca(v_escpass);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'MISSA_JA_COMECOU' then
    raise exception 'FALHOU [T3]: esperado o erro MISSA_JA_COMECOU, mas veio: %',
      coalesce(v_erro, '(nenhum erro: abriu troca de missa que já começou)');
  end if;

  -- ---------- T4: segunda troca aberta na mesma escalação ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.abrir_troca(v_esc5h);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'TROCA_JA_ABERTA' then
    raise exception 'FALHOU [T4]: esperado o erro TROCA_JA_ABERTA, mas veio: %',
      coalesce(v_erro, '(nenhum erro: a segunda troca aberta foi aceita)');
  end if;

  -- ---------- T5: escalação que não existe ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.abrir_troca(gen_random_uuid());
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'ESCALACAO_NAO_ENCONTRADA' then
    raise exception 'FALHOU [T5]: esperado o erro ESCALACAO_NAO_ENCONTRADA, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- T8: o banco recusa a segunda troca aberta (direto na tabela) ----------
  begin
    insert into public.trocas (escalacao_id) values (v_esc5h);
    raise exception
      'FALHOU [T8]: o banco aceitou duas trocas abertas na mesma escalação';
  exception
    when unique_violation then
      null; -- bloqueou, como esperado
  end;

  -- ---------- T6: a troca deixa de estar aberta -> dá para abrir outra ----------
  update public.trocas
     set status = 'cancelada', resolvida_em = now()
   where id = v_primeira;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_t from public.abrir_troca(v_esc5h);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception
      'FALHOU [T6]: com a troca anterior cancelada, deveria poder abrir outra, mas veio o erro: %', v_erro;
  end if;
  if v_t.id is not distinct from v_primeira or v_t.status is distinct from 'aberta' then
    raise exception 'FALHOU [T6]: deveria nascer uma troca NOVA e aberta';
  end if;

  -- ---------- T7: só quem está logado executa a função ----------
  if has_function_privilege('anon', 'public.abrir_troca(uuid)', 'execute') then
    raise exception 'FALHOU [T7]: o papel anon (sem login) não deveria poder executar abrir_troca()';
  end if;
  if not has_function_privilege('authenticated', 'public.abrir_troca(uuid)', 'execute') then
    raise exception 'FALHOU [T7]: o papel authenticated (logado) deveria poder executar abrir_troca()';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where coroinha_id in (v_ana, v_bia); -- leva as trocas junto
  delete from public.missas where id in (v_m5h, v_m8h, v_mpassou);
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_ana, v_bia); -- remove os perfis junto

  raise notice 'PASSOU: testes T1 a T8';
end;
$$;
