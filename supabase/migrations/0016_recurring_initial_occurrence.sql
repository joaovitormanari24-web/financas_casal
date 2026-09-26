-- ============================================================================
-- Ao cadastrar uma conta recorrente, o lançamento do ciclo atual só nascia
-- na próxima execução do gerador diário (03:00 UTC) — se o dia do mês já
-- tivesse passado, ficava sem nada até o mês seguinte. Isso gera o
-- lançamento do ciclo atual na hora do cadastro, se já estiver na data ou
-- atrasado (nasce pendente, igual o gerador diário — se já passou do dia,
-- o próprio sistema de atraso já pega no dia seguinte).
-- ============================================================================

create function public.generate_initial_occurrence(rt_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  rt record;
  today date := current_date;
  month_last_day int := extract(day from (date_trunc('month', today) + interval '1 month - 1 day'));
  target_day int;
  cycle_due_date date;
  already_exists boolean;
  member_id uuid;
  effective_amount numeric(12, 2);
begin
  select * into rt from public.recurring_transactions where id = rt_id and active = true;
  if not found then
    return;
  end if;

  if rt.frequency = 'monthly' then
    target_day := least(rt.day_of_cycle, month_last_day);
    cycle_due_date := date_trunc('month', today)::date + (target_day - 1);
    if cycle_due_date > today then
      return;
    end if;
    select exists(
      select 1 from public.transactions t
      where t.recurring_transaction_id = rt.id
        and date_trunc('month', t.date) = date_trunc('month', today)
    ) into already_exists;
  elsif rt.frequency = 'weekly' then
    cycle_due_date := today - (extract(isodow from today)::int - rt.day_of_cycle);
    if cycle_due_date > today then
      return;
    end if;
    select exists(
      select 1 from public.transactions t
      where t.recurring_transaction_id = rt.id
        and date_trunc('week', t.date) = date_trunc('week', today)
    ) into already_exists;
  else
    return;
  end if;

  if already_exists then
    return;
  end if;

  member_id := rt.paid_by_member_id;
  if member_id is null then
    select id into member_id
    from public.household_members
    where household_id = rt.household_id
    order by created_at
    limit 1;
  end if;
  if member_id is null then
    return;
  end if;

  select coalesce(
    (select new_amount
     from public.recurring_transaction_amount_changes
     where recurring_transaction_id = rt.id and effective_date <= cycle_due_date
     order by effective_date desc
     limit 1),
    rt.amount
  ) into effective_amount;

  insert into public.transactions (
    household_id, type, amount, description, category_id, date,
    paid_by_member_id, payment_method, recurring_transaction_id, status
  ) values (
    rt.household_id, 'expense', effective_amount, rt.description, rt.category_id, cycle_due_date,
    member_id, rt.payment_method, rt.id, 'pending'
  );
end;
$$;
