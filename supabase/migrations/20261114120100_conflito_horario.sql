create extension if not exists btree_gist with schema extensions;

alter table public.escalacoes
  add constraint escalacoes_sem_conflito_de_horario
  exclude using gist (coroinha_id with =, periodo with &&);
