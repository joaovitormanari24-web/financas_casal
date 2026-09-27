-- ============================================================================
-- Reversão da integração Open Finance via Pluggy (0014 + 0018) — decisão do
-- usuário de remover a funcionalidade de trazer/cadastrar bancos, a
-- experiência de conexão não ficou boa. Dados já importados foram apagados
-- antes desta migração (transactions/accounts com external_source='pluggy',
-- e todas as bank_connections).
-- ============================================================================

drop index if exists transactions_external_id_uniq;
alter table public.transactions drop constraint if exists transactions_external_id_key;
alter table public.transactions drop column if exists external_id;
alter table public.transactions drop column if exists external_source;

alter table public.accounts drop column if exists pluggy_account_id;
alter table public.accounts drop column if exists bank_connection_id;

drop table if exists public.bank_connections;
