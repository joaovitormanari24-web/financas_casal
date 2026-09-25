-- ============================================================================
-- Finanças do Casal — schema inicial (briefing, seções 9 e 57-59)
-- Duas contas autorizadas, todos os dados pertencem a um household,
-- RLS obrigatório em toda tabela financeira.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- profiles: espelha auth.users (1-1), criado automaticamente no signup.
-- ----------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- households / household_members
-- ----------------------------------------------------------------------------
create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now(),
  unique (household_id, user_id)
);

create index household_members_user_id_idx on public.household_members (user_id);
create index household_members_household_id_idx on public.household_members (household_id);

-- Função auxiliar security definer: evita recursão de RLS ao checar
-- pertencimento a um household a partir de outras tabelas.
create function public.is_household_member(target_household_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.household_members hm
    where hm.household_id = target_household_id
      and hm.user_id = auth.uid()
  );
$$;

-- ----------------------------------------------------------------------------
-- categories: globais (household_id null) + personalizadas por household.
-- ----------------------------------------------------------------------------
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references public.households (id) on delete cascade,
  name text not null,
  icon text not null,
  color_hex text not null,
  is_custom boolean not null default false,
  created_at timestamptz not null default now()
);

create index categories_household_id_idx on public.categories (household_id);

-- ----------------------------------------------------------------------------
-- accounts / credit_cards
-- ----------------------------------------------------------------------------
create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  owner_member_id uuid references public.household_members (id) on delete set null,
  external_source text,
  created_at timestamptz not null default now()
);

create index accounts_household_id_idx on public.accounts (household_id);

create table public.credit_cards (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  institution text not null,
  credit_limit numeric(12, 2) not null check (credit_limit >= 0),
  closing_day int not null check (closing_day between 1 and 31),
  due_day int not null check (due_day between 1 and 31),
  created_at timestamptz not null default now()
);

create index credit_cards_household_id_idx on public.credit_cards (household_id);

-- ----------------------------------------------------------------------------
-- installment_plans: agrupa as parcelas de uma compra (briefing, seção 33).
-- ----------------------------------------------------------------------------
create table public.installment_plans (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  description text not null,
  total_amount numeric(12, 2) not null check (total_amount > 0),
  installment_count int not null check (installment_count > 0),
  installment_amount numeric(12, 2) not null check (installment_amount > 0),
  first_due_date date not null,
  credit_card_id uuid references public.credit_cards (id) on delete set null,
  created_at timestamptz not null default now()
);

create index installment_plans_household_id_idx on public.installment_plans (household_id);

-- ----------------------------------------------------------------------------
-- recurring_transactions: gastos recorrentes (briefing, seção 34).
-- ----------------------------------------------------------------------------
create table public.recurring_transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  description text not null,
  amount numeric(12, 2) not null check (amount > 0),
  category_id uuid not null references public.categories (id),
  frequency text not null check (frequency in ('weekly', 'monthly', 'annual')),
  day_of_cycle int not null check (day_of_cycle between 1 and 31),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index recurring_transactions_household_id_idx on public.recurring_transactions (household_id);

-- ----------------------------------------------------------------------------
-- transactions: núcleo do app (briefing, seção 28).
-- ----------------------------------------------------------------------------
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  type text not null check (type in ('income', 'expense', 'transfer')),
  amount numeric(12, 2) not null check (amount > 0),
  description text not null,
  category_id uuid not null references public.categories (id),
  date date not null,
  paid_by_member_id uuid not null references public.household_members (id),
  payment_method text not null
    check (payment_method in ('pix', 'debit', 'credit', 'cash', 'boleto', 'transfer')),
  account_id uuid references public.accounts (id) on delete set null,
  credit_card_id uuid references public.credit_cards (id) on delete set null,
  note text,
  recurring_transaction_id uuid references public.recurring_transactions (id) on delete set null,
  installment_plan_id uuid references public.installment_plans (id) on delete cascade,
  installment_number int,
  installment_total int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index transactions_household_id_date_idx on public.transactions (household_id, date desc);
create index transactions_category_id_idx on public.transactions (category_id);
create index transactions_paid_by_member_id_idx on public.transactions (paid_by_member_id);
create index transactions_installment_plan_id_idx on public.transactions (installment_plan_id);

-- ----------------------------------------------------------------------------
-- budgets: orçamento mensal por categoria (briefing, seção 35).
-- ----------------------------------------------------------------------------
create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  category_id uuid not null references public.categories (id),
  limit_amount numeric(12, 2) not null check (limit_amount > 0),
  reference_month date not null,
  created_at timestamptz not null default now(),
  unique (household_id, category_id, reference_month)
);

create index budgets_household_id_month_idx on public.budgets (household_id, reference_month);

-- ----------------------------------------------------------------------------
-- goals / goal_contributions: metas e cofrinhos (briefing, seções 20 e 37).
-- ----------------------------------------------------------------------------
create table public.goals (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  target_amount numeric(12, 2) not null check (target_amount > 0),
  current_amount numeric(12, 2) not null default 0 check (current_amount >= 0),
  target_date date,
  monthly_contribution numeric(12, 2),
  icon text not null default 'target',
  created_at timestamptz not null default now()
);

