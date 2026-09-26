-- ============================================================================
-- create_recurring_transaction: cria a recorrência, o reajuste de valor (se
-- houver) e gera o lançamento do ciclo atual (se já devido) tudo numa única
-- chamada — o app fazia isso em 2-3 chamadas separadas (insert + insert +
-- RPC), e às vezes o generate_initial_occurrence não enxergava a recorrência
-- recém-criada ainda (aparente lag de leitura entre requisições), gerando a
-- regra sem o lançamento correspondente, silenciosamente.
-- ============================================================================

create function public.create_recurring_transaction(
  p_household_id uuid,
  p_description text,
  p_amount numeric,
  p_category_id uuid,
  p_frequency text,
  p_day_of_cycle int,
  p_payment_method text,
  p_paid_by_member_id uuid,
  p_end_date date default null,
  p_reminder_days_before int default null,
  p_amount_change_date date default null,
  p_amount_change_new_amount numeric default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  new_id uuid;
begin
  insert into public.recurring_transactions (
    household_id, description, amount, category_id, frequency, day_of_cycle,
    active, payment_method, paid_by_member_id, end_date, reminder_days_before
  ) values (
    p_household_id, p_description, p_amount, p_category_id, p_frequency, p_day_of_cycle,
    true, p_payment_method, p_paid_by_member_id, p_end_date, p_reminder_days_before
  )
  returning id into new_id;

  if p_amount_change_date is not null and p_amount_change_new_amount is not null then
    insert into public.recurring_transaction_amount_changes (
      recurring_transaction_id, effective_date, new_amount
    ) values (
      new_id, p_amount_change_date, p_amount_change_new_amount
    );
  end if;

  perform public.generate_initial_occurrence(new_id);

  return new_id;
end;
$$;
