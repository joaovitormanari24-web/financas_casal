-- ============================================================================
-- Um lançamento recorrente só materializava o ciclo atual (se já vencido) no
-- momento da criação — os meses seguintes só apareciam um de cada vez,
-- criados pelo cron diário (generate_due_recurring_transactions) exatamente
-- no dia do vencimento. Resultado: criar uma recorrência hoje não mostrava
-- nada nos meses futuros até o dia realmente chegar — quem espera "aparecer
-- todos os meses" ao cadastrar não via nada além do mês atual.
--
-- generate_initial_occurrence agora pré-popula um horizonte de 12 ciclos
-- (12 meses pra mensal, 12 semanas pra semanal) a partir de hoje, sempre
-- como "pending" — mesma lógica de dedup por ciclo de antes, só que num
-- laço. O cron diário continua existindo do jeito que já estava (cria o dia
-- exato + notifica "Conta recorrente lançada"), sem duplicar nada porque o
-- ciclo já vai existir quando ele passar por ali.
-- ============================================================================

create or replace function public.generate_initial_occurrence(rt_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  rt record;
  today date := current_date;
  cycle_month_start date;
  month_last_day int;
  target_day int;
  cycle_due_date date;
  already_exists boolean;
  member_id uuid;
  effective_amount numeric(12, 2);
  i int;
begin
  select * into rt from public.recurring_transactions where id = rt_id and active = true;
  if not found then
    return;
  end if;

  if rt.frequency not in ('monthly', 'weekly') then
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

  for i in 0..11 loop
    if rt.frequency = 'monthly' then
      cycle_month_start := date_trunc('month', today + (i || ' months')::interval)::date;
      month_last_day := extract(day from (cycle_month_start + interval '1 month - 1 day'));
      target_day := least(rt.day_of_cycle, month_last_day);
      cycle_due_date := cycle_month_start + (target_day - 1);
    else
      cycle_due_date := (today - (extract(isodow from today)::int - rt.day_of_cycle)) + (i * 7);
    end if;

    if rt.end_date is not null and cycle_due_date > rt.end_date then
      exit;
    end if;

    if rt.frequency = 'monthly' then
      select exists(
        select 1 from public.transactions t
        where t.recurring_transaction_id = rt.id
          and date_trunc('month', t.date) = date_trunc('month', cycle_due_date)
      ) into already_exists;
    else
      select exists(
        select 1 from public.transactions t
        where t.recurring_transaction_id = rt.id
          and date_trunc('week', t.date) = date_trunc('week', cycle_due_date)
      ) into already_exists;
    end if;

    if not already_exists then
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
    end if;
  end loop;
end;
$$;
