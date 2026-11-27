-- Testes B1, B2 e C1 a C6: confirmar presença.
--   [B1] exatamente 2h antes da missa já conta como "passou do prazo"
--   [B2] 2h01 antes ainda está no prazo
--   [C1] titular confirma dentro do prazo -> confirmado, sem atraso
--   [C2] titular confirma depois do prazo -> confirmado, COM atraso (permitido)
--   [C3] outro coroinha não confirma por ele -> NAO_AUTORIZADO
--   [C4] escalação que não existe -> ESCALACAO_NAO_ENCONTRADA
--   [C5] confirmar de novo não altera o atraso já registrado
--   [C6] só quem está logado tem direito de executar a função
--
-- O relógio é o do banco (now()), e o teste não consegue mudá-lo. Por isso as
-- missas são criadas RELATIVAS ao momento da execução (daqui a 1h, 5h, 8h), e
-- a regra exata do prazo é testada à parte, na função pura passou_do_prazo(),
-- que recebe a hora como parâmetro (B1 e B2).
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_ref     timestamptz := '2036-11-22 18:00:00-03';
  v_local   uuid := gen_random_uuid();
  v_ana     uuid := gen_random_uuid();
  v_bia     uuid := gen_random_uuid();
  v_m5h     uuid := gen_random_uuid(); -- daqui a 5h: dentro do prazo
  v_m1h     uuid := gen_random_uuid(); -- daqui a 1h: já passou das 2h antes
  v_m8h     uuid := gen_random_uuid(); -- daqui a 8h
  v_esc5h   uuid;
  v_esc1h   uuid;
  v_esc8h   uuid;
  v_escbia  uuid;
  v_e       public.escalacoes;
  v_erro    text;
begin
  -- ---------- B1 e B2: a regra exata do prazo (função pura) ----------
  if not public.passou_do_prazo(v_ref, v_ref - interval '2 hours') then
    raise exception 'FALHOU [B1]: exatamente 2h antes da missa já deveria contar como passou do prazo';
  end if;
  if public.passou_do_prazo(v_ref, v_ref - interval '2 hours 1 minute') then
    raise exception 'FALHOU [B2]: 2h01 antes da missa ainda deveria estar dentro do prazo';
  end if;

  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_ana), (v_bia);
  insert into public.perfis (id, nome) values
    (v_ana, 'Ana (teste)'), (v_bia, 'Bia (teste)');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id) values
    (v_m5h, now() + interval '5 hours', v_local),
    (v_m1h, now() + interval '1 hour',  v_local),
    (v_m8h, now() + interval '8 hours', v_local);

  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m5h, v_ana, 'turiferário') returning id into v_esc5h;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m1h, v_ana, 'turiferário') returning id into v_esc1h;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m8h, v_ana, 'turiferário') returning id into v_esc8h;
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_m1h, v_bia, 'cruciferário') returning id into v_escbia;

  -- ---------- C1: titular confirma dentro do prazo ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_e from public.confirmar_presenca(v_esc5h);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [C1]: a titular deveria conseguir confirmar, mas veio o erro: %', v_erro;
  end if;
  if v_e.status is distinct from 'confirmado' or v_e.confirmado_com_atraso then
    raise exception
      'FALHOU [C1]: deveria ficar confirmado SEM atraso, mas veio status=% atraso=%',
      v_e.status, v_e.confirmado_com_atraso;
  end if;

  -- ---------- C2: titular confirma depois do prazo ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_e from public.confirmar_presenca(v_esc1h);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [C2]: confirmar atrasado deveria ser permitido, mas veio o erro: %', v_erro;
  end if;
  if v_e.status is distinct from 'confirmado' or not v_e.confirmado_com_atraso then
    raise exception
      'FALHOU [C2]: deveria ficar confirmado COM atraso, mas veio status=% atraso=%',
      v_e.status, v_e.confirmado_com_atraso;
  end if;

  -- ---------- C3: outro coroinha não confirma por ela ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bia, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.confirmar_presenca(v_esc8h);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [C3]: esperado o erro NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: a Bia confirmou a presença da Ana)');
  end if;
  if (select status from public.escalacoes where id = v_esc8h) <> 'pendente' then
    raise exception 'FALHOU [C3]: a escalação da Ana deveria continuar pendente';
  end if;

  -- ---------- C4: escalação que não existe ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.confirmar_presenca(gen_random_uuid());
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'ESCALACAO_NAO_ENCONTRADA' then
    raise exception 'FALHOU [C4]: esperado o erro ESCALACAO_NAO_ENCONTRADA, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- C5: confirmar de novo não altera o atraso já registrado ----------
  -- A Bia já confirmou NO PRAZO (preparado direto no banco), mas a missa agora
  -- está a 1h, então um recálculo marcaria atraso. Não pode marcar.
  update public.escalacoes
     set status = 'confirmado', confirmado_com_atraso = false
   where id = v_escbia;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_bia, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_e from public.confirmar_presenca(v_escbia);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [C5]: confirmar de novo não deveria dar erro, mas veio: %', v_erro;
  end if;
  if v_e.confirmado_com_atraso then
    raise exception 'FALHOU [C5]: confirmar de novo não deveria marcar atraso em quem confirmou no prazo';
  end if;

  -- ---------- C6: só quem está logado executa a função ----------
  if has_function_privilege('anon', 'public.confirmar_presenca(uuid)', 'execute') then
    raise exception 'FALHOU [C6]: o papel anon (sem login) não deveria poder executar confirmar_presenca()';
  end if;
  if not has_function_privilege('authenticated', 'public.confirmar_presenca(uuid)', 'execute') then
    raise exception 'FALHOU [C6]: o papel authenticated (logado) deveria poder executar confirmar_presenca()';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where coroinha_id in (v_ana, v_bia);
  delete from public.missas where id in (v_m5h, v_m1h, v_m8h);
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_ana, v_bia); -- remove os perfis junto

  raise notice 'PASSOU: testes B1, B2 e C1 a C6';
end;
$$;
