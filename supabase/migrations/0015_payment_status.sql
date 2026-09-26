-- ============================================================================
-- Status de pagamento (pago/pendente) — até agora todo lançamento era
-- tratado como já realizado no ato. Isso separa "já paguei" de "vou pagar",
-- permite cadastrar contas futuras sem distorcer o saldo real da conta, e
-- detecta sozinho quando uma pendência passou do vencimento (atrasada).
-- ============================================================================

alter table public.transactions
  add column status text not null default 'paid' check (status in ('paid', 'pending')),
  add column overdue_notified boolean not null default false;

create index transactions_status_idx on public.transactions (household_id, status);

-- Saldo da conta só reflete o que já saiu/entrou de verdade — pendências
-- ainda não mexeram no dinheiro.
create or replace view public.account_balances
with (security_invoker = true)
as
select
  a.id,
  a.household_id,
  a.name,
  a.owner_member_id,
  a.external_source,
  a.initial_balance,
  a.initial_balance + coalesce(sum(
    case
      when t.status = 'paid' and t.type = 'income' then t.amount
      when t.status = 'paid' and t.type = 'expense' then -t.amount
      else 0
    end
  ), 0) as current_balance
from public.accounts a
left join public.transactions t on t.account_id = a.id
group by a.id;

-- Conta recorrente lançada nasce pendente agora — só account_balances muda
-- de fato quando alguém confirma que pagou (mesmo lugar que já detecta
-- atraso automaticamente, ver notify_overdue_bills abaixo).
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
      paid_by_member_id, payment_method, recurring_transaction_id, status
    ) values (
      rt.household_id, 'expense', effective_amount, rt.description, rt.category_id, today,
      member_id, rt.payment_method, rt.id, 'pending'
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

-- Avisa 1x quando uma pendência passa do vencimento sem ser marcada como
-- paga — dedup via overdue_notified (não repete o aviso todo dia).
create function public.notify_overdue_bills()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  t record;
  category_name text;
begin
  for t in
    select * from public.transactions
    where status = 'pending'
      and date < current_date
      and overdue_notified = false
  loop
    select name into category_name from public.categories where id = t.category_id;

    insert into public.notifications (household_id, title, body, kind)
    values (
      t.household_id,
      'Conta atrasada',
      t.description || coalesce(' (' || category_name || ')', '') || ' venceu e ainda não foi paga.',
      'overdue'
    );

    update public.transactions set overdue_notified = true where id = t.id;
  end loop;
end;
$$;

-- 11:00 UTC = 08:00 em Brasília — um horário em que alguém provavelmente
-- vai ver a notificação, diferente do gerador principal (03:00 UTC/meia-
-- noite, quando ninguém está olhando o celular).
select cron.schedule(
  'notify-overdue-bills',
  '0 11 * * *',
  $$select public.notify_overdue_bills()$$
);
