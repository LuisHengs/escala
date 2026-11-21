-- Testes FP1 a FP4: escalar() sem função vira "A definir".
--   [FP1] função vazia ('')              -> "A definir"
--   [FP2] função só com espaços ('   ')  -> "A definir"
--   [FP3] função nula                    -> "A definir" (e não um erro técnico)
--   [FP4] [guarda] função informada é mantida, sem os espaços das pontas
--
-- Por que existe: a tela de escalar passa a deixar a função em branco (como
-- na escala livre, onde a função é "A definir"). Antes, uma função nula dava
-- um erro técnico de coluna obrigatória, e uma vazia gravava um texto vazio.
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
  v_cai   uuid := gen_random_uuid();
  v_dan   uuid := gen_random_uuid();
  v_local uuid;
  v_m1    uuid;
  v_t1    timestamptz := date_trunc('hour', now()) + interval '3 days';
  v_erro  text;
  v_funcao text;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana), (v_bia), (v_cai), (v_dan);
  insert into public.perfis (id, nome, papel, ativo) values
    (v_adm, 'Coordenador (teste)', 'admin', true),
    (v_ana, 'Ana (teste)', 'coroinha', true),
    (v_bia, 'Bia (teste)', 'coroinha', true),
    (v_cai, 'Caio (teste)', 'coroinha', true),
    (v_dan, 'Dani (teste)', 'coroinha', true);
  insert into public.locais (nome) values ('Matriz (teste função)')
    returning id into v_local;
  insert into public.missas (inicio, local_id) values (v_t1, v_local)
    returning id into v_m1;

  -- ---------- FP1: função vazia ----------
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L, %L, %L)', v_m1, v_ana, ''), v_adm);
  select e.funcao into v_funcao from public.escalacoes e
   where e.missa_id = v_m1 and e.coroinha_id = v_ana;
  if v_erro is not null or v_funcao is distinct from 'A definir' then
    raise exception 'FALHOU [FP1]: função vazia deveria virar "A definir"; erro: %, função: %',
      coalesce(v_erro, '(nenhum)'), coalesce(v_funcao, '(sem escalação)');
  end if;

  -- ---------- FP2: só espaços ----------
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L, %L, %L)', v_m1, v_bia, '   '), v_adm);
  select e.funcao into v_funcao from public.escalacoes e
   where e.missa_id = v_m1 and e.coroinha_id = v_bia;
  if v_erro is not null or v_funcao is distinct from 'A definir' then
    raise exception 'FALHOU [FP2]: função só com espaços deveria virar "A definir"; erro: %, função: %',
      coalesce(v_erro, '(nenhum)'), coalesce(v_funcao, '(sem escalação)');
  end if;

  -- ---------- FP3: função nula ----------
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L, %L, null)', v_m1, v_cai), v_adm);
  select e.funcao into v_funcao from public.escalacoes e
   where e.missa_id = v_m1 and e.coroinha_id = v_cai;
  if v_erro is not null or v_funcao is distinct from 'A definir' then
    raise exception 'FALHOU [FP3]: função nula deveria virar "A definir"; erro: %, função: %',
      coalesce(v_erro, '(nenhum)'), coalesce(v_funcao, '(sem escalação)');
  end if;

  -- ---------- FP4: [guarda] função informada é mantida (sem espaços nas pontas) ----------
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L, %L, %L)', v_m1, v_dan, '  turiferário '), v_adm);
  select e.funcao into v_funcao from public.escalacoes e
   where e.missa_id = v_m1 and e.coroinha_id = v_dan;
  if v_erro is not null or v_funcao is distinct from 'turiferário' then
    raise exception 'FALHOU [FP4]: função informada deveria ser mantida como "turiferário"; erro: %, função: %',
      coalesce(v_erro, '(nenhum)'), coalesce(v_funcao, '(sem escalação)');
  end if;

  -- ---------- Limpeza ----------
  delete from public.escalacoes where missa_id = v_m1;
  delete from public.missas where id = v_m1;
  delete from public.locais where id = v_local;
  delete from public.perfis where id in (v_adm, v_ana, v_bia, v_cai, v_dan);
  delete from auth.users where id in (v_adm, v_ana, v_bia, v_cai, v_dan);
end;
$$;
