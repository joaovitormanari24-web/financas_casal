-- ============================================================================
-- Habilita Realtime (postgres_changes) para que lançamentos e metas
-- apareçam automaticamente para o outro membro do household, sem precisar
-- reabrir o app.
-- ============================================================================

alter publication supabase_realtime add table public.transactions;
alter publication supabase_realtime add table public.goals;
