-- Migration 11: políticas de leitura (RLS).
-- RODE SOMENTE DEPOIS de ver o teste 010 falhar com "FALHOU [L1]".
--
-- Só há políticas de LEITURA (select). Não existe nenhuma de insert, update
-- ou delete: sem política, a RLS nega, e quem escreve são as funções
-- (security definer), que ignoram a RLS e conferem a permissão por dentro.

-- ---------- Funções auxiliares ----------
-- Por que funções, e não um "exists" direto em cada política? A política da
-- própria tabela perfis precisaria ler perfis, o que a faria chamar a si
-- mesma sem fim ("infinite recursion detected in policy"). Como estas
-- funções são security definer, elas leem perfis sem passar pela RLS.

create function public.eh_membro()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.perfis p
    where p.id = auth.uid()
      and p.ativo
  );
$$;

create function public.eh_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.perfis p
    where p.id = auth.uid()
      and p.papel = 'admin'
      and p.ativo
  );
$$;

revoke execute on function public.eh_membro() from public, anon;
revoke execute on function public.eh_admin()  from public, anon;
grant  execute on function public.eh_membro() to authenticated;
grant  execute on function public.eh_admin()  to authenticated;

-- ---------- Políticas ----------
-- "to authenticated": quem não está logado (anon) nem chega a avaliar a
-- política, e não vê nada. O "(select ...)" em volta da função faz o banco
-- avaliá-la uma vez por consulta, e não uma vez por linha.

create policy locais_leitura on public.locais
  for select to authenticated
  using ((select public.eh_membro()));

create policy perfis_leitura on public.perfis
  for select to authenticated
  using ((select public.eh_membro()));

create policy missas_leitura on public.missas
  for select to authenticated
  using ((select public.eh_membro()));

create policy escalacoes_leitura on public.escalacoes
  for select to authenticated
  using ((select public.eh_membro()));

create policy trocas_leitura on public.trocas
  for select to authenticated
  using ((select public.eh_membro()));

-- Dados do responsável: só o próprio coroinha e o admin.
create policy dados_responsavel_leitura on public.dados_responsavel
  for select to authenticated
  using ((select public.eh_admin()) or perfil_id = (select auth.uid()));
