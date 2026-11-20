-- MODELO do script que cria o primeiro administrador.
-- Copie este arquivo para admin.sql (que fica FORA do Git), troque os dois
-- valores em maiúsculas e rode no SQL Editor do Supabase.
--
-- Antes: entre no app UMA vez com a sua conta Google (vai cair na tela de
-- convite). É isso que cria a sua linha em auth.users.

insert into public.perfis (id, nome, papel)
select id, 'SEU NOME', 'admin'
from auth.users
where email = 'SEU_EMAIL_DO_GOOGLE';

select id, nome, papel, ativo from public.perfis where papel = 'admin';
