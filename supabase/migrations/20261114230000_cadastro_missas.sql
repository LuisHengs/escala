-- Migration 14: cadastro de locais e missas pelo admin.
-- RODE SOMENTE DEPOIS de ver o teste 013 falhar com "FALHOU [C1]".
--
-- Como as demais escritas, não há política de insert/update: quem grava são
-- funções (security definer) que conferem a permissão por dentro.
--
-- Mover o horário de uma missa é PERMITIDO (decisão dos testes 003 e 004):
-- o período das escalações acompanha, a presença confirmada é mantida e só o
-- conflito de horário bloqueia (CONFLITO_DE_HORARIO).

-- ---------- criar_local ----------
create function public.criar_local(p_nome text)
returns public.locais
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_local public.locais;
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;
  if p_nome is null or btrim(p_nome) = '' then
    raise exception 'NOME_INVALIDO';
  end if;

  begin
    insert into public.locais (nome)
    values (btrim(p_nome))
    returning * into v_local;
  exception
    when unique_violation then
      raise exception 'LOCAL_DUPLICADO';
  end;

  return v_local;
end;
$$;

-- ---------- criar_missa ----------
create function public.criar_missa(p_inicio timestamptz, p_local_id uuid)
returns public.missas
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_missa public.missas;
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;
  if p_inicio is null then
    raise exception 'HORARIO_INVALIDO';
  end if;
  if not exists (select 1 from public.locais l where l.id = p_local_id) then
    raise exception 'LOCAL_INEXISTENTE';
  end if;

  insert into public.missas (inicio, local_id)
  values (p_inicio, p_local_id)
  returning * into v_missa;

  return v_missa;
end;
$$;

-- ---------- editar_missa ----------
-- Troca horário e local. Se o novo horário conflitar com outra escalação de
-- algum escalado, o gatilho da migration 4 atualiza o período, a restrição de
-- exclusão rejeita, e o comando inteiro é desfeito (a missa não muda).
create function public.editar_missa(
  p_missa_id uuid,
  p_inicio   timestamptz,
  p_local_id uuid
)
returns public.missas
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_missa public.missas;
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;
  if not exists (select 1 from public.missas m where m.id = p_missa_id) then
    raise exception 'MISSA_INEXISTENTE';
  end if;
  if p_inicio is null then
    raise exception 'HORARIO_INVALIDO';
  end if;
  if not exists (select 1 from public.locais l where l.id = p_local_id) then
    raise exception 'LOCAL_INEXISTENTE';
  end if;

  begin
    update public.missas
       set inicio = p_inicio,
           local_id = p_local_id
     where id = p_missa_id
    returning * into v_missa;
  exception
    when exclusion_violation then
      raise exception 'CONFLITO_DE_HORARIO';
  end;

  return v_missa;
end;
$$;

-- ---------- Direitos de execução ----------
revoke execute on function public.criar_local(text)                        from public, anon;
revoke execute on function public.criar_missa(timestamptz, uuid)           from public, anon;
revoke execute on function public.editar_missa(uuid, timestamptz, uuid)    from public, anon;
grant  execute on function public.criar_local(text)                        to authenticated;
grant  execute on function public.criar_missa(timestamptz, uuid)           to authenticated;
grant  execute on function public.editar_missa(uuid, timestamptz, uuid)   to authenticated;
