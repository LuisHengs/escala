-- Testes LD1 a LD3: nome de local não diferencia maiúsculas de minúsculas.
--   [LD1] "Matriz" já existe -> "matriz" e "MATRIZ" dão LOCAL_DUPLICADO
--   [LD2] nada extra é gravado (continua 1 local com esse nome, em qualquer caixa)
--   [LD3] um nome realmente diferente continua sendo aceito
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
  v_adm  uuid := gen_random_uuid();
  v_erro text;
  v_qtd  int;
begin
  insert into auth.users (id) values (v_adm);
  insert into public.perfis (id, nome, papel)
  values (v_adm, 'Coordenador (teste)', 'admin');

  v_erro := pg_temp.tentar(format('select public.criar_local(%L)', 'Matriz (teste caixa)'), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [LD1]: o primeiro local deveria ser criado, mas veio: %', v_erro;
  end if;

  -- ---------- LD1: mesma palavra com outra caixa ----------
  v_erro := pg_temp.tentar(format('select public.criar_local(%L)', 'matriz (teste caixa)'), v_adm);
  if v_erro is distinct from 'LOCAL_DUPLICADO' then
    raise exception 'FALHOU [LD1]: "matriz (teste caixa)" deveria dar LOCAL_DUPLICADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: o local duplicado foi criado)');
  end if;
  v_erro := pg_temp.tentar(format('select public.criar_local(%L)', 'MATRIZ (TESTE CAIXA)'), v_adm);
  if v_erro is distinct from 'LOCAL_DUPLICADO' then
    raise exception 'FALHOU [LD1]: "MATRIZ (TESTE CAIXA)" deveria dar LOCAL_DUPLICADO, mas veio: %',
      coalesce(v_erro, '(nenhum erro: o local duplicado foi criado)');
  end if;

  -- ---------- LD2: nada extra gravado ----------
  select count(*) into v_qtd from public.locais
  where lower(nome) = 'matriz (teste caixa)';
  if v_qtd <> 1 then
    raise exception 'FALHOU [LD2]: deveria existir 1 local com esse nome (em qualquer caixa), mas há %', v_qtd;
  end if;

  -- ---------- LD3: nome diferente continua valendo ----------
  v_erro := pg_temp.tentar(format('select public.criar_local(%L)', 'Capela (teste caixa)'), v_adm);
  if v_erro is not null then
    raise exception 'FALHOU [LD3]: um nome diferente deveria ser aceito, mas veio: %', v_erro;
  end if;

  -- Limpeza
  delete from public.locais where nome in ('Matriz (teste caixa)', 'Capela (teste caixa)');
  delete from public.perfis where id = v_adm;
  delete from auth.users where id = v_adm;
end;
$$;
