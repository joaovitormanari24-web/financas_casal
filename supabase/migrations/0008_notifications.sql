-- ============================================================================
-- Notificações in-app: 3 gatilhos automáticos usando a tabela
-- `notifications` (existente desde 0001_init.sql, nunca usada até agora).
-- ============================================================================

alter publication supabase_realtime add table public.notifications;

-- ----------------------------------------------------------------------------
-- 1) Conta recorrente lançada — estende o gerador de 0006 pra também criar
-- uma notificação a cada parcela/recorrência gerada automaticamente.
-- ----------------------------------------------------------------------------
create or replace function public.generate_due_recurring_transactions()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  rt record;
  today date := current_date;
  month_last_day int := extract(day from (date_trunc('month', today) + interval '1 month - 1 day'));
  target_day int;
  already_exists boolean;
  member_id uuid;
  effective_amount numeric(12, 2);
begin
  for rt in select * from public.recurring_transactions where active = true loop
    if rt.end_date is not null and today > rt.end_date then
      continue;
    end if;

    if rt.frequency = 'monthly' then
      target_day := least(rt.day_of_cycle, month_last_day);
      if extract(day from today) <> target_day then
        continue;
      end if;
      select exists(
        select 1 from public.transactions t
        where t.recurring_transaction_id = rt.id
          and date_trunc('month', t.date) = date_trunc('month', today)
      ) into already_exists;
    elsif rt.frequency = 'weekly' then
      if extract(isodow from today) <> rt.day_of_cycle then
        continue;
      end if;
      select exists(
        select 1 from public.transactions t
        where t.recurring_transaction_id = rt.id
          and date_trunc('week', t.date) = date_trunc('week', today)
      ) into already_exists;
    else
      continue;
    end if;

    if already_exists then
      continue;
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
      continue;
    end if;

    select coalesce(
      (select new_amount
       from public.recurring_transaction_amount_changes
       where recurring_transaction_id = rt.id and effective_date <= today
       order by effective_date desc
       limit 1),
      rt.amount
    ) into effective_amount;

    insert into public.transactions (
      household_id, type, amount, description, category_id, date,
      paid_by_member_id, payment_method, recurring_transaction_id
    ) values (
      rt.household_id, 'expense', effective_amount, rt.description, rt.category_id, today,
      member_id, rt.payment_method, rt.id
    );

    insert into public.notifications (household_id, title, body, kind)
    values (
      rt.household_id,
      'Conta recorrente lançada',
      rt.description || ' foi lançado automaticamente hoje.',
      'recurring'
    );
  end loop;
end;
$$;

-- ----------------------------------------------------------------------------
-- 2) Orçamento estourado — dispara só no lançamento que faz o total da
-- categoria no mês ultrapassar o limite (não repete a cada novo gasto).
-- ----------------------------------------------------------------------------
create function public.notify_budget_exceeded()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  budget_limit numeric(12, 2);
  total_before numeric(12, 2);
  total_after numeric(12, 2);
  category_name text;
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

  if total_before <= budget_limit and total_after > budget_limit then
    select name into category_name from public.categories where id = new.category_id;

    insert into public.notifications (household_id, title, body, kind)
    values (
      new.household_id,
      'Orçamento estourado',
      'Vocês passaram do limite em ' || coalesce(category_name, 'uma categoria') || ' este mês.',
      'budget'
    );
  end if;

  return new;
end;
$$;

create trigger on_transaction_budget_check
  after insert on public.transactions
  for each row execute function public.notify_budget_exceeded();

-- ----------------------------------------------------------------------------
-- 3) Meta atingida — estende o trigger de 0001 que já mantém
-- goals.current_amount em sincronia com os aportes.
-- ----------------------------------------------------------------------------
create or replace function public.apply_goal_contribution()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  goal_target numeric(12, 2);
  goal_name text;
  amount_before numeric(12, 2);
  amount_after numeric(12, 2);
begin
  if tg_op = 'INSERT' then
    update public.goals
    set current_amount = current_amount + new.amount
    where id = new.goal_id
    returning current_amount, target_amount, name into amount_after, goal_target, goal_name;

    amount_before := amount_after - new.amount;

    if amount_before < goal_target and amount_after >= goal_target then
      insert into public.notifications (household_id, title, body, kind)
      select household_id, 'Meta atingida! 🎉', goal_name || ' chegou ao valor combinado.', 'goal'
      from public.goals where id = new.goal_id;
    end if;
  elsif tg_op = 'DELETE' then
    update public.goals set current_amount = current_amount - old.amount where id = old.goal_id;
  end if;
  return null;
end;
$$;
