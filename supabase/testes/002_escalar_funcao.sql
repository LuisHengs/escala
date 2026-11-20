-- Testes 1, 3 e 2d: a função escalar().   (VERSÃO 2: entra como admin)
--   [1]  escalar coroinha livre funciona e a escalação nasce pendente
--   [3]  mesma missa duas vezes -> erro JA_ESCALADO_NA_MISSA
--   [2d] missa com início a menos de 1h -> erro CONFLITO_DE_HORARIO
--
-- Desde a migration 5, escalar() só aceita admin. Por isso este teste agora
-- "entra" como admin (login de mentira + papel authenticated) antes de chamar.
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [n]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_local uuid := gen_random_uuid();
  v_adm   uuid := gen_random_uuid();
  v_ana   uuid := gen_random_uuid();
  v_m1800 uuid := gen_random_uuid();
  v_m1830 uuid := gen_random_uuid();
  v_e     public.escalacoes;
  v_erro  text;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana);
  insert into public.perfis (id, nome, papel) values
    (v_adm, 'Coordenador (teste)', 'admin'),
    (v_ana, 'Ana (teste)', 'coroinha');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id) values
    (v_m1800, '2026-11-22 18:00:00-03', v_local),
    (v_m1830, '2026-11-22 18:30:00-03', v_local);

  -- ---------- Entra como admin ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- ---------- Teste 1: escalar coroinha livre ----------
  select * into v_e from public.escalar(v_m1800, v_ana, 'turiferário');
  if v_e.coroinha_id is distinct from v_ana
     or v_e.missa_id is distinct from v_m1800
     or v_e.status is distinct from 'pendente' then
    raise exception 'FALHOU [1]: a escalação deveria nascer com a Ana, na missa das 18:00, como pendente';
  end if;

  -- ---------- Teste 3: mesma missa duas vezes ----------
  v_erro := null;
  begin
    perform public.escalar(v_m1800, v_ana, 'cruciferário');
  exception
    when others then
      v_erro := sqlerrm;
  end;
  if v_erro is distinct from 'JA_ESCALADO_NA_MISSA' then
    raise exception 'FALHOU [3]: esperado o erro JA_ESCALADO_NA_MISSA, mas veio: %',
      coalesce(v_erro, '(nenhum erro: a escalação duplicada foi aceita)');
  end if;

  -- ---------- Teste 2d: conflito de horário (18:30 com 18:00) ----------
  v_erro := null;
  begin
    perform public.escalar(v_m1830, v_ana, 'turiferário');
  exception
    when others then
      v_erro := sqlerrm;
  end;
  if v_erro is distinct from 'CONFLITO_DE_HORARIO' then
    raise exception 'FALHOU [2d]: esperado o erro CONFLITO_DE_HORARIO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: a escalação conflitante foi aceita)');
  end if;

  -- ---------- Volta ao papel normal e limpa (só se tudo passou) ----------
  reset role;
  delete from public.escalacoes where coroinha_id = v_ana;
  delete from public.missas where id in (v_m1800, v_m1830);
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_adm, v_ana); -- remove os perfis junto

  raise notice 'PASSOU: testes 1, 3 e 2d';
end;
$$;
