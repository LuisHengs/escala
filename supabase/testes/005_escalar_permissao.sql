-- Testes P1, P2 e P3: quem pode chamar a função escalar().
--   [P1] coroinha comum chama escalar -> NAO_AUTORIZADO (e nada é gravado)
--   [P2] admin chama escalar -> funciona
--   [P3] quem não está logado (anon) não tem direito de executar a função
--
-- TÉCNICA: para "entrar" como alguém, o teste preenche o login de mentira
-- (request.jwt.claims, de onde auth.uid() lê o id) e troca o papel do banco
-- para "authenticated", que é o papel que o app usa de verdade.
-- Depois volta ao papel normal com "reset role" para conferir e limpar.
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
  v_missa uuid := gen_random_uuid();
  v_e     public.escalacoes;
  v_erro  text;
  v_qtd   int;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana);
  insert into public.perfis (id, nome, papel) values
    (v_adm, 'Coordenador (teste)', 'admin'),
    (v_ana, 'Ana (teste)', 'coroinha');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id)
    values (v_missa, '2036-11-22 18:00:00-03', v_local);

  -- ---------- Teste P1: coroinha comum NÃO pode escalar ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;

  v_erro := null;
  begin
    perform public.escalar(v_missa, v_ana, 'turiferário');
  exception
    when others then
      v_erro := sqlerrm;
  end;

  reset role;

  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception
      'FALHOU [P1]: esperado o erro NAO_AUTORIZADO para coroinha comum, mas veio: %',
      coalesce(v_erro, '(nenhum erro: o coroinha conseguiu escalar)');
  end if;

  select count(*) into v_qtd from public.escalacoes where missa_id = v_missa;
  if v_qtd <> 0 then
    raise exception 'FALHOU [P1]: nada deveria ter sido gravado, mas há % escalação(ões)', v_qtd;
  end if;

  -- ---------- Teste P2: admin PODE escalar ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;

  v_erro := null;
  begin
    select * into v_e from public.escalar(v_missa, v_ana, 'turiferário');
  exception
    when others then
      v_erro := sqlerrm;
  end;

  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [P2]: o admin deveria conseguir escalar, mas veio o erro: %', v_erro;
  end if;
  if v_e.coroinha_id is distinct from v_ana or v_e.status is distinct from 'pendente' then
    raise exception 'FALHOU [P2]: a escalação deveria nascer com a Ana, como pendente';
  end if;

  -- ---------- Teste P3: quem não está logado não executa a função ----------
  if has_function_privilege('anon', 'public.escalar(uuid, uuid, text)', 'execute') then
    raise exception 'FALHOU [P3]: o papel anon (sem login) não deveria poder executar escalar()';
  end if;
  if not has_function_privilege('authenticated', 'public.escalar(uuid, uuid, text)', 'execute') then
    raise exception 'FALHOU [P3]: o papel authenticated (logado) deveria poder executar escalar()';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where missa_id = v_missa;
  delete from public.missas where id = v_missa;
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_adm, v_ana); -- remove os perfis junto

  raise notice 'PASSOU: testes P1, P2 e P3';
end;
$$;
