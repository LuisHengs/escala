-- Migration 15: lista de "pendentes em atraso" para o coordenador.
-- RODE SOMENTE DEPOIS de ver o teste 014 falhar com "FALHOU [D1]".
--
-- Mesma regra do Dart (pendentesEmAtraso): escalação PENDENTE cuja missa
-- ainda não começou e começa em até 2h (inclusive o instante exato das 2h).
-- Usa passou_do_prazo(), da migration 6, para a regra das 2h ficar num lugar
-- só. "Agora" é parâmetro (padrão: now()) para o teste usar horas exatas.
--
-- Só admin: a lista existe para o coordenador cobrar quem não confirmou.

create function public.pendentes_em_atraso(p_agora timestamptz default now())
returns table (
  escalacao_id  uuid,
  missa_id      uuid,
  inicio        timestamptz,
  coroinha_id   uuid,
  coroinha_nome text,
  funcao        text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_agora timestamptz := coalesce(p_agora, now());
begin
  if not public.eh_admin() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  return query
    select e.id, m.id, m.inicio, e.coroinha_id, p.nome, e.funcao
      from public.escalacoes e
      join public.missas m on m.id = e.missa_id
      join public.perfis p on p.id = e.coroinha_id
     where e.status = 'pendente'
       and public.passou_do_prazo(m.inicio, v_agora)
       and v_agora < m.inicio
     order by m.inicio, p.nome;
end;
$$;

revoke execute on function public.pendentes_em_atraso(timestamptz) from public, anon;
grant  execute on function public.pendentes_em_atraso(timestamptz) to authenticated;
