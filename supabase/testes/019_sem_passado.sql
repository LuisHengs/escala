-- Testes SP1 a SP6: o passado não se mexe.
--   [SP1] criar_missa com horário que já passou -> HORARIO_NO_PASSADO (nada
--         é gravado)
--   [SP2] editar_missa de uma missa que JÁ COMEÇOU -> MISSA_JA_COMECOU (a
--         missa continua como estava)
--   [SP3] editar_missa para um horário que já passou -> HORARIO_NO_PASSADO (a
--         missa continua no horário de antes)
--   [SP4] escalar numa missa que JÁ COMEÇOU -> MISSA_JA_COMECOU (nada é
--         gravado)
--   [SP5] [guarda] no futuro tudo continua funcionando: criar, editar e
--         escalar
--   [SP6] [guarda] a permissão vem ANTES: coroinha comum criando missa no
--         passado recebe NAO_AUTORIZADO
--
-- Decisão (21/11/2026): escalar, editar e criar missa só valem para missa que
-- ainda não começou; o histórico não é reescrito.
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
  v_adm    uuid := gen_random_uuid();
  v_ana    uuid := gen_random_uuid();
  v_bia    uuid := gen_random_uuid();
  v_local  uuid;
  v_agora  timestamptz := date_trunc('hour', now());
  v_pass   uuid; -- missa que já começou (1 hora atrás)
  v_fut    uuid; -- missa futura (daqui a 3 dias)
  v_erro   text;
  v_qtd    int;
  v_inicio timestamptz;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana), (v_bia);
  insert into public.perfis (id, nome, papel, ativo) values
    (v_adm, 'Coordenador (teste)', 'admin', true),
    (v_ana, 'Ana (teste)', 'coroinha', true),
    (v_bia, 'Bia (teste)', 'coroinha', true);
  insert into public.locais (nome) values ('Matriz (teste passado)')
    returning id into v_local;
  insert into public.missas (inicio, local_id)
    values (now() - interval '1 hour', v_local) returning id into v_pass;
  insert into public.missas (inicio, local_id)
    values (v_agora + interval '3 days', v_local) returning id into v_fut;

  -- ---------- SP1: criar missa no passado ----------
  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L, %L)',
           now() - interval '2 days', v_local), v_adm);
  select count(*) into v_qtd from public.missas
   where local_id = v_local and inicio < now() - interval '1 day';
  if v_erro is distinct from 'HORARIO_NO_PASSADO' or v_qtd <> 0 then
    raise exception 'FALHOU [SP1]: criar missa no passado deveria dar HORARIO_NO_PASSADO e não gravar nada; veio: %, gravadas: %',
      coalesce(v_erro, '(nenhum erro)'), v_qtd;
  end if;

  -- ---------- SP2: editar missa que já começou ----------
  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L, %L, %L)',
           v_pass, v_agora + interval '5 days', v_local), v_adm);
  select inicio into v_inicio from public.missas where id = v_pass;
  if v_erro is distinct from 'MISSA_JA_COMECOU' or v_inicio > now() then
    raise exception 'FALHOU [SP2]: editar missa que já começou deveria dar MISSA_JA_COMECOU e mantê-la; veio: %, início: %',
      coalesce(v_erro, '(nenhum erro)'), v_inicio;
  end if;

  -- ---------- SP3: editar para um horário passado ----------
  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L, %L, %L)',
           v_fut, now() - interval '3 days', v_local), v_adm);
  select inicio into v_inicio from public.missas where id = v_fut;
  if v_erro is distinct from 'HORARIO_NO_PASSADO'
     or v_inicio is distinct from v_agora + interval '3 days' then
    raise exception 'FALHOU [SP3]: mover para o passado deveria dar HORARIO_NO_PASSADO e manter o horário; veio: %, início: %',
      coalesce(v_erro, '(nenhum erro)'), v_inicio;
  end if;

  -- ---------- SP4: escalar em missa que já começou ----------
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L, %L, %L)', v_pass, v_ana, 'turiferário'),
    v_adm);
  select count(*) into v_qtd from public.escalacoes where missa_id = v_pass;
  if v_erro is distinct from 'MISSA_JA_COMECOU' or v_qtd <> 0 then
    raise exception 'FALHOU [SP4]: escalar em missa que já começou deveria dar MISSA_JA_COMECOU e não gravar; veio: %, escalações: %',
      coalesce(v_erro, '(nenhum erro)'), v_qtd;
  end if;

  -- ---------- SP5: [guarda] no futuro tudo continua funcionando ----------
  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L, %L)',
           v_agora + interval '10 days', v_local), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [SP5]: criar missa no futuro deveria funcionar; veio: %', v_erro;
  end if;

  v_erro := pg_temp.tentar(
    format('select public.editar_missa(%L, %L, %L)',
           v_fut, v_agora + interval '4 days', v_local), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [SP5]: editar missa futura para outro horário futuro deveria funcionar; veio: %', v_erro;
  end if;

  v_erro := pg_temp.tentar(
    format('select public.escalar(%L, %L, %L)', v_fut, v_bia, 'turiferário'),
    v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [SP5]: escalar em missa futura deveria funcionar; veio: %', v_erro;
  end if;

  -- ---------- SP6: [guarda] a permissão vem antes ----------
  v_erro := pg_temp.tentar(
    format('select public.criar_missa(%L, %L)',
           now() - interval '2 days', v_local), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception 'FALHOU [SP6]: coroinha comum criando missa no passado deveria dar NAO_AUTORIZADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- ---------- Limpeza ----------
  delete from public.escalacoes where missa_id in
    (select id from public.missas where local_id = v_local);
  delete from public.missas where local_id = v_local;
  delete from public.locais where id = v_local;
  delete from public.perfis where id in (v_adm, v_ana, v_bia);
  delete from auth.users where id in (v_adm, v_ana, v_bia);
end;
$$;
