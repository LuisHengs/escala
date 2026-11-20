-- Testes W1 a W6: convite que dispensa o responsável (para adultos).
--   [W1] o admin gera convite que NÃO exige responsável
--   [W2] sem informar nada, o convite exige responsável (o padrão protege)
--   [W3] adulto resgata convite sem responsável: nasce o perfil e NÃO nasce
--        registro em dados_responsavel (só se guarda o que é necessário)
--   [W4] convite que não exige responsável ignora o nome do responsável,
--        mesmo que alguém o informe
--   [W5] convite que exige responsável continua recusando responsável vazio,
--        sem gastar o convite
--   [W6] só quem está logado tem direito de executar a nova função
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_adm      uuid := gen_random_uuid();
  v_adulto1  uuid := gen_random_uuid(); -- login sem perfil
  v_adulto2  uuid := gen_random_uuid(); -- login sem perfil
  v_menor    uuid := gen_random_uuid(); -- login sem perfil
  v_cod_a1   text;
  v_cod_a2   text;
  v_cod_menor text;
  v_exige    boolean;
  v_perfil   public.perfis;
  v_erro     text;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_adulto1), (v_adulto2), (v_menor);
  insert into public.perfis (id, nome, papel)
    values (v_adm, 'Coordenador (teste)', 'admin');

  -- ---------- W1: convite que NÃO exige responsável ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select public.gerar_convite(false) into v_cod_a1;
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [W1]: o admin deveria conseguir gerar um convite sem responsável, mas veio o erro: %', v_erro;
  end if;
  select exige_responsavel into v_exige
    from public.convites where codigo_hash = public.hash_convite(v_cod_a1);
  if v_exige is distinct from false then
    raise exception 'FALHOU [W1]: o convite deveria ficar com exige_responsavel = false, mas está: %', v_exige;
  end if;

  -- ---------- W2: sem informar nada, exige responsável ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select public.gerar_convite() into v_cod_menor;
  reset role;

  select exige_responsavel into v_exige
    from public.convites where codigo_hash = public.hash_convite(v_cod_menor);
  if v_exige is distinct from true then
    raise exception 'FALHOU [W2]: o convite padrão deveria exigir responsável, mas exige_responsavel está: %', v_exige;
  end if;

  -- ---------- W3: adulto resgata sem responsável ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adulto1, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    select * into v_perfil from public.resgatar_convite(v_cod_a1, 'Adulto Um', null);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [W3]: o adulto deveria conseguir resgatar sem responsável, mas veio o erro: %', v_erro;
  end if;
  if v_perfil.id is distinct from v_adulto1
     or v_perfil.nome is distinct from 'Adulto Um'
     or not v_perfil.ativo then
    raise exception 'FALHOU [W3]: o perfil deveria nascer ativo com o nome informado';
  end if;
  if exists (select 1 from public.dados_responsavel where perfil_id = v_adulto1) then
    raise exception 'FALHOU [W3]: não deveria existir registro de responsável para quem entrou com convite de adulto';
  end if;

  -- ---------- W4: o nome do responsável é ignorado quando não é exigido ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select public.gerar_convite(false) into v_cod_a2;
  reset role;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adulto2, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.resgatar_convite(v_cod_a2, 'Adulto Dois', 'Alguém Qualquer');
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is not null then
    raise exception 'FALHOU [W4]: informar um responsável a mais não deveria dar erro, mas veio: %', v_erro;
  end if;
  if exists (select 1 from public.dados_responsavel where perfil_id = v_adulto2) then
    raise exception 'FALHOU [W4]: o nome do responsável deveria ser ignorado neste convite (não é necessário)';
  end if;

  -- ---------- W5: convite padrão continua exigindo o responsável ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_menor, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_erro := null;
  begin
    perform public.resgatar_convite(v_cod_menor, 'Menor', null);
  exception
    when others then v_erro := sqlerrm;
  end;
  reset role;

  if v_erro is distinct from 'RESPONSAVEL_OBRIGATORIO' then
    raise exception 'FALHOU [W5]: esperado o erro RESPONSAVEL_OBRIGATORIO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: o convite padrão aceitou responsável vazio)');
  end if;
  if exists (select 1 from public.convites
              where codigo_hash = public.hash_convite(v_cod_menor)
                and usado_em is not null)
     or exists (select 1 from public.perfis where id = v_menor) then
    raise exception 'FALHOU [W5]: o convite deveria continuar livre e nenhum perfil criado';
  end if;

  -- ---------- W6: só quem está logado executa a função ----------
  if has_function_privilege('anon', 'public.gerar_convite(boolean)', 'execute') then
    raise exception 'FALHOU [W6]: o papel anon (sem login) não deveria poder executar gerar_convite()';
  end if;
  if not has_function_privilege('authenticated', 'public.gerar_convite(boolean)', 'execute') then
    raise exception 'FALHOU [W6]: o papel authenticated (logado) deveria poder executar gerar_convite()';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.convites where criado_por = v_adm;
  delete from auth.users
   where id in (v_adm, v_adulto1, v_adulto2, v_menor); -- remove perfis e dados junto

  raise notice 'PASSOU: testes W1 a W6';
end;
$$;
