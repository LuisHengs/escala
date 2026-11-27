-- Teste M4: [decisão de negócio] mover o horário da missa NÃO desfaz
-- presenças já confirmadas. O coroinha continua "confirmado".
--
-- Este teste já nasce verde: ele não pede código novo, só protege a decisão.
-- Se um dia alguém mudar o gatilho do horário e ele passar a resetar a
-- presença, este teste falha.
--
-- COMO RODAR: cole TUDO no SQL Editor e clique em Run.
--   Sucesso -> "Success. No rows returned" (nenhum dado de teste fica no banco)
--   Falha   -> erro vermelho começando com "FALHOU [M4]: ..."
-- Se der qualquer OUTRO erro, ele não é do teste: cole a mensagem na conversa.

do $$
declare
  v_local  uuid := gen_random_uuid();
  v_ana    uuid := gen_random_uuid();
  v_missa  uuid := gen_random_uuid();
  v_status text;
  v_atraso boolean;
begin
  -- ---------- Preparação ----------
  insert into auth.users (id) values (v_ana);
  insert into public.perfis (id, nome) values (v_ana, 'Ana (teste)');
  insert into public.locais (id, nome) values (v_local, 'Local de teste');
  insert into public.missas (id, inicio, local_id)
    values (v_missa, '2036-11-22 18:00:00-03', v_local);
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (v_missa, v_ana, 'turiferário');

  -- A função de confirmar ainda não existe, então a confirmação é feita direto.
  update public.escalacoes
     set status = 'confirmado'
   where missa_id = v_missa and coroinha_id = v_ana;

  -- ---------- Teste M4: o horário da missa muda ----------
  update public.missas
     set inicio = '2036-11-22 20:00:00-03'
   where id = v_missa;

  select status, confirmado_com_atraso into v_status, v_atraso
    from public.escalacoes
   where missa_id = v_missa and coroinha_id = v_ana;

  if v_status is distinct from 'confirmado' then
    raise exception
      'FALHOU [M4]: a presença confirmada deveria continuar "confirmado" depois de mudar o horário, mas está: %',
      v_status;
  end if;

  -- ---------- Limpeza (só chega aqui se tudo passou) ----------
  delete from public.escalacoes where coroinha_id = v_ana;
  delete from public.missas where id = v_missa;
  delete from public.locais where id = v_local;
  delete from auth.users where id = v_ana; -- remove o perfil junto

  raise notice 'PASSOU: teste M4';
end;
$$;
