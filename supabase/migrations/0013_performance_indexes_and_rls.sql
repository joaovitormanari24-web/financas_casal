-- ============================================================================
-- Robustez/performance: dois achados do linter de performance do Supabase.
--
-- 1) 14 chaves estrangeiras sem índice — toda vez que uma dessas colunas é
-- usada num join/filtro (o que já acontece: account_balances, o gerador de
-- recorrentes, o dedup de lembrete, etc.), o Postgres faz sequential scan
-- em vez de usar índice. Sem impacto perceptível hoje (pouco dado), mas é
-- built-in ficar correto desde já em vez de esperar o histórico crescer.
--
-- 2) RLS re-avaliando auth.uid() por linha em vez de uma vez só — troca
-- `auth.uid()` por `(select auth.uid())`, que o Postgres consegue cachear
-- como InitPlan (mesmo resultado, plano de execução mais barato).
-- ============================================================================

create index if not exists accounts_owner_member_id_idx on public.accounts (owner_member_id);
create index if not exists budgets_category_id_idx on public.budgets (category_id);
create index if not exists financial_simulations_created_by_member_id_idx on public.financial_simulations (created_by_member_id);
create index if not exists goal_contributions_member_id_idx on public.goal_contributions (member_id);
create index if not exists household_invites_created_by_member_id_idx on public.household_invites (created_by_member_id);
create index if not exists household_invites_used_by_user_id_idx on public.household_invites (used_by_user_id);
create index if not exists installment_plans_credit_card_id_idx on public.installment_plans (credit_card_id);
create index if not exists notifications_recurring_transaction_id_idx on public.notifications (recurring_transaction_id);
create index if not exists push_subscriptions_member_id_idx on public.push_subscriptions (member_id);
create index if not exists recurring_transactions_category_id_idx on public.recurring_transactions (category_id);
create index if not exists recurring_transactions_paid_by_member_id_idx on public.recurring_transactions (paid_by_member_id);
create index if not exists transactions_account_id_idx on public.transactions (account_id);
create index if not exists transactions_credit_card_id_idx on public.transactions (credit_card_id);
create index if not exists transactions_recurring_transaction_id_idx on public.transactions (recurring_transaction_id);

drop policy "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (id = (select auth.uid()));

drop policy "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (id = (select auth.uid()));

drop policy "household_members_update_own" on public.household_members;
create policy "household_members_update_own" on public.household_members
  for update using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy "household_members_delete_own" on public.household_members;
create policy "household_members_delete_own" on public.household_members
  for delete using (user_id = (select auth.uid()));
