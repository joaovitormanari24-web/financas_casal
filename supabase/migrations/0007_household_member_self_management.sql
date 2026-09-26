-- ============================================================================
-- Permite que um membro edite o próprio nome de exibição e saia do
-- household — nenhuma das duas ações tinha policy antes (só existia
-- select).
-- ============================================================================

create policy "household_members_update_own" on public.household_members
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- "Sair" pode falhar com violação de FK se o membro já tiver lançamentos
-- (transactions.paid_by_member_id é not null, sem on delete) — tratado como
-- erro amigável no app, não como cascade automático de dados financeiros.
create policy "household_members_delete_own" on public.household_members
  for delete using (user_id = auth.uid());
