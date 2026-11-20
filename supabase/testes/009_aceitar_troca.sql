-- Testes A1 a A14: aceitar uma troca.
--   [A1]  substituto livre aceita: a escalação passa a ele, confirmada e no prazo
--   [A2]  aceitar depois do prazo (missa a 1h): confirmada COM atraso
--   [A3]  o titular não aceita a própria troca -> SUBSTITUTO_INVALIDO
--   [A4]  substituto com conflito de horário -> CONFLITO_DE_HORARIO
--   [A5]  substituto que já está na mesma missa -> JA_ESCALADO_NA_MISSA
--   [A6]  quem não tem perfil (não passou pelo convite) -> NAO_AUTORIZADO
--         e, depois de A3 a A6, a troca segue aberta e a escalação não mudou
--   [A7]  o primeiro aceite vence: segundo -> TROCA_JA_RESOLVIDA
--   [A8]  troca cancelada não pode ser aceita -> TROCA_JA_RESOLVIDA
--   [A9]  missa que já começou -> MISSA_JA_COMECOU
--   [A10] troca que não existe -> TROCA_NAO_ENCONTRADA
--   [A11] o NOVO titular não cancela troca já aceita -> TROCA_JA_RESOLVIDA
--   [A12] o ANTIGO titular perde o direito sobre ela -> NAO_AUTORIZADO
--   [A13] o novo titular pode abrir uma nova troca
--   [A14] só quem está logado tem direito de executar a função
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.
--
-- Limite honesto: aqui os aceites acontecem um depois do outro. A proteção
-- contra aceites realmente simultâneos vem do bloqueio da linha (for update)
-- dentro da função, e este tipo de teste não consegue simulá-la.

