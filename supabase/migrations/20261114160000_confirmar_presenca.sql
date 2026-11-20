-- Migration 6: confirmar presença.
-- RODE SOMENTE DEPOIS de ver o teste 006 falhar (vermelho).

-- ---------- Regra do prazo, em função pura ----------
-- Mesma regra do Dart (_chegouNoPrazo + prazoConfirmacao): a partir de 2h
-- antes da missa, inclusive o instante exato, a confirmação conta como
-- atrasada. Recebe "agora" como parâmetro para poder ser testada com horas
-- exatas, sem depender do relógio do banco.

create function public.passou_do_prazo(p_inicio timestamptz, p_agora timestamptz)
returns boolean
language sql
stable
as $$
  select p_agora >= p_inicio - interval '2 hours';
$$;

-- ---------- confirmar_presenca ----------
-- Quem confirma vem do login (auth.uid()), nunca de um parâmetro.

create function public.confirmar_presenca(p_escalacao_id uuid)
returns public.escalacoes
language plpgsql
security definer      -- roda com os poderes do dono, ignorando a RLS
set search_path = ''  -- por isso TODO nome abaixo precisa do prefixo public.
as $$
declare
  v_escalacao public.escalacoes;
  v_inicio    timestamptz;
begin
  -- "for update" trava a linha: dois cliques simultâneos não se atropelam.
  select e.*
    into v_escalacao
    from public.escalacoes e
   where e.id = p_escalacao_id
     for update;

  -- 1º: existe? (mesma ordem do Dart: buscar antes de checar permissão)
  if not found then
    raise exception 'ESCALACAO_NAO_ENCONTRADA';
  end if;

  -- 2º: só o titular confirma. Sem login, auth.uid() é nulo e cai aqui também.
  if v_escalacao.coroinha_id is distinct from auth.uid() then
    raise exception 'NAO_AUTORIZADO';
  end if;

  -- 3º: já confirmada? Devolve como está. Recalcular marcaria atraso em quem
  -- confirmou no prazo só porque o relógio andou.
  if v_escalacao.status = 'confirmado' then
    return v_escalacao;
  end if;

  select m.inicio into v_inicio
    from public.missas m
   where m.id = v_escalacao.missa_id;

  update public.escalacoes
     set status = 'confirmado',
         confirmado_com_atraso = public.passou_do_prazo(v_inicio, now())
   where id = p_escalacao_id
  returning * into v_escalacao;

  return v_escalacao;
end;
$$;

revoke execute on function public.confirmar_presenca(uuid) from public, anon;
grant  execute on function public.confirmar_presenca(uuid) to authenticated;
