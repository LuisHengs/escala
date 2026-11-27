-- Migration 22: nome de local não diferencia maiúsculas de minúsculas.
-- "Matriz" e "matriz" passam a ser o mesmo local. A função criar_local já
-- traduz a violação de unicidade em LOCAL_DUPLICADO; só falta o índice.
-- Se já existirem dois locais que diferem só na caixa, o índice não é criado
-- (erro "could not create unique index"): renomeie um deles e rode de novo.
-- Rode UMA vez no SQL Editor do projeto escala-dev.

create unique index locais_nome_sem_caixa on public.locais (lower(nome));
