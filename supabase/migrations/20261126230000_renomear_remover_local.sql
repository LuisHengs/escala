-- Migration 23: o admin renomeia e remove locais.
-- renomear_local: mesmas validações de criar_local; o nome continua único
--   sem diferenciar maiúsculas (índice da migration 22).
-- remover_local: só remove local sem missas (LOCAL_EM_USO caso contrário);
--   nunca apaga missas junto.
-- Rode UMA vez no SQL Editor do projeto escala-dev.

create function public.renomear_local(p_id uuid, p_nome text)
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
  if not exists (select 1 from public.locais l where l.id = p_id) then
    raise exception 'LOCAL_INEXISTENTE';
  end if;

  begin
    update public.locais set nome = btrim(p_nome)
    where id = p_id
    returning * into v_local;
  exception
    when unique_violation then
      raise exception 'LOCAL_DUPLICADO';
  end;

  return v_local;
end;
$$;

create function public.remover_local(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;
  if not exists (select 1 from public.locais l where l.id = p_id) then
    raise exception 'LOCAL_INEXISTENTE';
  end if;
  if exists (select 1 from public.missas m where m.local_id = p_id) then
    raise exception 'LOCAL_EM_USO';
  end if;

  delete from public.locais where id = p_id;
end;
$$;

revoke execute on function public.renomear_local(uuid, text) from public, anon;
revoke execute on function public.remover_local(uuid)        from public, anon;
grant  execute on function public.renomear_local(uuid, text) to authenticated;
grant  execute on function public.remover_local(uuid)        to authenticated;
