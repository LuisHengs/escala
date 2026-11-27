-- Testes M1, M2 e M3: o horário da missa muda.
--   [M1] o período das escalações acompanha a missa (e só o dela)
--   [M2] mover a missa para um horário que conflita é BLOQUEADO,
--        e a missa continua no horário original
--   [M3] [borda] mover para exatamente 1h depois de outra missa do mesmo
--        coroinha é permitido
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_local uuid := gen_random_uuid();
  v_ana   uuid := gen_random_uuid();
  v_bia   uuid := gen_random_uuid();
  v_m1800 uuid := gen_random_uuid(); -- missa da Ana que vai ser movida (M1)
  v_m1900 uuid := gen_random_uuid(); -- missa da Bia, não pode ser afetada (M1)
  v_ma    uuid := gen_random_uuid(); -- Ana às 10:00 (M2 e M3)
  v_mb    uuid := gen_random_uuid(); -- Ana às 15:00, vai ser movida (M2 e M3)
  v_periodo tstzrange;
  v_inicio  timestamptz;
  v_bloqueou boolean;
begin
  -- ---------- Preparação ----------
  insert into auth.users (id) values (v_ana), (v_bia);
  insert into public.perfis (id, nome)
    values (v_ana, 'Ana (teste)'), (v_bia, 'Bia (teste)');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id) values
    (v_m1800, '2036-11-22 18:00:00-03', v_local),
    (v_m1900, '2036-11-22 19:00:00-03', v_local),
    (v_ma,    '2036-11-29 10:00:00-03', v_local),
    (v_mb,    '2036-11-29 15:00:00-03', v_local);

  insert into public.escalacoes (missa_id, coroinha_id, funcao) values
    (v_m1800, v_ana, 'turiferário'),
    (v_m1900, v_bia, 'turiferário'),
    (v_ma,    v_ana, 'turiferário'),
    (v_mb,    v_ana, 'cruciferário');

  -- ---------- Teste M1: o período acompanha o novo horário ----------
  update public.missas
     set inicio = '2036-11-22 20:00:00-03'
   where id = v_m1800;

  select periodo into v_periodo
    from public.escalacoes
   where missa_id = v_m1800 and coroinha_id = v_ana;
  if v_periodo is distinct from tstzrange(
       '2036-11-22 20:00:00-03'::timestamptz,
       '2036-11-22 21:00:00-03'::timestamptz) then
    raise exception
      'FALHOU [M1]: o período da Ana deveria ser 20:00-21:00 depois de mover a missa, mas está em: %',
      v_periodo;
  end if;

  -- A escalação da Bia (outra missa) não pode ter sido tocada.
  select periodo into v_periodo
    from public.escalacoes
   where missa_id = v_m1900 and coroinha_id = v_bia;
  if v_periodo is distinct from tstzrange(
       '2036-11-22 19:00:00-03'::timestamptz,
       '2036-11-22 20:00:00-03'::timestamptz) then
    raise exception
      'FALHOU [M1]: a escalação da Bia (outra missa) não deveria mudar, mas o período está em: %',
      v_periodo;
  end if;

  -- ---------- Teste M2: mover para horário conflitante é bloqueado ----------
  -- A Ana está às 10:00 (missa A). Mover a missa B (15:00) para 10:30 conflita.
  v_bloqueou := false;
  begin
    update public.missas
       set inicio = '2036-11-29 10:30:00-03'
     where id = v_mb;
  exception
    when exclusion_violation then
      v_bloqueou := true;
  end;
  if not v_bloqueou then
    raise exception
      'FALHOU [M2]: a missa foi movida para um horário que conflita com outra missa da Ana';
  end if;

  select inicio into v_inicio from public.missas where id = v_mb;
  if v_inicio is distinct from '2036-11-29 15:00:00-03'::timestamptz then
    raise exception
      'FALHOU [M2]: a missa deveria ter ficado no horário original (15:00), mas está em: %',
      v_inicio;
  end if;

  -- ---------- Teste M3: exatamente 1h depois da outra missa é permitido ----------
  begin
    update public.missas
       set inicio = '2036-11-29 11:00:00-03'
     where id = v_mb;
  exception
    when exclusion_violation then
      raise exception
        'FALHOU [M3]: 10:00 e 11:00 não deveriam conflitar (a primeira termina quando a segunda começa)';
  end;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where coroinha_id in (v_ana, v_bia);
  delete from public.missas where id in (v_m1800, v_m1900, v_ma, v_mb);
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_ana, v_bia); -- remove os perfis junto

  raise notice 'PASSOU: testes M1, M2 e M3';
end;
$$;
