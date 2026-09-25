-- ============================================================================
-- Gastos recorrentes: geração automática via pg_cron. Sem isso, a tabela
-- recurring_transactions (já existente desde 0001_init.sql) é só uma lista
-- que ninguém usa — o valor da feature é o app lançar sozinho todo
-- mês/semana, sem o casal precisar digitar de novo.
-- ============================================================================

-- payment_method e paid_by_member_id não existiam na tabela original — sem
-- eles, cada lançamento gerado teria que adivinhar quem pagou e como.
alter table public.recurring_transactions
  add column payment_method text not null default 'pix'
    check (payment_method in ('pix', 'debit', 'credit', 'cash', 'boleto', 'transfer')),
  add column paid_by_member_id uuid references public.household_members (id) on delete set null;

create extension if not exists pg_cron;

-- ----------------------------------------------------------------------------
-- generate_due_recurring_transactions: roda 1x/dia (agendada abaixo). Para
-- cada recorrência ativa cujo dia bate com hoje, insere o lançamento
-- correspondente — se ainda não tiver sido gerado no período atual.
--
-- 'annual' ainda não é suportado: o schema não guarda o mês, só o dia
-- (day_of_cycle 1-31), então não dá pra saber em qual mês do ano lançar.
-- Fica como próxima melhoria caso o casal precise de recorrência anual.
-- ----------------------------------------------------------------------------
create function public.generate_due_recurring_transactions()
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
begin
  for rt in select * from public.recurring_transactions where active = true loop
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

    insert into public.transactions (
      household_id, type, amount, description, category_id, date,
      paid_by_member_id, payment_method, recurring_transaction_id
    ) values (
      rt.household_id, 'expense', rt.amount, rt.description, rt.category_id, today,
      member_id, rt.payment_method, rt.id
    );
  end loop;
end;
$$;

-- 03:00 UTC = meia-noite em horário de Brasília (UTC-3).
select cron.schedule(
  'generate-recurring-transactions',
  '0 3 * * *',
  $$select public.generate_due_recurring_transactions()$$
);
