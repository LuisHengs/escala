-- Testes EL1 a EL8: escala livre (o coroinha se escala sozinho).
--   [EL1] criar_missa aceita "escala livre" (padrão: desligada); só admin
--   [EL2] editar_missa muda a escala livre; sem informar, mantém como estava
--   [EL3] auto_escalar: entra como "A definir", confirmado, marcado como
--         auto-escalado, e o coroinha é sempre quem está logado
--   [EL4] auto_escalar recusa: missa inexistente, escala não livre, missa que
--         já começou, já escalado nela, conflito de horário, perfil inativo;
--         nenhuma escalação é gravada nesses casos
--   [EL5] auto_desescalar: sai da escala e a vaga volta (pode entrar de novo)
--   [EL6] auto_desescalar recusa: não escalado, escalado pelo administrador
--         (SAIDA_NAO_PERMITIDA), missa que já começou, e a escalação de OUTRA
--         pessoa nunca é tocada
--   [EL7] desligar a escala livre não tira quem já entrou; novos não entram
--   [EL8] anon não executa as funções; authenticated executa
--
-- Decisões (conversa de 20/11/2026): sem limite de vagas; função fixa
-- "A definir" (o administrador ajusta depois); o coroinha sai até o início da
-- missa, mas só da escala que ele mesmo escolheu; entra como confirmado.
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

create or replace function pg_temp.tentar(p_sql text, p_uid uuid)
returns text
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
  execute p_sql;
  reset role;
  return null;
exception
  when others then
    reset role;
    return sqlerrm;
end;
$$;

