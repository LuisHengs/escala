-- Testes V1 a V10: convites (gerar e resgatar).
--   [V1]  o admin gera um convite: código de 8 caracteres, gravado só como
--         hash, com validade de 7 dias
--   [V2]  coroinha comum não gera convite -> NAO_AUTORIZADO
--   [V3]  quem tem login mas não tem perfil resgata o código: nasce o perfil
--         (coroinha, ativo), os dados do responsável e o convite fica usado.
--         O código vale em minúsculas e com espaços nas pontas.
--   [V4]  convite já usado -> CONVITE_USADO
--   [V5]  código que não existe -> CONVITE_INVALIDO
--   [V6]  convite vencido -> CONVITE_EXPIRADO
--   [V7]  quem já tem perfil não resgata de novo -> JA_TEM_PERFIL
--   [V8]  nome ou responsável vazios são recusados SEM gastar o convite
--   [V9]  só quem está logado tem direito de executar as funções
--   [V10] o admin lê os convites; o coroinha não
--
-- (VERSÃO 2: o V9 passou a conferir gerar_convite(boolean), a nova assinatura.)
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_adm      uuid := gen_random_uuid();
  v_ana      uuid := gen_random_uuid();
  v_novo     uuid := gen_random_uuid(); -- tem login, sem perfil: vai resgatar (V3)
  v_outro    uuid := gen_random_uuid(); -- tem login, sem perfil: só tentativas que falham
  v_codigo   text;
  v_expira   timestamptz;
  v_perfil   public.perfis;
  v_erro     text;
  v_qtd      int;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana), (v_novo), (v_outro);
  insert into public.perfis (id, nome, papel) values
    (v_adm, 'Coordenador (teste)', 'admin'),
    (v_ana, 'Ana (teste)', 'coroinha');

  -- ---------- V1: o admin gera um convite ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select public.gerar_convite() into v_codigo;
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [V1]: o admin deveria conseguir gerar um convite, mas veio o erro: %', v_erro;
  end if;
  if v_codigo !~ '^[A-HJ-NP-Z2-9]{8}$' then
    raise exception
      'FALHOU [V1]: o código deveria ter 8 caracteres sem 0, O, 1 e I, mas veio: %', v_codigo;
  end if;

  select expira_em into v_expira
    from public.convites
   where codigo_hash = public.hash_convite(v_codigo);
  if not found then
    raise exception 'FALHOU [V1]: o convite deveria ter sido gravado (procurado pelo hash)';
  end if;
  if v_expira < now() + interval '6 days 23 hours'
     or v_expira > now() + interval '7 days 1 hour' then
    raise exception 'FALHOU [V1]: a validade deveria ser de 7 dias, mas expira em %', v_expira;
  end if;
  if exists (select 1 from public.convites where codigo_hash = v_codigo) then
    raise exception 'FALHOU [V1]: o código NÃO pode ser gravado em texto, só o hash';
  end if;

  -- ---------- V2: coroinha comum não gera convite ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.gerar_convite();
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [V2]: esperado o erro NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: um coroinha gerou convite)');
  end if;

  -- ---------- V3: quem tem login e não tem perfil resgata o convite ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_novo, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_perfil from public.resgatar_convite(
      '  ' || lower(v_codigo) || '  ', 'Novo Coroinha', 'Responsável do Novo');
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [V3]: o resgate deveria funcionar, mas veio o erro: %', v_erro;
  end if;
  if v_perfil.id is distinct from v_novo
     or v_perfil.nome is distinct from 'Novo Coroinha'
     or v_perfil.papel is distinct from 'coroinha'
     or not v_perfil.ativo then
    raise exception 'FALHOU [V3]: o perfil deveria nascer como coroinha ativo com o nome informado';
  end if;
  if not exists (
    select 1 from public.dados_responsavel
     where perfil_id = v_novo and responsavel_nome = 'Responsável do Novo'
  ) then
    raise exception 'FALHOU [V3]: os dados do responsável deveriam ter sido gravados';
  end if;
  if not exists (
    select 1 from public.convites
     where codigo_hash = public.hash_convite(v_codigo)
       and usado_em is not null and usado_por = v_novo
  ) then
    raise exception 'FALHOU [V3]: o convite deveria ficar marcado como usado pelo novo perfil';
  end if;

  -- ---------- V4: o mesmo convite não vale duas vezes ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_outro, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.resgatar_convite(v_codigo, 'Outro', 'Responsável do Outro');
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'CONVITE_USADO' then
    raise exception 'FALHOU [V4]: esperado o erro CONVITE_USADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: um convite já usado foi aceito)');
  end if;
  if exists (select 1 from public.perfis where id = v_outro) then
    raise exception 'FALHOU [V4]: nenhum perfil deveria ter sido criado';
  end if;

  -- ---------- V5: código que não existe ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_outro, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.resgatar_convite('NAOEXIST', 'Outro', 'Responsável do Outro');
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'CONVITE_INVALIDO' then
    raise exception 'FALHOU [V5]: esperado o erro CONVITE_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- V6: convite vencido ----------
  insert into public.convites (codigo_hash, criado_por, expira_em)
    values (public.hash_convite('VENCIDO2'), v_adm, now() - interval '1 day');

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_outro, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.resgatar_convite('VENCIDO2', 'Outro', 'Responsável do Outro');
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'CONVITE_EXPIRADO' then
    raise exception 'FALHOU [V6]: esperado o erro CONVITE_EXPIRADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: um convite vencido foi aceito)');
  end if;

  -- ---------- V7: quem já tem perfil não resgata de novo ----------
  insert into public.convites (codigo_hash, criado_por, expira_em)
    values (public.hash_convite('VALIDO22'), v_adm, now() + interval '7 days');

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.resgatar_convite('VALIDO22', 'Ana de novo', 'Responsável');
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'JA_TEM_PERFIL' then
    raise exception 'FALHOU [V7]: esperado o erro JA_TEM_PERFIL, mas veio: %',
      coalesce(v_erro, '(nenhum erro: quem já tem perfil resgatou outro convite)');
  end if;

  -- ---------- V8: nome ou responsável vazios não gastam o convite ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_outro, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.resgatar_convite('VALIDO22', '   ', 'Responsável');
  exception
    when others then v_erro := sqlerrm;
  end;
  if v_erro is distinct from 'NOME_INVALIDO' then
    reset role;
    raise exception 'FALHOU [V8]: esperado o erro NOME_INVALIDO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: aceitou nome vazio)');
  end if;

  v_erro := null;
  begin
    perform public.resgatar_convite('VALIDO22', 'Outro', '');
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;
  if v_erro is distinct from 'RESPONSAVEL_OBRIGATORIO' then
    raise exception 'FALHOU [V8]: esperado o erro RESPONSAVEL_OBRIGATORIO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: aceitou responsável vazio)');
  end if;

  if exists (select 1 from public.convites
              where codigo_hash = public.hash_convite('VALIDO22')
                and usado_em is not null)
     or exists (select 1 from public.perfis where id = v_outro) then
    raise exception 'FALHOU [V8]: depois dos pedidos recusados, o convite deveria continuar livre e nenhum perfil criado';
  end if;

  -- ---------- V9: só quem está logado executa as funções ----------
  if has_function_privilege('anon', 'public.gerar_convite(boolean)', 'execute')
     or has_function_privilege('anon', 'public.resgatar_convite(text, text, text)', 'execute') then
    raise exception 'FALHOU [V9]: o papel anon (sem login) não deveria poder executar as funções de convite';
  end if;
  if not has_function_privilege('authenticated', 'public.gerar_convite(boolean)', 'execute')
     or not has_function_privilege('authenticated', 'public.resgatar_convite(text, text, text)', 'execute') then
    raise exception 'FALHOU [V9]: o papel authenticated (logado) deveria poder executar as funções de convite';
  end if;

  -- ---------- V10: o admin lê os convites; o coroinha não ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_qtd from public.convites where criado_por = v_adm;
  reset role;
  if v_qtd <> 0 then
    raise exception 'FALHOU [V10]: o coroinha não deveria enxergar convites, mas enxerga %', v_qtd;
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_qtd from public.convites where criado_por = v_adm;
  reset role;
  if v_qtd < 3 then
    raise exception 'FALHOU [V10]: o admin deveria enxergar os 3 convites de teste, mas enxerga %', v_qtd;
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.convites where criado_por = v_adm;
  delete from auth.users
   where id in (v_adm, v_ana, v_novo, v_outro); -- remove perfis e dados junto

  raise notice 'PASSOU: testes V1 a V10';
end;
$$;
