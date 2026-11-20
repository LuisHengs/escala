-- Dados de teste: duas missas na "Matriz (teste)", com o primeiro administrador
-- escalado nas duas: uma daqui a 26 horas e outra daqui a 90 minutos (o prazo
-- de confirmação dessa já passou).
--
-- Pode ser rodado várias vezes: primeiro apaga os restos da vez anterior.
-- Para só LIMPAR, use limpar_dados_teste.sql.

-- 1) limpa
delete from public.escalacoes
where missa_id in (
  select m.id from public.missas m
  join public.locais l on l.id = m.local_id
  where l.nome = 'Matriz (teste)');
delete from public.missas
where local_id in (select id from public.locais where nome = 'Matriz (teste)');
delete from public.locais where nome = 'Matriz (teste)';

-- 2) cria
insert into public.locais (nome) values ('Matriz (teste)');

insert into public.missas (inicio, local_id)
select x.inicio, l.id
from public.locais l,
     (values (now() + interval '26 hours'), (now() + interval '90 minutes')) as x(inicio)
where l.nome = 'Matriz (teste)';

insert into public.escalacoes (missa_id, coroinha_id, funcao)
select m.id,
       (select id from public.perfis where papel = 'admin' order by nome limit 1),
       'turiferário'
from public.missas m
join public.locais l on l.id = m.local_id
where l.nome = 'Matriz (teste)';
