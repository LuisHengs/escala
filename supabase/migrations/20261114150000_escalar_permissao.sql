-- Migration 5: escalar() só para admin; a identidade vem do login (auth.uid()).
-- RODE SOMENTE DEPOIS de ver o teste 005 falhar com "FALHOU [P1]".
--
-- ATENÇÃO: depois desta migration o teste 002 ANTIGO passa a falhar, e isso é
-- esperado: ele chamava escalar() sem estar logado como admin. Use a versão
-- nova do 002, que faz o login de admin antes.

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
begin
  -- 0º: permissão. Vem antes de tudo, como no Dart: quem não pode escalar não
  -- recebe informação sobre a escala dos outros. auth.uid() é nulo quando não
  -- há login, e aí o "exists" é falso e a chamada é negada do mesmo jeito.
  -- Admin desativado (ativo = false) também perde o poder de escalar.
  if not exists (
    select 1
    from public.perfis p
    where p.id = auth.uid()
      and p.papel = 'admin'
      and p.ativo
  ) then
    raise exception 'NAO_AUTORIZADO';
  end if;

  -- 1º: mesma missa. Vem ANTES do conflito de horário (mesma ordem do Dart).
  if exists (
    select 1
    from public.escalacoes
    where missa_id = p_missa_id
      and coroinha_id = p_coroinha_id
  ) then
    raise exception 'JA_ESCALADO_NA_MISSA';
  end if;

  -- 2º: conflito de horário. Quem GARANTE é a restrição de exclusão da
  -- tabela; aqui só traduzimos o erro para um código estável.
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

-- Direitos de execução: só quem está logado. As duas linhas do revoke
-- importam: o Supabase concede execução ao papel anon por padrão, e tirar
-- apenas de "public" não bastaria.
revoke execute on function public.escalar(uuid, uuid, text) from public, anon;
grant  execute on function public.escalar(uuid, uuid, text) to authenticated;
