-- ============================================================================
-- 1) Saldo por conta: contas ganham saldo inicial, e uma view calcula o
-- saldo atual (inicial + receitas - despesas lançadas naquela conta).
-- security_invoker garante que a RLS de `accounts`/`transactions` continua
-- valendo pra quem consulta a view (não roda com privilégio do dono dela).
-- ============================================================================

alter table public.accounts add column initial_balance numeric(12, 2) not null default 0;

create view public.account_balances
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
      when t.type = 'income' then t.amount
      when t.type = 'expense' then -t.amount
      else 0
    end
  ), 0) as current_balance
from public.accounts a
left join public.transactions t on t.account_id = a.id
group by a.id;

-- ============================================================================
-- 2) Lembrete de conta recorrente antes do vencimento — hoje o aviso só
-- dispara no dia do lançamento (0008_notifications.sql); isso adiciona um
-- segundo aviso opcional N dias antes, sem lançar nada ainda.
-- ============================================================================

alter table public.recurring_transactions add column reminder_days_before int;

alter table public.notifications
  add column recurring_transaction_id uuid references public.recurring_transactions (id) on delete cascade,
  add column related_date date;

create function public.send_recurring_reminders()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  rt record;
  today date := current_date;
  target_date date;
  target_month_last_day int;
  is_due_on_target boolean;
  already_reminded boolean;
begin
  for rt in
    select * from public.recurring_transactions
    where active = true and reminder_days_before is not null and reminder_days_before > 0
  loop
    if rt.end_date is not null and today > rt.end_date then
      continue;
    end if;

    target_date := today + rt.reminder_days_before;

    if rt.frequency = 'monthly' then
      target_month_last_day := extract(day from (date_trunc('month', target_date) + interval '1 month - 1 day'));
      is_due_on_target := extract(day from target_date) = least(rt.day_of_cycle, target_month_last_day);
    elsif rt.frequency = 'weekly' then
      is_due_on_target := extract(isodow from target_date) = rt.day_of_cycle;
    else
      is_due_on_target := false;
    end if;

    if not is_due_on_target then
      continue;
    end if;

    select exists(
      select 1 from public.notifications
      where recurring_transaction_id = rt.id and related_date = target_date
    ) into already_reminded;

    if already_reminded then
      continue;
    end if;

    insert into public.notifications (
      household_id, title, body, kind, recurring_transaction_id, related_date
    ) values (
      rt.household_id,
      'Conta chegando',
      rt.description || ' vence em ' || rt.reminder_days_before || ' dia(s), no dia ' ||
        to_char(target_date, 'DD/MM') || '.',
      'reminder',
      rt.id,
      target_date
    );
  end loop;
end;
$$;

-- Mesmo horário do gerador principal (0005_recurring_transactions_automation.sql).
select cron.schedule(
  'send-recurring-reminders',
  '0 3 * * *',
  $$select public.send_recurring_reminders()$$
);