do $$
declare
  v_local    uuid := gen_random_uuid();
  v_ana      uuid := gen_random_uuid(); -- titular de todas as escalações de teste
  v_bia      uuid := gen_random_uuid();
  v_carlos   uuid := gen_random_uuid();
  v_dani     uuid := gen_random_uuid();
  v_intruso  uuid := gen_random_uuid(); -- tem login, mas NÃO tem perfil
  v_m1h      uuid := gen_random_uuid();
  v_m3h      uuid := gen_random_uuid();
  v_m5h      uuid := gen_random_uuid();
  v_m8h      uuid := gen_random_uuid();
  v_m8h30    uuid := gen_random_uuid();
  v_mpassou  uuid := gen_random_uuid();
  v_e1 uuid; v_e2 uuid; v_e3 uuid; v_e4 uuid; v_e5 uuid;
  v_t1 uuid; v_t2 uuid; v_t3 uuid; v_t4 uuid; v_t5 uuid;
  v_t      public.trocas;
  v_erro   text;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id)
    values (v_ana), (v_bia), (v_carlos), (v_dani), (v_intruso);
  insert into public.perfis (id, nome) values
    (v_ana, 'Ana (teste)'), (v_bia, 'Bia (teste)'),
    (v_carlos, 'Carlos (teste)'), (v_dani, 'Dani (teste)');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id) values
    (v_m1h,     now() + interval '1 hour',    v_local),
    (v_m3h,     now() + interval '3 hours',   v_local),
    (v_m5h,     now() + interval '5 hours',   v_local),
    (v_m8h,     now() + interval '8 hours',   v_local),
    (v_m8h30,   now() + interval '8 hours 30 minutes', v_local),
    (v_mpassou, now() - interval '5 minutes', v_local);

  -- A Ana é a titular de cinco escalações, uma por cenário.
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m5h, v_ana, 'turiferário') returning id into v_e1;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m1h, v_ana, 'turiferário') returning id into v_e2;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m8h, v_ana, 'turiferário') returning id into v_e3;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m3h, v_ana, 'turiferário') returning id into v_e4;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_mpassou, v_ana, 'turiferário') returning id into v_e5;

  -- A Bia já está na missa das 8h (outra função) -> cenário A5.
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m8h, v_bia, 'cruciferário');
  -- A Dani está às 8h30, que conflita com as 8h -> cenário A4.
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m8h30, v_dani, 'turiferário');

  -- Uma troca por escalação da Ana. A T4 já nasce cancelada; a T5 é de uma
  -- missa que já começou (a função abrir_troca não deixaria criar, então
  -- ela é preparada direto no banco).
  insert into public.trocas (escalacao_id) values (v_e1) returning id into v_t1;
  insert into public.trocas (escalacao_id) values (v_e2) returning id into v_t2;
  insert into public.trocas (escalacao_id) values (v_e3) returning id into v_t3;
  insert into public.trocas (escalacao_id, status, resolvida_em)
    values (v_e4, 'cancelada', now()) returning id into v_t4;
  insert into public.trocas (escalacao_id) values (v_e5) returning id into v_t5;

  -- ---------- A1: a Bia aceita a troca da Ana (missa a 5h) ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bia, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_t from public.aceitar_troca(v_t1);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [A1]: a Bia deveria conseguir aceitar, mas veio o erro: %', v_erro;
  end if;
  if v_t.status is distinct from 'aceita'
     or v_t.substituto_id is distinct from v_bia
     or v_t.resolvida_em is null then
    raise exception
      'FALHOU [A1]: a troca deveria ficar aceita pela Bia e com data de resolução, mas veio status=% substituto=%',
      v_t.status, v_t.substituto_id;
  end if;
  if (select coroinha_id from public.escalacoes where id = v_e1) is distinct from v_bia then
    raise exception 'FALHOU [A1]: a escalação deveria ter passado para a Bia';
  end if;
  if (select status from public.escalacoes where id = v_e1) is distinct from 'confirmado'
     or (select confirmado_com_atraso from public.escalacoes where id = v_e1) then
    raise exception 'FALHOU [A1]: a Bia deveria entrar CONFIRMADA e SEM atraso (a missa é daqui a 5h)';
  end if;

  -- ---------- A2: o Carlos aceita a troca de uma missa a 1h ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_carlos, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_t from public.aceitar_troca(v_t2);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [A2]: aceitar depois do prazo deveria ser permitido, mas veio o erro: %', v_erro;
  end if;
  if (select status from public.escalacoes where id = v_e2) is distinct from 'confirmado'
     or not (select confirmado_com_atraso from public.escalacoes where id = v_e2) then
    raise exception 'FALHOU [A2]: o Carlos deveria entrar CONFIRMADO e COM atraso (a missa é daqui a 1h)';
  end if;

  -- ---------- A3: a Ana tenta aceitar a própria troca ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.aceitar_troca(v_t3);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'SUBSTITUTO_INVALIDO' then
    raise exception 'FALHOU [A3]: esperado o erro SUBSTITUTO_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: a titular aceitou a própria troca)');
  end if;

  -- ---------- A4: a Dani tem conflito de horário (8h30 x 8h) ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dani, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.aceitar_troca(v_t3);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'CONFLITO_DE_HORARIO' then
    raise exception 'FALHOU [A4]: esperado o erro CONFLITO_DE_HORARIO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: aceitou mesmo com conflito de horário)');
  end if;

  -- ---------- A5: a Bia já está na missa das 8h ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bia, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.aceitar_troca(v_t3);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'JA_ESCALADO_NA_MISSA' then
    raise exception 'FALHOU [A5]: esperado o erro JA_ESCALADO_NA_MISSA, mas veio: %',
      coalesce(v_erro, '(nenhum erro: aceitou mesmo já estando na missa)');
  end if;

  -- ---------- A6: quem não tem perfil ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_intruso, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.aceitar_troca(v_t3);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [A6]: esperado o erro NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: alguém sem perfil aceitou a troca)');
  end if;

  -- Depois de quatro tentativas negadas (A3 a A6), nada pode ter mudado.
  if (select status from public.trocas where id = v_t3) is distinct from 'aberta' then
    raise exception 'FALHOU [A6]: a troca deveria continuar aberta depois das tentativas negadas';
  end if;
  if (select coroinha_id from public.escalacoes where id = v_e3) is distinct from v_ana then
    raise exception 'FALHOU [A6]: a escalação deveria continuar com a Ana depois das tentativas negadas';
  end if;

  -- ---------- A7: o primeiro aceite vence (a T1 já foi aceita pela Bia no A1) ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_carlos, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.aceitar_troca(v_t1);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'TROCA_JA_RESOLVIDA' then
    raise exception 'FALHOU [A7]: esperado o erro TROCA_JA_RESOLVIDA, mas veio: %',
      coalesce(v_erro, '(nenhum erro: um segundo aceite foi aceito)');
  end if;
  if (select coroinha_id from public.escalacoes where id = v_e1) is distinct from v_bia then
    raise exception 'FALHOU [A7]: a escalação deveria continuar com a Bia (primeiro aceite)';
  end if;

  -- ---------- A8: troca cancelada não pode ser aceita ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_carlos, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.aceitar_troca(v_t4);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'TROCA_JA_RESOLVIDA' then
    raise exception 'FALHOU [A8]: esperado o erro TROCA_JA_RESOLVIDA, mas veio: %',
      coalesce(v_erro, '(nenhum erro: aceitou uma troca cancelada)');
  end if;
  if (select coroinha_id from public.escalacoes where id = v_e4) is distinct from v_ana then
    raise exception 'FALHOU [A8]: a escalação deveria continuar com a Ana';
  end if;

  -- ---------- A9: missa que já começou ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_carlos, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.aceitar_troca(v_t5);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'MISSA_JA_COMECOU' then
    raise exception 'FALHOU [A9]: esperado o erro MISSA_JA_COMECOU, mas veio: %',
      coalesce(v_erro, '(nenhum erro: aceitou troca de missa que já começou)');
  end if;
  if (select status from public.trocas where id = v_t5) is distinct from 'aberta' then
    raise exception 'FALHOU [A9]: a troca deveria continuar aberta';
  end if;

  -- ---------- A10: troca que não existe ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_carlos, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.aceitar_troca(gen_random_uuid());
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'TROCA_NAO_ENCONTRADA' then
    raise exception 'FALHOU [A10]: esperado o erro TROCA_NAO_ENCONTRADA, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- A11: o novo titular (Bia) não cancela uma troca já aceita ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bia, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.cancelar_troca(v_t1);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'TROCA_JA_RESOLVIDA' then
    raise exception 'FALHOU [A11]: esperado o erro TROCA_JA_RESOLVIDA, mas veio: %',
      coalesce(v_erro, '(nenhum erro: cancelou uma troca já aceita)');
  end if;
  if (select status from public.trocas where id = v_t1) is distinct from 'aceita'
     or (select coroinha_id from public.escalacoes where id = v_e1) is distinct from v_bia then
    raise exception 'FALHOU [A11]: a troca deveria continuar aceita e a escalação com a Bia';
  end if;

  -- ---------- A12: a ANTIGA titular (Ana) perdeu o direito sobre a troca ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.cancelar_troca(v_t1);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception
      'FALHOU [A12]: a antiga titular deveria receber NAO_AUTORIZADO (não é mais dona da escalação), mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- A13: o novo titular (Bia) pode abrir uma nova troca ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bia, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_t from public.abrir_troca(v_e1);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception
      'FALHOU [A13]: o novo titular deveria poder abrir uma troca, mas veio o erro: %', v_erro;
  end if;
  if v_t.id is not distinct from v_t1 or v_t.status is distinct from 'aberta' then
    raise exception 'FALHOU [A13]: deveria nascer uma troca NOVA e aberta';
  end if;

  -- ---------- A14: só quem está logado executa a função ----------
  if has_function_privilege('anon', 'public.aceitar_troca(uuid)', 'execute') then
    raise exception 'FALHOU [A14]: o papel anon (sem login) não deveria poder executar aceitar_troca()';
  end if;
  if not has_function_privilege('authenticated', 'public.aceitar_troca(uuid)', 'execute') then
    raise exception 'FALHOU [A14]: o papel authenticated (logado) deveria poder executar aceitar_troca()';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes
   where coroinha_id in (v_ana, v_bia, v_carlos, v_dani); -- leva as trocas junto
  delete from public.missas
   where id in (v_m1h, v_m3h, v_m5h, v_m8h, v_m8h30, v_mpassou);
  delete from public.locais where id = v_local;
  delete from auth.users
   where id in (v_ana, v_bia, v_carlos, v_dani, v_intruso); -- remove os perfis junto

  raise notice 'PASSOU: testes A1 a A14';
end;
$$;
