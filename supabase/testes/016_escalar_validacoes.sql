-- Testes S1 a S5: escalar valida a missa e o coroinha.
--   [S1] coroinha que não existe -> COROINHA_INEXISTENTE (e não um erro cru
--        de chave estrangeira)
--   [S2] coroinha INATIVO não pode ser escalado -> COROINHA_INATIVO
--   [S3] missa que não existe -> MISSA_INEXISTENTE
--   [S4] [guarda] a permissão vem ANTES: quem não é admin recebe
--        NAO_AUTORIZADO e não descobre se a missa ou o coroinha existem
--   [S5] [guarda] reativado, o coroinha volta a poder ser escalado
--
-- Por que existe: definir_ativo impede desativar quem tem missa futura, mas
-- nada impedia escalar alguém que JÁ estava inativo. Essa pessoa não enxerga
-- nada no app (eh_membro() nega tudo), então nunca confirmaria presença.
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [..]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

-- Ajudante temporário: roda um comando SQL "como" um usuário logado e devolve
-- a mensagem de erro (ou nulo, se deu certo). Some quando a sessão termina.
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
  v_ana   uuid := gen_random_uuid(); -- coroinha ativa
  v_bia   uuid := gen_random_uuid(); -- coroinha INATIVA
  v_local uuid := gen_random_uuid();
  v_m5h   uuid := gen_random_uuid(); -- missa daqui a 5h
  v_erro  text;
  v_qtd   int;
begin
  -- ---------- Preparação (como dono do banco) ----------
  insert into auth.users (id) values (v_adm), (v_ana), (v_bia);
  insert into public.perfis (id, nome, papel, ativo) values
    (v_adm, 'Coordenador (teste)', 'admin',    true),
    (v_ana, 'Ana (teste)',         'coroinha', true),
    (v_bia, 'Bia (teste)',         'coroinha', false);
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id)
    values (v_m5h, now() + interval '5 hours', v_local);

  -- ---------- S1: coroinha que não existe ----------
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L::uuid, %L::uuid, %L)',
           v_m5h, gen_random_uuid(), 'turiferário'), v_adm);
  if v_erro is distinct from 'COROINHA_INEXISTENTE' then
    raise exception 'FALHOU [S1]: esperado COROINHA_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro: escalou alguém que não existe)');
  end if;

  -- ---------- S2: coroinha inativo ----------
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L::uuid, %L::uuid, %L)',
           v_m5h, v_bia, 'turiferário'), v_adm);
  if v_erro is distinct from 'COROINHA_INATIVO' then
    raise exception 'FALHOU [S2]: esperado COROINHA_INATIVO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: escalou um coroinha inativo)');
  end if;

  -- ---------- S3: missa que não existe ----------
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L::uuid, %L::uuid, %L)',
           gen_random_uuid(), v_ana, 'turiferário'), v_adm);
  if v_erro is distinct from 'MISSA_INEXISTENTE' then
    raise exception 'FALHOU [S3]: esperado MISSA_INEXISTENTE, mas veio: %',
      coalesce(v_erro, '(nenhum erro: escalou numa missa que não existe)');
  end if;

  -- ---------- S4: a permissão vem antes de tudo ----------
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L::uuid, %L::uuid, %L)',
           gen_random_uuid(), gen_random_uuid(), 'turiferário'), v_ana);
  if v_erro is distinct from 'NAO_AUTORIZADO' then
    raise exception
      'FALHOU [S4]: coroinha comum deveria receber NAO_AUTORIZADO (sem saber se a missa ou o coroinha existem), mas veio: %',
      coalesce(v_erro, '(nenhum erro)');
  end if;

  -- Nada pode ter sido gravado pelas quatro tentativas negadas.
  select count(*) into v_qtd from public.escalacoes where missa_id = v_m5h;
  if v_qtd <> 0 then
    raise exception 'FALHOU [S4]: as tentativas negadas não deveriam gravar nada, mas há % escalação(ões)', v_qtd;
  end if;

  -- ---------- S5: reativado, pode ser escalado ----------
  update public.perfis set ativo = true where id = v_bia;
  v_erro := pg_temp.tentar(
    format('select public.escalar(%L::uuid, %L::uuid, %L)',
           v_m5h, v_bia, 'turiferário'), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [S5]: a Bia reativada deveria poder ser escalada, mas veio o erro: %', v_erro;
  end if;
  if not exists (select 1 from public.escalacoes
                  where missa_id = v_m5h and coroinha_id = v_bia) then
    raise exception 'FALHOU [S5]: a escalação da Bia deveria ter sido gravada';
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where missa_id = v_m5h;
  delete from public.missas where id = v_m5h;
  delete from public.locais where id = v_local;
  delete from auth.users where id in (v_adm, v_ana, v_bia); -- remove os perfis junto

  raise notice 'PASSOU: testes S1 a S5';
end;
$$;
