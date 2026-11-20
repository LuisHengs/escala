-- Dados de teste para as trocas: cria a "Maria (teste)", uma pessoa de mentira
-- (sem e-mail: ninguém entra como ela), com dois pedidos de troca abertos.
--
-- Rode ANTES o dados_teste_escala.sql e logo depois este: um dos pedidos fica
-- 30 minutos depois da sua missa de teste (mostra a mensagem de conflito) e o
-- outro fica livre (mostra o aceite).
-- Pode ser rodado várias vezes: o bloco 0) apaga os restos.

-- 0) limpa restos de tentativas anteriores
delete from public.escalacoes where coroinha_id = '00000000-0000-0000-0000-00000000aaaa';
delete from public.missas where local_id in (select id from public.locais where nome = 'Capela (teste)');
delete from public.locais where nome = 'Capela (teste)';
delete from auth.users where id = '00000000-0000-0000-0000-00000000aaaa';

-- 1) uma pessoa de mentira
insert into auth.users (id) values ('00000000-0000-0000-0000-00000000aaaa');
insert into public.perfis (id, nome) values ('00000000-0000-0000-0000-00000000aaaa', 'Maria (teste)');

-- 2) duas missas na "Capela (teste)": uma que conflita com a sua e outra livre
insert into public.locais (nome) values ('Capela (teste)');

insert into public.missas (inicio, local_id)
select x.inicio, l.id
from public.locais l,
     (values (now() + interval '26 hours 30 minutes'), (now() + interval '72 hours')) as x(inicio)
where l.nome = 'Capela (teste)';

-- 3) a Maria escalada nas duas, cada uma com um pedido de troca aberto
insert into public.escalacoes (missa_id, coroinha_id, funcao)
select m.id, '00000000-0000-0000-0000-00000000aaaa', 'cruciferário'
from public.missas m join public.locais l on l.id = m.local_id
where l.nome = 'Capela (teste)';

insert into public.trocas (escalacao_id)
select e.id from public.escalacoes e
where e.coroinha_id = '00000000-0000-0000-0000-00000000aaaa';
