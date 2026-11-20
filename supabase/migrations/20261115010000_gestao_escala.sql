-- Migration 16: o admin corrige a escala e gere membros e missas.
-- RODE SOMENTE DEPOIS de ver o teste 015 falhar com "FALHOU [E1]".
--
-- Como as demais escritas, não há política de update/delete: quem grava são
-- funções (security definer) que conferem a permissão por dentro.
--
-- Decisões (travadas pelo teste 015):
--  * desescalar: só missa FUTURA (a que já começou preserva o histórico);
--  * remover_missa: só missa SEM escalados (nada some em cascata);
--  * desativar alguém com missa futura é bloqueado: desescale antes;
--  * o sistema nunca fica sem admin ativo.

-- ---------- Auxiliar: ainda sobra outro admin? ----------
-- Trava os admins ativos ("for update") para que dois admins rebaixando um ao
-- outro ao mesmo tempo não zerem a lista. Uso interno: ninguém a chama de fora.

create function public.exigir_outro_admin(p_excluir uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1
    from public.perfis p
   where p.papel = 'admin' and p.ativo
     for update;

  if not exists (
    select 1
      from public.perfis p
     where p.papel = 'admin' and p.ativo and p.id <> p_excluir
  ) then
    raise exception 'ULTIMO_ADMIN';
  end if;
end;
$$;

revoke execute on function public.exigir_outro_admin(uuid) from public, anon, authenticated;

-- ---------- desescalar ----------
create function public.desescalar(p_escalacao_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inicio timestamptz;
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  select m.inicio
    into v_inicio
    from public.escalacoes e
    join public.missas m on m.id = e.missa_id
   where e.id = p_escalacao_id
     for update of e;

  if not found then
    raise exception 'ESCALACAO_NAO_ENCONTRADA';
  end if;
  -- Mesma regra do Dart: a missa começou quando agora >= início.
  if v_inicio <= now() then
    raise exception 'MISSA_JA_COMECOU';
  end if;

  -- As trocas da escalação saem junto (on delete cascade).
  delete from public.escalacoes where id = p_escalacao_id;
end;
$$;

-- ---------- definir_ativo ----------
create function public.definir_ativo(p_perfil_id uuid, p_ativo boolean)
returns public.perfis
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_perfil public.perfis;
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;
  if p_ativo is null then
    raise exception 'VALOR_INVALIDO';
  end if;

  select p.*
    into v_perfil
    from public.perfis p
   where p.id = p_perfil_id
     for update;
  if not found then
    raise exception 'PERFIL_INEXISTENTE';
  end if;

  if not p_ativo then
    if v_perfil.papel = 'admin' and v_perfil.ativo then
      perform public.exigir_outro_admin(p_perfil_id);
    end if;
    if exists (
      select 1
        from public.escalacoes e
        join public.missas m on m.id = e.missa_id
       where e.coroinha_id = p_perfil_id
         and m.inicio > now()
    ) then
      raise exception 'TEM_ESCALACOES_FUTURAS';
    end if;
  end if;

  update public.perfis
     set ativo = p_ativo
   where id = p_perfil_id
  returning * into v_perfil;

  return v_perfil;
end;
$$;

-- ---------- definir_papel ----------
create function public.definir_papel(p_perfil_id uuid, p_papel text)
returns public.perfis
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_perfil public.perfis;
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;
  if p_papel is null or p_papel not in ('admin', 'coroinha') then
    raise exception 'PAPEL_INVALIDO';
  end if;

  select p.*
    into v_perfil
    from public.perfis p
   where p.id = p_perfil_id
     for update;
  if not found then
    raise exception 'PERFIL_INEXISTENTE';
  end if;

  if v_perfil.papel = 'admin' and v_perfil.ativo and p_papel <> 'admin' then
    perform public.exigir_outro_admin(p_perfil_id);
  end if;

  update public.perfis
     set papel = p_papel
   where id = p_perfil_id
  returning * into v_perfil;

  return v_perfil;
end;
$$;

-- ---------- remover_missa ----------
create function public.remover_missa(p_missa_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  perform 1 from public.missas m where m.id = p_missa_id for update;
  if not found then
    raise exception 'MISSA_INEXISTENTE';
  end if;
  if exists (select 1 from public.escalacoes e where e.missa_id = p_missa_id) then
    raise exception 'MISSA_COM_ESCALADOS';
  end if;

  delete from public.missas where id = p_missa_id;
end;
$$;

-- ---------- Direitos de execução ----------
revoke execute on function public.desescalar(uuid)               from public, anon;
revoke execute on function public.definir_ativo(uuid, boolean)   from public, anon;
revoke execute on function public.definir_papel(uuid, text)      from public, anon;
revoke execute on function public.remover_missa(uuid)            from public, anon;
grant  execute on function public.desescalar(uuid)               to authenticated;
grant  execute on function public.definir_ativo(uuid, boolean)   to authenticated;
grant  execute on function public.definir_papel(uuid, text)      to authenticated;
grant  execute on function public.remover_missa(uuid)            to authenticated;
