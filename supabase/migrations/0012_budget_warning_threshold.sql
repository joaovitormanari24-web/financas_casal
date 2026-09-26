-- ============================================================================
-- Aviso antecipado de orçamento: além do "estourou" (0008_notifications.sql,
-- 100% do limite), agora também avisa ao passar de 80% — dá tempo do casal
-- reagir antes de estourar de vez. Cada aviso dispara só na transação exata
-- que cruza aquele limiar (não repete a cada gasto novo), e o "estourou"
-- tem prioridade se um único lançamento pular direto de <80% pra >100%.
-- ============================================================================

create or replace function public.notify_budget_exceeded()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  budget_limit numeric(12, 2);
  total_before numeric(12, 2);
  total_after numeric(12, 2);
  category_name text;
  warning_threshold numeric(12, 2);
begin
  if new.type <> 'expense' then
    return new;
  end if;

  select limit_amount into budget_limit
  from public.budgets
  where household_id = new.household_id
    and category_id = new.category_id
    and reference_month = date_trunc('month', new.date)::date;

  if budget_limit is null then
    return new;
  end if;

  select coalesce(sum(amount), 0) into total_after
  from public.transactions
  where household_id = new.household_id
    and category_id = new.category_id
    and type = 'expense'
    and date_trunc('month', date) = date_trunc('month', new.date);

  total_before := total_after - new.amount;
  warning_threshold := budget_limit * 0.8;

  select name into category_name from public.categories where id = new.category_id;

  if total_before <= budget_limit and total_after > budget_limit then
    insert into public.notifications (household_id, title, body, kind)
    values (
      new.household_id,
      'Orçamento estourado',
      'Vocês passaram do limite em ' || coalesce(category_name, 'uma categoria') || ' este mês.',
      'budget'
    );
  elsif total_before <= warning_threshold and total_after > warning_threshold and total_after <= budget_limit then
    insert into public.notifications (household_id, title, body, kind)
    values (
      new.household_id,
      'Orçamento quase no limite',
      'Vocês já usaram 80% do orçamento em ' || coalesce(category_name, 'uma categoria') || ' este mês.',
      'budget_warning'
    );
  end if;

  return new;
end;
$$;
