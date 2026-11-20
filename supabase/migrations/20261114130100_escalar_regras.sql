-- Migration 3: regras da função escalar (fase verde do TDD).
-- RODE SOMENTE DEPOIS de ver o teste 002 falhar com "FALHOU [3]".
--
-- Mesma assinatura da versão anterior, por isso "create or replace".

create or replace function public.escalar(
  p_missa_id    uuid,
  p_coroinha_id uuid,
  p_funcao      text
)
returns public.escalacoes
language plpgsql
as $$
declare
  v_escalacao public.escalacoes;
begin
  -- 1º: mesma missa. Vem ANTES do conflito de horário, na mesma ordem do
  -- código Dart: a mesma missa tem período idêntico e cairia no conflito.
  if exists (
    select 1
    from public.escalacoes
    where missa_id = p_missa_id
      and coroinha_id = p_coroinha_id
  ) then
    raise exception 'JA_ESCALADO_NA_MISSA';
  end if;

  -- 2º: conflito de horário. Quem GARANTE é a restrição de exclusão da tabela
  -- (vale até para dois pedidos simultâneos); aqui só traduzimos o erro para
  -- um código estável que o app consegue reconhecer.
  begin
    insert into public.escalacoes (missa_id, coroinha_id, funcao)
    values (p_missa_id, p_coroinha_id, p_funcao)
    returning * into v_escalacao;
  exception
    when exclusion_violation then
      raise exception 'CONFLITO_DE_HORARIO';
  end;

  return v_escalacao;
end;
$$;