create index goals_household_id_idx on public.goals (household_id);

create table public.goal_contributions (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.goals (id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  date date not null default current_date,
  member_id uuid not null references public.household_members (id),
  created_at timestamptz not null default now()
);

create index goal_contributions_goal_id_idx on public.goal_contributions (goal_id);

-- Mantém goals.current_amount em sincronia com os aportes.
create function public.apply_goal_contribution()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.goals set current_amount = current_amount + new.amount where id = new.goal_id;
  elsif tg_op = 'DELETE' then
    update public.goals set current_amount = current_amount - old.amount where id = old.goal_id;
  end if;
  return null;
end;
$$;

create trigger on_goal_contribution_change
  after insert or delete on public.goal_contributions
  for each row execute function public.apply_goal_contribution();

-- ----------------------------------------------------------------------------
-- monthly_plans: objetivo do mês (briefing, seção 38).
-- ----------------------------------------------------------------------------
create table public.monthly_plans (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  reference_month date not null,
  savings_target numeric(12, 2) not null check (savings_target >= 0),
  income_expected numeric(12, 2),
  created_at timestamptz not null default now(),
  unique (household_id, reference_month)
);

-- ----------------------------------------------------------------------------
-- financial_simulations: histórico do simulador "Podemos gastar?" e "E se?"
-- (briefing, seções 14-18).
-- ----------------------------------------------------------------------------
create table public.financial_simulations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  created_by_member_id uuid not null references public.household_members (id),
  kind text not null check (kind in ('purchase', 'installment', 'what_if')),
  input jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now()
);

create index financial_simulations_household_id_idx on public.financial_simulations (household_id);

-- ----------------------------------------------------------------------------
-- notifications: alertas e insights (briefing, seção 36).
-- ----------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  member_id uuid references public.household_members (id) on delete cascade,
  title text not null,
  body text not null,
  kind text not null default 'info',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_household_id_idx on public.notifications (household_id);
create index notifications_member_id_idx on public.notifications (member_id);

-- ============================================================================
-- Row Level Security — obrigatório em toda tabela financeira (seção 58/59).
-- Fluxo: usuário autenticado -> household_members -> household_id -> acesso
-- somente aos dados daquele household.
-- ============================================================================

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.categories enable row level security;
alter table public.accounts enable row level security;
alter table public.credit_cards enable row level security;
alter table public.installment_plans enable row level security;
alter table public.recurring_transactions enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.goals enable row level security;
alter table public.goal_contributions enable row level security;
alter table public.monthly_plans enable row level security;
alter table public.financial_simulations enable row level security;
alter table public.notifications enable row level security;

-- profiles: cada usuário só lê/edita o próprio perfil.
create policy "profiles_select_own" on public.profiles
  for select using (id = auth.uid());
create policy "profiles_update_own" on public.profiles
  for update using (id = auth.uid());

-- households: visível para quem é membro.
create policy "households_select_member" on public.households
  for select using (public.is_household_member(id));
create policy "households_update_member" on public.households
  for update using (public.is_household_member(id));
-- Criação de household fica restrita ao fluxo de onboarding controlado
-- (service role / função dedicada) — nenhuma policy de insert aberta aqui.

-- household_members: um membro vê os outros membros do seu household.
create policy "household_members_select_same_household" on public.household_members
  for select using (public.is_household_member(household_id));

-- Helper genérico reaproveitado por todas as tabelas "household-scoped":
-- select/insert/update/delete somente se o usuário pertence ao household_id.

create policy "categories_select" on public.categories
  for select using (household_id is null or public.is_household_member(household_id));
create policy "categories_insert" on public.categories
  for insert with check (public.is_household_member(household_id));
create policy "categories_update" on public.categories
  for update using (public.is_household_member(household_id));
create policy "categories_delete" on public.categories
  for delete using (public.is_household_member(household_id));

create policy "accounts_all" on public.accounts
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy "credit_cards_all" on public.credit_cards
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy "installment_plans_all" on public.installment_plans
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy "recurring_transactions_all" on public.recurring_transactions
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy "transactions_all" on public.transactions
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy "budgets_all" on public.budgets
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy "goals_all" on public.goals
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

-- goal_contributions não tem household_id direto: resolve via goals.
create policy "goal_contributions_select" on public.goal_contributions
  for select using (
    exists (
      select 1 from public.goals g
      where g.id = goal_contributions.goal_id
        and public.is_household_member(g.household_id)
    )
  );
create policy "goal_contributions_insert" on public.goal_contributions
  for insert with check (
    exists (
      select 1 from public.goals g
      where g.id = goal_contributions.goal_id
        and public.is_household_member(g.household_id)
    )
  );
create policy "goal_contributions_delete" on public.goal_contributions
  for delete using (
    exists (
      select 1 from public.goals g
      where g.id = goal_contributions.goal_id
        and public.is_household_member(g.household_id)
    )
  );

create policy "monthly_plans_all" on public.monthly_plans
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy "financial_simulations_all" on public.financial_simulations
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy "notifications_all" on public.notifications
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
