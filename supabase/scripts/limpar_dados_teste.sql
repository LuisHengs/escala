-- Apaga TODOS os dados de teste dos scripts desta pasta e dos testes manuais
-- do app: os locais "Matriz (teste)", "Capela (teste)" e "Capela (teste app)",
-- as missas deles, as escalações e trocas ligadas a eles, e a "Maria (teste)".
--
-- Não mexe em nada que não seja de teste. Pode ser rodado várias vezes.

delete from public.escalacoes
where coroinha_id = '00000000-0000-0000-0000-00000000aaaa'
   or missa_id in (
     select m.id from public.missas m
     join public.locais l on l.id = m.local_id
     where l.nome in ('Matriz (teste)', 'Capela (teste)', 'Capela (teste app)'));

delete from public.missas
where local_id in (
  select id from public.locais
  where nome in ('Matriz (teste)', 'Capela (teste)', 'Capela (teste app)'));

delete from public.locais
where nome in ('Matriz (teste)', 'Capela (teste)', 'Capela (teste app)');

delete from auth.users where id = '00000000-0000-0000-0000-00000000aaaa';
