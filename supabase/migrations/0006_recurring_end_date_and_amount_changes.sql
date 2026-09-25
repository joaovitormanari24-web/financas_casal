-- ============================================================================
-- Gastos recorrentes: data de término opcional + reajuste de valor
-- programado (ex.: aluguel que aumenta a partir de um mês específico).
-- ============================================================================

alter table public.recurring_transactions
  add column end_date date;

-- Cada linha é um "a partir desta data, o valor passa a ser este" — permite
-- inclusive mais de um reajuste ao longo do tempo (ex.: aluguel reajustado
-- todo ano), embora a UI hoje só exponha um de cada vez.
create table public.recurring_transaction_amount_changes (
  id uuid primary key default gen_random_uuid(),
  recurring_transaction_id uuid not null references public.recurring_transactions (id) on delete cascade,
  effective_date date not null,
  new_amount numeric(12, 2) not null check (new_amount > 0),
  created_at timestamptz not null default now(),
  unique (recurring_transaction_id, effective_date)
);

create index recurring_transaction_amount_changes_rt_id_idx
  on public.recurring_transaction_amount_changes (recurring_transaction_id);

alter table public.recurring_transaction_amount_changes enable row level security;

create policy "recurring_transaction_amount_changes_all"
  on public.recurring_transaction_amount_changes
  for all using (
    exists (
      select 1 from public.recurring_transactions rt
      where rt.id = recurring_transaction_amount_changes.recurring_transaction_id
        and public.is_household_member(rt.household_id)
    )
  )
  with check (
    exists (
      select 1 from public.recurring_transactions rt
      where rt.id = recurring_transaction_amount_changes.recurring_transaction_id
        and public.is_household_member(rt.household_id)
    )
  );

-- Substitui a função para: (1) respeitar end_date, (2) usar o valor vigente
-- na data de hoje (o reajuste mais recente com effective_date <= hoje, ou o
-- valor original se nunca reajustado).
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
  end loop;
end;
$$;
