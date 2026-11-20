-- Auditoria de segurança (somente leitura: não altera nada).
-- Cole no SQL Editor e rode. Cada bloco diz o que esperar.
-- O SQL Editor mostra só o resultado da ÚLTIMA consulta, então rode UMA
-- consulta por vez (selecione o trecho e clique em Run).

-- [A1] Tabelas do app SEM a proteção por linha (RLS) ligada.
-- ESPERADO: nenhuma linha.
select c.relname as tabela_sem_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
  and not c.relrowsecurity;

-- [A2] Políticas que NÃO são de leitura. Toda escrita deve passar pelas
-- funções, então não pode existir política de insert/update/delete.
-- ESPERADO: nenhuma linha.
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and cmd <> 'SELECT';

-- [A3] Políticas que valem também para quem NÃO está logado (anon/public).
-- ESPERADO: nenhuma linha.
select tablename, policyname, roles
from pg_policies
where schemaname = 'public'
  and (roles && array['anon', 'public']::name[]);

-- [A4] Funções do app que quem NÃO está logado (anon) consegue executar.
-- ESPERADO: só auxiliares sem efeito (cálculo puro ou gatilho):
--   atualizar_periodo_escalacoes, definir_periodo_escalacao,
--   passou_do_prazo, periodo_missa.
-- Qualquer outra (escalar, confirmar_presenca, gerar_convite...) é falha.
select p.oid::regprocedure as funcao_executavel_por_anon
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and has_function_privilege('anon', p.oid, 'execute')
order by 1::text;

-- [A5] Funções "security definer" SEM search_path fixado (risco clássico de
-- sequestro de nomes). ESPERADO: nenhuma linha.
select p.oid::regprocedure as funcao_sem_search_path
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and not exists (
    select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) c
    where c like 'search_path=%'
  );

-- [A6] Funções do app que o papel logado (authenticated) consegue executar:
-- a "superfície" que o app enxerga. ESPERADO: as funções de negócio abaixo,
-- e NÃO exigir_outro_admin nem hash_convite (uso interno).
select p.oid::regprocedure as funcao_executavel_por_logado
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and has_function_privilege('authenticated', p.oid, 'execute')
order by 1::text;
