-- ============================================================================
-- Open Finance via Pluggy: cada membro conecta o próprio banco (via widget
-- Pluggy Connect no app), e os lançamentos/saldos passam a ser importados
-- automaticamente em vez de digitados manualmente.
--
-- accounts.external_source já existia desde 0001_init.sql, exatamente
-- pensado pra isso ("arquitetura preparada para futura integração com Open
-- Finance"); só faltava o resto do desenho.
-- ============================================================================

-- Uma linha por "Item" da Pluggy (uma instituição conectada por um membro).
create table public.bank_connections (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  member_id uuid not null references public.household_members (id) on delete cascade,
  pluggy_item_id uuid not null unique,
  institution_name text,
  status text not null default 'UPDATING',
  last_synced_at timestamptz,
  created_at timestamptz not null default now()
);

create index bank_connections_household_id_idx on public.bank_connections (household_id);

alter table public.bank_connections enable row level security;
create policy "bank_connections_all" on public.bank_connections
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

-- Liga uma conta da Pluggy (dentro de um Item) a uma linha de `accounts` —
-- criada automaticamente na primeira sincronização.
alter table public.accounts add column pluggy_account_id uuid unique;
alter table public.accounts add column bank_connection_id uuid references public.bank_connections (id) on delete cascade;

-- Rastreia a origem de um lançamento importado — sem isso não dá pra saber
-- se ele já foi importado antes (evita duplicar a cada sincronização) nem
-- distinguir do que foi digitado manualmente.
alter table public.transactions add column external_source text;
alter table public.transactions add column external_id text;
create unique index transactions_external_id_uniq on public.transactions (external_id) where external_id is not null;
