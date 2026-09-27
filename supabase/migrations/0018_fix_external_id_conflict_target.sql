-- ============================================================================
-- O índice único parcial em transactions.external_id (0014) não pode ser
-- usado como alvo de "ON CONFLICT (external_id)" pelo Postgres — só
-- constraints/índices sem cláusula WHERE servem pra isso. Como NULL nunca
-- conflita com NULL numa constraint UNIQUE comum, uma constraint normal já
-- dá o mesmo resultado (só lançamentos com external_id preenchido colidem
-- entre si) sem precisar do índice parcial.
-- ============================================================================

drop index if exists transactions_external_id_uniq;
alter table public.transactions add constraint transactions_external_id_key unique (external_id);
