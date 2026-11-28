-- Migration 23: o admin apaga uma pessoa que deixou de participar (LGPD).
-- Só apaga quem está INATIVO (PESSOA_ATIVA caso contrário): desativar vem
-- antes, e já exige que a pessoa não tenha missas futuras.
-- Apaga: as trocas em que ela foi a substituta, as escalações dela (com as
-- trocas delas, em cascata) e o login (auth.users), que leva junto o perfil e
-- os dados do responsável. A escalação de quem pediu a troca continua.
-- Rode UMA vez no SQL Editor do projeto escala-dev.

create function public.apagar_pessoa(p_perfil_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ativo boolean;
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  select p.ativo into v_ativo from public.perfis p
   where p.id = p_perfil_id for update;
  if not found then
    raise exception 'PERFIL_INEXISTENTE';
  end if;
  if v_ativo then
    raise exception 'PESSOA_ATIVA';
  end if;

  delete from public.trocas t where t.substituto_id = p_perfil_id;
  delete from public.escalacoes e where e.coroinha_id = p_perfil_id;
  delete from auth.users u where u.id = p_perfil_id;
end;
$$;

revoke execute on function public.apagar_pessoa(uuid) from public, anon;
grant  execute on function public.apagar_pessoa(uuid) to authenticated;