do $$
declare
  v_adm   uuid := gen_random_uuid();
  v_ana   uuid := gen_random_uuid();
  v_bia   uuid := gen_random_uuid();
  v_ina   uuid := gen_random_uuid(); -- inativa
  v_local uuid;
  v_m1    uuid; -- livre, daqui a 3 dias
  v_m2    uuid; -- NÃO livre
  v_mconf uuid; -- livre, 30 min depois da m1 (conflita com ela)
  v_mpass uuid; -- livre, mas já começou
  v_madm  uuid; -- livre; a Ana é escalada nela pelo administrador
  v_t1    timestamptz := date_trunc('hour', now()) + interval '3 days';
  v_erro  text;
  v_qtd   int;
  v_esc   public.escalacoes;
  v_livre boolean;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana), (v_bia), (v_ina);
  insert into public.perfis (id, nome, papel, ativo) values
    (v_adm, 'Coordenador (teste)', 'admin', true),
    (v_ana, 'Ana (teste)', 'coroinha', true),
    (v_bia, 'Bia (teste)', 'coroinha', true),
    (v_ina, 'Ina (teste)', 'coroinha', false);
  insert into public.locais (nome) values ('Matriz (teste livre)')
    returning id into v_local;

  -- ---------- EL1: criar_missa com escala livre ----------
  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L::timestamptz, %L::uuid)', v_t1, v_local), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [EL1]: criar_missa sem o parâmetro novo deveria continuar valendo, mas veio: %', v_erro;
  end if;
  select m.id, m.escala_livre into v_m1, v_livre from public.missas m where m.inicio = v_t1;
  if v_livre is distinct from false then
    raise exception 'FALHOU [EL1]: sem informar, a escala livre deveria ficar desligada, mas está %', v_livre;
  end if;
  delete from public.missas where id = v_m1;

  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L::timestamptz, %L::uuid, true)', v_t1, v_local), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [EL1]: o admin deveria criar a missa com escala livre, mas veio: %', v_erro;
  end if;
  select m.id, m.escala_livre into v_m1, v_livre from public.missas m where m.inicio = v_t1;
  if v_livre is distinct from true then
    raise exception 'FALHOU [EL1]: a missa deveria ter escala livre ligada, mas está %', v_livre;
  end if;

  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L::timestamptz, %L::uuid, true)', v_t1 + interval '1 day', v_local), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [EL1]: coroinha comum não cria missa; esperado NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- Missas de apoio para os demais testes (criadas como dono do banco).
  insert into public.missas (inicio, local_id, escala_livre)
    values (v_t1 + interval '1 day', v_local, false) returning id into v_m2;
  insert into public.missas (inicio, local_id, escala_livre)
    values (v_t1 + interval '30 minutes', v_local, true) returning id into v_mconf;
  insert into public.missas (inicio, local_id, escala_livre)
    values (now() - interval '2 hours', v_local, true) returning id into v_mpass;
  insert into public.missas (inicio, local_id, escala_livre)
    values (v_t1 + interval '2 days', v_local, true) returning id into v_madm;

  -- ---------- EL2: editar_missa ----------
  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid)', v_m1, v_t1, v_local), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [EL2]: editar_missa sem o parâmetro novo deveria continuar valendo, mas veio: %', v_erro;
  end if;
  select escala_livre into v_livre from public.missas where id = v_m1;
  if v_livre is distinct from true then
    raise exception 'FALHOU [EL2]: sem informar, a escala livre deveria ser mantida (ligada), mas está %', v_livre;
  end if;

  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid, false)', v_m1, v_t1, v_local), v_adm);
  select escala_livre into v_livre from public.missas where id = v_m1;
  if v_erro is not null or v_livre is distinct from false then
    raise exception 'FALHOU [EL2]: o admin deveria desligar a escala livre (erro: %, valor: %)',
      coalesce(v_erro, '(nenhum)'), v_livre;
  end if;
  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid, true)', v_m1, v_t1, v_local), v_adm);
  select escala_livre into v_livre from public.missas where id = v_m1;
  if v_erro is not null or v_livre is distinct from true then
    raise exception 'FALHOU [EL2]: o admin deveria ligar a escala livre (erro: %, valor: %)',
      coalesce(v_erro, '(nenhum)'), v_livre;
  end if;

  -- ---------- EL3: auto_escalar (caminho feliz) ----------
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', v_m1), v_ana);
  if v_erro is not null then
    raise exception 'FALHOU [EL3]: a Ana deveria conseguir se escalar, mas veio: %', v_erro;
  end if;
  select * into v_esc from public.escalacoes where missa_id = v_m1 and coroinha_id = v_ana;
  if not found then
    raise exception 'FALHOU [EL3]: a escalação da Ana não foi gravada';
  end if;
  if v_esc.funcao <> 'A definir' or v_esc.status <> 'confirmado'
     or v_esc.auto_escalada is distinct from true or v_esc.confirmado_com_atraso then
    raise exception 'FALHOU [EL3]: esperado função "A definir", confirmado, auto_escalada e sem atraso; veio % / % / % / %',
      v_esc.funcao, v_esc.status, v_esc.auto_escalada, v_esc.confirmado_com_atraso;
  end if;

  -- ---------- EL4: auto_escalar recusa ----------
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', gen_random_uuid()), v_bia);
  if v_erro is distinct from 'MISSA_INEXISTENTE' then
    raise exception 'FALHOU [EL4]: missa inexistente deveria dar MISSA_INEXISTENTE, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', v_m2), v_bia);
  if v_erro is distinct from 'ESCALA_NAO_LIVRE' then
    raise exception 'FALHOU [EL4]: missa sem escala livre deveria dar ESCALA_NAO_LIVRE, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', v_mpass), v_bia);
  if v_erro is distinct from 'MISSA_JA_COMECOU' then
    raise exception 'FALHOU [EL4]: missa que já começou deveria dar MISSA_JA_COMECOU, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', v_m1), v_ana);
  if v_erro is distinct from 'JA_ESCALADO_NA_MISSA' then
    raise exception 'FALHOU [EL4]: escalar de novo na mesma missa deveria dar JA_ESCALADO_NA_MISSA, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', v_mconf), v_ana);
  if v_erro is distinct from 'CONFLITO_DE_HORARIO' then
    raise exception 'FALHOU [EL4]: missa 30 min depois da outra deveria dar CONFLITO_DE_HORARIO, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', v_m1), v_ina);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [EL4]: perfil inativo deveria dar NAO_AUTORIZADO, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  select count(*) into v_qtd from public.escalacoes
   where missa_id in (v_m2, v_mpass, v_mconf) or coroinha_id in (v_bia, v_ina);
  if v_qtd <> 0 then
    raise exception 'FALHOU [EL4]: nenhuma escalação deveria ter sido gravada nos casos recusados, mas há %', v_qtd;
  end if;

  -- ---------- EL5: auto_desescalar (a vaga volta) ----------
  v_erro := pg_temp.tentar(format('select public.auto_desescalar(%L::uuid)', v_m1), v_ana);
  if v_erro is not null then
    raise exception 'FALHOU [EL5]: a Ana deveria conseguir sair da escala que escolheu, mas veio: %', v_erro;
  end if;
  select count(*) into v_qtd from public.escalacoes where missa_id = v_m1;
  if v_qtd <> 0 then
    raise exception 'FALHOU [EL5]: a escalação da Ana deveria ter sido removida, mas há %', v_qtd;
  end if;
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', v_m1), v_ana);
  if v_erro is not null then
    raise exception 'FALHOU [EL5]: depois de sair, a Ana deveria poder entrar de novo, mas veio: %', v_erro;
  end if;
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', v_m1), v_bia);
  if v_erro is not null then
    raise exception 'FALHOU [EL5]: sem limite de vagas, a Bia também deveria entrar, mas veio: %', v_erro;
  end if;
  select count(*) into v_qtd from public.escalacoes where missa_id = v_m1;
  if v_qtd <> 2 then
    raise exception 'FALHOU [EL5]: deveriam existir 2 escalados (Ana e Bia), mas há %', v_qtd;
  end if;

  -- ---------- EL6: auto_desescalar recusa ----------
  -- (a) quem não está escalado: a Ina... usamos o admin, que não entrou
  v_erro := pg_temp.tentar(format('select public.auto_desescalar(%L::uuid)', v_m1), v_adm);
  if v_erro is distinct from 'ESCALACAO_NAO_ENCONTRADA' then
    raise exception 'FALHOU [EL6]: quem não está escalado deveria dar ESCALACAO_NAO_ENCONTRADA, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  -- (b) escalada pelo administrador: não sai sozinha (usa pedir troca)
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L::uuid, %L::uuid, %L)', v_madm, v_ana, 'turiferário'), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [EL6]: preparação: o admin deveria conseguir escalar a Ana, mas veio: %', v_erro;
  end if;
  v_erro := pg_temp.tentar(format('select public.auto_desescalar(%L::uuid)', v_madm), v_ana);
  if v_erro is distinct from 'SAIDA_NAO_PERMITIDA' then
    raise exception 'FALHOU [EL6]: escalada pelo admin não sai sozinha; esperado SAIDA_NAO_PERMITIDA, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  select count(*) into v_qtd from public.escalacoes where missa_id = v_madm and coroinha_id = v_ana;
  if v_qtd <> 1 then
    raise exception 'FALHOU [EL6]: a escalação feita pelo admin deveria continuar, mas há %', v_qtd;
  end if;
  -- (c) missa que já começou (escalação marcada como auto-escalada)
  insert into public.escalacoes (missa_id, coroinha_id, funcao, status, auto_escalada)
    values (v_mpass, v_bia, 'A definir', 'confirmado', true);
  v_erro := pg_temp.tentar(format('select public.auto_desescalar(%L::uuid)', v_mpass), v_bia);
  if v_erro is distinct from 'MISSA_JA_COMECOU' then
    raise exception 'FALHOU [EL6]: sair de missa que já começou deveria dar MISSA_JA_COMECOU, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  select count(*) into v_qtd from public.escalacoes where missa_id = v_mpass;
  if v_qtd <> 1 then
    raise exception 'FALHOU [EL6]: a escalação da missa que já começou deveria continuar, mas há %', v_qtd;
  end if;
  -- (d) nunca toca na escalação de outra pessoa: a Ina chama para a missa m1
  v_erro := pg_temp.tentar(format('select public.auto_desescalar(%L::uuid)', v_m1), v_ina);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [EL6]: perfil inativo deveria dar NAO_AUTORIZADO, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  select count(*) into v_qtd from public.escalacoes where missa_id = v_m1;
  if v_qtd <> 2 then
    raise exception 'FALHOU [EL6]: Ana e Bia deveriam continuar escaladas na m1, mas há %', v_qtd;
  end if;

  -- ---------- EL7: desligar a escala livre ----------
  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L::uuid, %L::timestamptz, %L::uuid, false)', v_m1, v_t1, v_local), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [EL7]: o admin deveria desligar a escala livre, mas veio: %', v_erro;
  end if;
  select count(*) into v_qtd from public.escalacoes where missa_id = v_m1;
  if v_qtd <> 2 then
    raise exception 'FALHOU [EL7]: quem já entrou deveria continuar escalado, mas há %', v_qtd;
  end if;
  delete from public.escalacoes where missa_id = v_m1 and coroinha_id = v_bia;
  v_erro := pg_temp.tentar(format('select public.auto_escalar(%L::uuid)', v_m1), v_bia);
  if v_erro is distinct from 'ESCALA_NAO_LIVRE' then
    raise exception 'FALHOU [EL7]: com a escala livre desligada, novos não entram; esperado ESCALA_NAO_LIVRE, mas veio: %', coalesce(v_erro, '(nenhum erro)');
  end if;
  v_erro := pg_temp.tentar(format('select public.auto_desescalar(%L::uuid)', v_m1), v_ana);
  if v_erro is not null then
    raise exception 'FALHOU [EL7]: quem entrou ainda pode sair com a escala livre desligada, mas veio: %', v_erro;
  end if;

  -- ---------- EL8: direitos de execução ----------
  if has_function_privilege('anon', 'public.auto_escalar(uuid)', 'execute')
     or has_function_privilege('anon', 'public.auto_desescalar(uuid)', 'execute')
     or has_function_privilege('anon', 'public.criar_missa(timestamptz, uuid, boolean)', 'execute')
     or has_function_privilege('anon', 'public.editar_missa(uuid, timestamptz, uuid, boolean)', 'execute') then
    raise exception 'FALHOU [EL8]: o papel anon (sem login) não deveria executar as funções da escala livre';
  end if;
  if not has_function_privilege('authenticated', 'public.auto_escalar(uuid)', 'execute')
     or not has_function_privilege('authenticated', 'public.auto_desescalar(uuid)', 'execute')
     or not has_function_privilege('authenticated', 'public.criar_missa(timestamptz, uuid, boolean)', 'execute')
     or not has_function_privilege('authenticated', 'public.editar_missa(uuid, timestamptz, uuid, boolean)', 'execute') then
    raise exception 'FALHOU [EL8]: o papel authenticated (logado) deveria executar as funções da escala livre';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where missa_id in (v_m1, v_m2, v_mconf, v_mpass, v_madm);
  delete from public.missas where id in (v_m1, v_m2, v_mconf, v_mpass, v_madm);
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_adm, v_ana, v_bia, v_ina); -- remove os perfis junto

  raise notice 'PASSOU: testes EL1 a EL8';
end;
$$;
