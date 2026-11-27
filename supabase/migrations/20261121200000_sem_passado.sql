-- Migration 20: o passado não se mexe.
-- RODE SOMENTE DEPOIS de ver o teste 019 falhar (vermelho).
--
-- Decisão (21/11/2026): escalar, editar e criar missa só valem para missa que
-- AINDA NÃO COMEÇOU. É a mesma regra da escala livre; o histórico não é
-- reescrito.
--   * criar_missa: horário no passado -> HORARIO_NO_PASSADO
--   * editar_missa: missa que já começou -> MISSA_JA_COMECOU; novo horário no
--     passado -> HORARIO_NO_PASSADO
--   * escalar: missa que já começou -> MISSA_JA_COMECOU
-- Mesmas assinaturas de antes (create or replace); direitos de execução
-- preservados e repetidos no fim.

-- ---------- criar_missa ----------
create or replace function public.criar_missa(
  p_inicio       timestamptz,
  p_local_id     uuid,
  p_escala_livre boolean default false
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
  if p_inicio is null then
    raise exception 'HORARIO_INVALIDO';
  end if;
  if not exists (select 1 from public.locais l where l.id = p_local_id) then
    raise exception 'LOCAL_INEXISTENTE';
  end if;
  if p_inicio <= now() then
    raise exception 'HORARIO_NO_PASSADO';
  end if;

  insert into public.missas (inicio, local_id, escala_livre)
  values (p_inicio, p_local_id, coalesce(p_escala_livre, false))
  returning * into v_missa;

  return v_missa;
end;
$$;

-- ---------- editar_missa ----------
create or replace function public.editar_missa(
  p_missa_id     uuid,
  p_inicio       timestamptz,
  p_local_id     uuid,
  p_escala_livre boolean default null
)
returns public.missas
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_missa public.missas;
  v_atual timestamptz;
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;
  if not exists (select 1 from public.missas m where m.id = p_missa_id) then
    raise exception 'MISSA_INEXISTENTE';
  end if;
  select m.inicio into v_atual from public.missas m where m.id = p_missa_id;
  if v_atual <= now() then
    raise exception 'MISSA_JA_COMECOU';
  end if;
  if p_inicio is null then
    raise exception 'HORARIO_INVALIDO';
  end if;
  if not exists (select 1 from public.locais l where l.id = p_local_id) then
    raise exception 'LOCAL_INEXISTENTE';
  end if;
  if p_inicio <= now() then
    raise exception 'HORARIO_NO_PASSADO';
  end if;

  begin
    update public.missas
       set inicio = p_inicio,
           local_id = p_local_id,
           escala_livre = coalesce(p_escala_livre, escala_livre)
     where id = p_missa_id
    returning * into v_missa;
  exception
    when exclusion_violation then
      raise exception 'CONFLITO_DE_HORARIO';
  end;

  return v_missa;
end;
$$;

-- ---------- escalar ----------
create or replace function public.escalar(
  p_missa_id    uuid,
  p_coroinha_id uuid,
  p_funcao      text
)
returns public.escalacoes
language plpgsql
security definer      -- roda com os poderes do dono, ignorando a RLS
set search_path = ''  -- por isso TODO nome abaixo precisa do prefixo public.
as $$
declare
  v_escalacao public.escalacoes;
  v_ativo     boolean;
  v_inicio    timestamptz;
  v_funcao    text := coalesce(nullif(btrim(p_funcao), ''), 'A definir');
begin
  -- 0º: permissão. Vem antes de tudo: quem não pode escalar não descobre se a
  -- missa ou o coroinha existem. Sem login, o admin é "ninguém" e cai aqui.
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  -- 1º: a missa existe? (antes, isto aparecia como erro cru de chave
  -- estrangeira.)
  select m.inicio into v_inicio from public.missas m where m.id = p_missa_id;
  if not found then
    raise exception 'MISSA_INEXISTENTE';
  end if;
  if v_inicio <= now() then
    raise exception 'MISSA_JA_COMECOU';
  end if;

  -- 2º: o coroinha existe e está ativo? Um perfil inativo não enxerga nada no
  -- app (eh_membro() nega tudo), então escalá-lo criaria um escalado que
  -- nunca poderia confirmar presença.
  select p.ativo
    into v_ativo
    from public.perfis p
   where p.id = p_coroinha_id;

  if not found then
    raise exception 'COROINHA_INEXISTENTE';
  end if;
  if not v_ativo then
    raise exception 'COROINHA_INATIVO';
  end if;

  -- 3º: mesma missa. Vem ANTES do conflito de horário (mesma ordem do Dart).
  if exists (
    select 1
    from public.escalacoes
    where missa_id = p_missa_id
      and coroinha_id = p_coroinha_id
  ) then
    raise exception 'JA_ESCALADO_NA_MISSA';
  end if;

  -- 4º: conflito de horário. Quem GARANTE é a restrição de exclusão da
  -- tabela; aqui só traduzimos o erro para um código estável.
  begin
    insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (p_missa_id, p_coroinha_id, v_funcao)
    returning * into v_escalacao;
  exception
    when exclusion_violation then
      raise exception 'CONFLITO_DE_HORARIO';
  end;

  return v_escalacao;
end;
$$;

revoke execute on function public.criar_missa(timestamptz, uuid, boolean)         from public, anon;
revoke execute on function public.editar_missa(uuid, timestamptz, uuid, boolean)  from public, anon;
revoke execute on function public.escalar(uuid, uuid, text)                       from public, anon;
grant  execute on function public.criar_missa(timestamptz, uuid, boolean)         to authenticated;
grant  execute on function public.editar_missa(uuid, timestamptz, uuid, boolean)  to authenticated;
grant  execute on function public.escalar(uuid, uuid, text)                       to authenticated;
