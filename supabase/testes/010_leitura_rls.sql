-- Testes L1 a L5c: quem lê o quê (políticas de acesso, RLS).
--   [L1]  um membro (perfil ativo) enxerga as tabelas da escala
--   [L2]  quem tem login mas NÃO tem perfil não enxerga nada
--   [L3]  quem não está logado (anon) não enxerga nada
--   [L4]  dados do responsável: o próprio lê o seu, não lê o dos outros;
--         o admin lê todos
--   [L5a] um coroinha NÃO consegue se promover a admin
--   [L5b] escrita direta numa tabela é negada (só as funções escrevem)
--   [L5c] apagar direto numa tabela não apaga nada
--
-- Este teste usa os dados de teste e conta só as linhas CRIADAS por ele,
-- então não depende do que já existe no banco.
--
-- ATENÇÃO: na fase vermelha, L2, L3 e L5 passam "por acaso", porque sem
-- nenhuma política tudo já é negado. Eles são testes de GUARDA: servem para
-- pegar um excesso de permissão quando as políticas forem criadas.
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_local   uuid := gen_random_uuid();
  v_adm     uuid := gen_random_uuid();
  v_ana     uuid := gen_random_uuid();
  v_bia     uuid := gen_random_uuid();
  v_intruso uuid := gen_random_uuid(); -- tem login, mas NÃO tem perfil
  v_missa   uuid := gen_random_uuid();
  v_esc     uuid;
  v_troca   uuid;
  v_qtd     int;
  v_linhas  int;
  v_ok      boolean;
  v_papel   text;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana), (v_bia), (v_intruso);
  insert into public.perfis (id, nome, papel) values
    (v_adm, 'Coordenador (teste)', 'admin'),
    (v_ana, 'Ana (teste)', 'coroinha'),
    (v_bia, 'Bia (teste)', 'coroinha');
  insert into public.dados_responsavel (perfil_id, responsavel_nome) values
    (v_ana, 'Responsável da Ana (teste)'),
    (v_bia, 'Responsável da Bia (teste)');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id)
    values (v_missa, now() + interval '5 hours', v_local);
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_missa, v_ana, 'turiferário') returning id into v_esc;
  insert into public.trocas (escalacao_id) values (v_esc) returning id into v_troca;

  -- Linhas de teste visíveis a um MEMBRO: 1 local + 1 missa + 3 perfis
  -- + 1 escalação + 1 troca = 7 (os dados do responsável contam à parte).

  -- ---------- L1: um membro enxerga a escala ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select (select count(*) from public.locais     where id = v_local)
       + (select count(*) from public.missas     where id = v_missa)
       + (select count(*) from public.perfis     where id in (v_adm, v_ana, v_bia))
       + (select count(*) from public.escalacoes where id = v_esc)
       + (select count(*) from public.trocas     where id = v_troca)
    into v_qtd;
  reset role;

  if v_qtd <> 7 then
    raise exception
      'FALHOU [L1]: a Ana (membro) deveria enxergar 7 linhas de teste (local, missa, 3 perfis, escalação, troca), mas enxerga %', v_qtd;
  end if;

  -- ---------- L2: quem tem login mas não tem perfil não enxerga nada ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_intruso, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select (select count(*) from public.locais     where id = v_local)
       + (select count(*) from public.missas     where id = v_missa)
       + (select count(*) from public.perfis     where id in (v_adm, v_ana, v_bia))
       + (select count(*) from public.escalacoes where id = v_esc)
       + (select count(*) from public.trocas     where id = v_troca)
       + (select count(*) from public.dados_responsavel where perfil_id in (v_ana, v_bia))
    into v_qtd;
  reset role;

  if v_qtd <> 0 then
    raise exception
      'FALHOU [L2]: quem não tem perfil não deveria enxergar nada, mas enxerga % linha(s)', v_qtd;
  end if;

  -- ---------- L3: quem não está logado (anon) não enxerga nada ----------
  perform set_config('request.jwt.claims',
    json_build_object('role', 'anon')::text, true);
  set local role anon;
  begin
    select (select count(*) from public.locais     where id = v_local)
         + (select count(*) from public.missas     where id = v_missa)
         + (select count(*) from public.perfis     where id in (v_adm, v_ana, v_bia))
         + (select count(*) from public.escalacoes where id = v_esc)
         + (select count(*) from public.trocas     where id = v_troca)
         + (select count(*) from public.dados_responsavel where perfil_id in (v_ana, v_bia))
      into v_qtd;
  exception
    when insufficient_privilege then
      v_qtd := 0; -- negar o acesso por completo também vale
  end;
  reset role;

  if v_qtd <> 0 then
    raise exception
      'FALHOU [L3]: quem não está logado não deveria enxergar nada, mas enxerga % linha(s)', v_qtd;
  end if;

  -- ---------- L4: dados do responsável ----------
  -- A Ana lê o dela, e não o da Bia.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_qtd
    from public.dados_responsavel where perfil_id = v_ana;
  v_linhas := (select count(*) from public.dados_responsavel where perfil_id = v_bia);
  reset role;

  if v_qtd <> 1 then
    raise exception 'FALHOU [L4]: a Ana deveria ler os próprios dados de responsável (1 linha), mas lê %', v_qtd;
  end if;
  if v_linhas <> 0 then
    raise exception 'FALHOU [L4]: a Ana NÃO deveria ler os dados de responsável da Bia, mas lê % linha(s)', v_linhas;
  end if;

  -- O admin lê os de todos.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_qtd
    from public.dados_responsavel where perfil_id in (v_ana, v_bia);
  reset role;

  if v_qtd <> 2 then
    raise exception 'FALHOU [L4]: o admin deveria ler os dados de responsável de todos (2 linhas), mas lê %', v_qtd;
  end if;

  -- ---------- L5a: um coroinha não consegue se promover a admin ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.perfis set papel = 'admin' where id = v_ana;
  get diagnostics v_linhas = row_count;
  reset role;

  select papel into v_papel from public.perfis where id = v_ana;
  if v_linhas <> 0 or v_papel is distinct from 'coroinha' then
    raise exception
      'FALHOU [L5a]: a Ana não deveria conseguir mudar o próprio papel (linhas alteradas=%, papel agora=%)',
      v_linhas, v_papel;
  end if;

  -- ---------- L5b: escrita direta é negada ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_ok := false;
  begin
    insert into public.escalacoes (missa_id, coroinha_id, funcao)
      values (v_missa, v_bia, 'cruciferário');
  exception
    when insufficient_privilege then
      v_ok := true; -- negado pela RLS, como esperado
  end;
  reset role;

  if not v_ok then
    raise exception 'FALHOU [L5b]: a Ana conseguiu inserir direto numa tabela (deveria ser negado)';
  end if;

  -- ---------- L5c: apagar direto não apaga nada ----------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  delete from public.escalacoes where id = v_esc;
  get diagnostics v_linhas = row_count;
  reset role;

  if v_linhas <> 0
     or not exists (select 1 from public.escalacoes where id = v_esc) then
    raise exception 'FALHOU [L5c]: a Ana não deveria conseguir apagar a escalação direto na tabela';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where coroinha_id in (v_ana, v_bia); -- leva as trocas junto
  delete from public.missas where id = v_missa;
  delete from public.locais where id = v_local;
  delete from auth.users
   where id in (v_adm, v_ana, v_bia, v_intruso); -- remove perfis e dados junto

  raise notice 'PASSOU: testes L1 a L5c';
end;
$$;
