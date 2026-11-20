-- Migration 2 (esqueleto): função escalar SEM regras (fase vermelha do TDD).
-- Só insere. As verificações entram depois que o teste 002 falhar.
--
-- Rode UMA vez no SQL Editor do projeto escala-dev.

create function public.escalar(
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
  insert into public.escalacoes (missa_id, coroinha_id, funcao)
  values (p_missa_id, p_coroinha_id, p_funcao)
  returning * into v_escalacao;

  return v_escalacao;
end;
$$;
