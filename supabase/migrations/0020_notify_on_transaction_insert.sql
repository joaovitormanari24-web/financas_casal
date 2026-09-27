-- ============================================================================
-- Avisa o household inteiro (push + notificação in-app) quando um lançamento
-- é adicionado manualmente — pra que o parceiro saiba na hora, sem precisar
-- abrir o app. Só dispara pra lançamentos "avulsos": exclui os gerados
-- automaticamente por uma recorrência (já tem seu próprio aviso, "Conta
-- recorrente lançada") e os criados em lote por uma compra parcelada (senão
-- uma parcela em 12x dispararia 12 notificações de uma vez só).
-- ============================================================================

create or replace function public.notify_transaction_added()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  member_name text;
  type_label text;
  amount_label text;
begin
  if new.recurring_transaction_id is not null or new.installment_plan_id is not null then
    return new;
  end if;

  select display_name into member_name
  from public.household_members
  where id = new.paid_by_member_id;

  type_label := case when new.type = 'income' then 'um recebimento' else 'uma despesa' end;
  amount_label := replace(to_char(new.amount, 'FM999999990.00'), '.', ',');

  insert into public.notifications (household_id, title, body, kind)
  values (
    new.household_id,
    'Novo lançamento',
    coalesce(member_name, 'Alguém') || ' registrou ' || type_label || ': ' ||
      new.description || ' (R$ ' || amount_label || ').',
    'transaction_added'
  );

  return new;
end;
$$;

create trigger on_transaction_insert_notify
  after insert on public.transactions
  for each row execute function public.notify_transaction_added();
