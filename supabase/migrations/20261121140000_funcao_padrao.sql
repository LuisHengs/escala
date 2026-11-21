-- Migration 19: escalar() sem função grava "A definir".
-- RODE SOMENTE DEPOIS de ver o teste 018 falhar (vermelho).
--
-- Mesma assinatura de antes, por isso "create or replace". O que muda: a
-- função é limpa (espaços das pontas saem) e, se ficar vazia ou nula, vira
-- "A definir" (o mesmo texto da escala livre). As validações e a ordem
-- continuam as da migration 17: permissão -> missa existe -> coroinha existe
-- e está ativo -> mesma missa -> conflito de horário.

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
  v_funcao    text := coalesce(nullif(btrim(p_funcao), ''), 'A definir');
begin
  -- 0º: permissão. Vem antes de tudo: quem não pode escalar não descobre se a
  -- missa ou o coroinha existem. Sem login, o admin é "ninguém" e cai aqui.
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  -- 1º: a missa existe? (antes, isto aparecia como erro cru de chave
  -- estrangeira.)
  if not exists (select 1 from public.missas m where m.id = p_missa_id) then
    raise exception 'MISSA_INEXISTENTE';
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

-- Os direitos de execução já existem desde a migration 5 e o
-- "create or replace" os preserva; repetimos por clareza.
revoke execute on function public.escalar(uuid, uuid, text) from public, anon;
grant  execute on function public.escalar(uuid, uuid, text) to authenticated;
