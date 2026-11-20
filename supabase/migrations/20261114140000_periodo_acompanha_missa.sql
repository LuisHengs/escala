-- Migration 4: o período das escalações acompanha o horário da missa.
-- RODE SOMENTE DEPOIS de ver o teste 003 falhar com "FALHOU [M1]".

-- ---------- 1) Refatoração: a duração da missa num lugar só ----------
-- A duração (1 hora) é a mesma constante duracaoMissa do código Dart.
-- Antes ela estava escrita direto no gatilho; agora dois gatilhos precisam
-- dela, então vira uma função.

create function public.periodo_missa(p_inicio timestamptz)
returns tstzrange
language sql
stable
as $$
  select tstzrange(p_inicio, p_inicio + interval '1 hour');
$$;

-- Mesmo gatilho de antes (ao escalar), agora usando a função acima.
create or replace function public.definir_periodo_escalacao()
returns trigger
language plpgsql
as $$
begin
  new.periodo := (
    select public.periodo_missa(m.inicio)
    from public.missas m
    where m.id = new.missa_id
  );
  return new;
end;
$$;

-- ---------- 2) Novo: quando o horário da missa muda ----------
-- Se o novo horário conflitar com outra escalação do mesmo coroinha, a
-- restrição de exclusão da tabela escalacoes rejeita este UPDATE, e o
-- horário da missa não muda (o comando inteiro é desfeito).

create function public.atualizar_periodo_escalacoes()
returns trigger
language plpgsql
as $$
begin
  update public.escalacoes
     set periodo = public.periodo_missa(new.inicio)
   where missa_id = new.id;
  return new;
end;
$$;

create trigger missas_atualizar_periodo
after update of inicio on public.missas
for each row
when (old.inicio is distinct from new.inicio)
execute function public.atualizar_periodo_escalacoes();
