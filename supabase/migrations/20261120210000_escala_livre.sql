-- Migration 18: escala livre (o coroinha se escala sozinho).
-- RODE SOMENTE DEPOIS de ver o teste 017 falhar (veja o aviso no teste).
--
-- Decisões (conversa de 20/11/2026):
--   * a missa tem uma chave "escala livre", ligada pelo administrador ao criar
--     ou editar a missa;
--   * sem limite de vagas;
--   * quem entra sozinho fica com a função "A definir" (o administrador
--     ajusta depois) e já como CONFIRMADO;
--   * o coroinha pode sair até o início da missa, mas SÓ da escala que ele
--     mesmo escolheu (auto_escalada); se foi o administrador que o escalou,
--     o caminho continua sendo pedir troca;
--   * desligar a escala livre não tira quem já entrou.
--
-- criar_missa e editar_missa ganham um parâmetro novo (com valor padrão), e
-- por isso precisam ser removidas e recriadas (o Postgres não troca a lista
-- de parâmetros de uma função existente). Quem chama com a lista antiga
-- continua funcionando. O teste 013 (C6) cita as assinaturas e foi atualizado.

-- ---------- Colunas ----------
alter table public.missas
  add column escala_livre boolean not null default false;

alter table public.escalacoes
  add column auto_escalada boolean not null default false;

-- ---------- criar_missa (com escala livre) ----------
drop function public.criar_missa(timestamptz, uuid);

create function public.criar_missa(
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

  insert into public.missas (inicio, local_id, escala_livre)
  values (p_inicio, p_local_id, coalesce(p_escala_livre, false))
  returning * into v_missa;

  return v_missa;
end;
$$;

-- ---------- editar_missa (com escala livre) ----------
-- p_escala_livre nulo = não mexe na escala livre.
drop function public.editar_missa(uuid, timestamptz, uuid);

create function public.editar_missa(
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

-- ---------- auto_escalar ----------
-- O coroinha logado entra na missa que está com a escala livre. Quem entra é
-- SEMPRE quem está logado (não há parâmetro de pessoa).
create function public.auto_escalar(p_missa_id uuid)
returns public.escalacoes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inicio timestamptz;
  v_livre  boolean;
  v_esc    public.escalacoes;
begin
  -- Permissão primeiro: só perfil ativo (eh_membro). Sem login cai aqui.
  if not public.eh_membro() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  select m.inicio, m.escala_livre
    into v_inicio, v_livre
    from public.missas m
   where m.id = p_missa_id;
  if not found then
    raise exception 'MISSA_INEXISTENTE';
  end if;
  if not v_livre then
    raise exception 'ESCALA_NAO_LIVRE';
  end if;
  -- Mesma regra do resto do sistema: começou quando agora >= início.
  if v_inicio <= now() then
    raise exception 'MISSA_JA_COMECOU';
  end if;

  if exists (
    select 1
      from public.escalacoes e
     where e.missa_id = p_missa_id
       and e.coroinha_id = auth.uid()
  ) then
    raise exception 'JA_ESCALADO_NA_MISSA';
  end if;

  -- Quem GARANTE o conflito de horário é a restrição de exclusão da tabela.
  begin
    insert into public.escalacoes
      (missa_id, coroinha_id, funcao, status, auto_escalada)
    values
      (p_missa_id, auth.uid(), 'A definir', 'confirmado', true)
    returning * into v_esc;
  exception
    when exclusion_violation then
      raise exception 'CONFLITO_DE_HORARIO';
  end;

  return v_esc;
end;
$$;

-- ---------- auto_desescalar ----------
-- O coroinha logado sai da escala que ele mesmo escolheu, até o início da
-- missa. Só mexe na escalação de quem está logado.
create function public.auto_desescalar(p_missa_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id     uuid;
  v_auto   boolean;
  v_inicio timestamptz;
begin
  if not public.eh_membro() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  select e.id, e.auto_escalada, m.inicio
    into v_id, v_auto, v_inicio
    from public.escalacoes e
    join public.missas m on m.id = e.missa_id
   where e.missa_id = p_missa_id
     and e.coroinha_id = auth.uid()
     for update of e;
  if not found then
    raise exception 'ESCALACAO_NAO_ENCONTRADA';
  end if;
  if not v_auto then
    -- Foi o administrador que escalou: o caminho é pedir troca.
    raise exception 'SAIDA_NAO_PERMITIDA';
  end if;
  if v_inicio <= now() then
    raise exception 'MISSA_JA_COMECOU';
  end if;

  -- As trocas da escalação saem junto (on delete cascade).
  delete from public.escalacoes where id = v_id;
end;
$$;

-- ---------- Direitos de execução ----------
revoke execute on function public.criar_missa(timestamptz, uuid, boolean)         from public, anon;
revoke execute on function public.editar_missa(uuid, timestamptz, uuid, boolean)  from public, anon;
revoke execute on function public.auto_escalar(uuid)                              from public, anon;
revoke execute on function public.auto_desescalar(uuid)                           from public, anon;
grant  execute on function public.criar_missa(timestamptz, uuid, boolean)         to authenticated;
grant  execute on function public.editar_missa(uuid, timestamptz, uuid, boolean)  to authenticated;
grant  execute on function public.auto_escalar(uuid)                              to authenticated;
grant  execute on function public.auto_desescalar(uuid)                           to authenticated;
