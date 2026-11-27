-- Testes 2, 2b e 2c: conflito de horário.
-- Regra: o mesmo coroinha não pode ter duas escalações com início a menos
-- de 1h de diferença. Exatamente 1h de diferença é permitido.
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [n]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_local uuid := gen_random_uuid();
  v_ana   uuid := gen_random_uuid();
  v_bia   uuid := gen_random_uuid();
  v_m1800 uuid := gen_random_uuid();
  v_m1830 uuid := gen_random_uuid();
  v_m1900 uuid := gen_random_uuid();
begin
  -- ---------- Preparação ----------
  insert into auth.users (id) values (v_ana), (v_bia);
  insert into public.perfis (id, nome)
    values (v_ana, 'Ana (teste)'), (v_bia, 'Bia (teste)');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id) values
    (v_m1800, '2036-11-22 18:00:00-03', v_local),
    (v_m1830, '2036-11-22 18:30:00-03', v_local),
    (v_m1900, '2036-11-22 19:00:00-03', v_local);

  -- A Ana já está escalada às 18:00.
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m1800, v_ana, 'turiferário');

  -- ---------- Teste 2: 18:30 conflita com 18:00 ----------
  begin
    insert into public.escalacoes (missa_id, coroinha_id, funcao)
      values (v_m1830, v_ana, 'turiferário');
    raise exception
      'FALHOU [2]: a Ana foi escalada às 18:00 e às 18:30, e deveria ter sido bloqueada';
  exception
    when exclusion_violation then
      null; -- bloqueou, como esperado
  end;

  -- ---------- Teste 2b: 19:00 NÃO conflita (diferença de exatamente 1h) ----------
  begin
    insert into public.escalacoes (missa_id, coroinha_id, funcao)
      values (v_m1900, v_ana, 'cruciferário');
  exception
    when exclusion_violation then
      raise exception
        'FALHOU [2b]: 18:00 e 19:00 não deveriam conflitar (a primeira termina quando a segunda começa)';
  end;

  -- ---------- Teste 2c: OUTRO coroinha no mesmo horário é permitido ----------
  begin
    insert into public.escalacoes (missa_id, coroinha_id, funcao)
      values (v_m1800, v_bia, 'turiferário');
  exception
    when exclusion_violation then
      raise exception
        'FALHOU [2c]: o conflito vale por coroinha, a Bia não deveria ser bloqueada';
  end;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  -- Se algum teste falhar, o bloco inteiro é desfeito sozinho.
  delete from public.escalacoes where coroinha_id in (v_ana, v_bia);
  delete from public.missas where id in (v_m1800, v_m1830, v_m1900);
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_ana, v_bia); -- remove os perfis junto

  raise notice 'PASSOU: testes 2, 2b e 2c';
end;
$$;
