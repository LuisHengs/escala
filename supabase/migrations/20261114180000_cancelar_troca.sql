-- Migration 8: cancelar_troca.
-- RODE SOMENTE DEPOIS de ver o teste 008 falhar (vermelho).
--
-- Uma função só atende o titular e o admin. No Dart eram dois métodos
-- (cancelarTroca e cancelarTrocaComoAdmin) porque lá o "quem" era um
-- parâmetro; aqui ele vem do login, então não precisa de dois caminhos.

create function public.cancelar_troca(p_troca_id uuid)
returns public.trocas
language plpgsql
security definer      -- roda com os poderes do dono, ignorando a RLS
set search_path = ''  -- por isso TODO nome abaixo precisa do prefixo public.
as $$
declare
  v_troca   public.trocas;
  v_titular uuid;
begin
  -- "for update" trava a troca: um cancelamento e um aceite simultâneos
  -- passam um de cada vez, e só o primeiro vale.
  select t.*
    into v_troca
    from public.trocas t
   where t.id = p_troca_id
     for update;

  -- 1º: existe?
  if not found then
    raise exception 'TROCA_NAO_ENCONTRADA';
  end if;

  -- 2º: permissão. Pode cancelar o titular ATUAL da escalação ou um admin
  -- ativo. Vem antes do estado: um estranho não descobre se a troca já foi
  -- resolvida. Sem login, auth.uid() é nulo e cai aqui também.
  select e.coroinha_id
    into v_titular
    from public.escalacoes e
   where e.id = v_troca.escalacao_id;

  if v_titular is distinct from auth.uid()
     and not exists (
       select 1
       from public.perfis p
       where p.id = auth.uid()
         and p.papel = 'admin'
         and p.ativo
     ) then
    raise exception 'NAO_AUTORIZADO';
  end if;

  -- 3º: só dá para cancelar o que ainda está aberto.
  if v_troca.status <> 'aberta' then
    raise exception 'TROCA_JA_RESOLVIDA';
  end if;

  update public.trocas
     set status = 'cancelada',
         resolvida_em = now()
   where id = p_troca_id
  returning * into v_troca;

  return v_troca;
end;
$$;

revoke execute on function public.cancelar_troca(uuid) from public, anon;
grant  execute on function public.cancelar_troca(uuid) to authenticated;
