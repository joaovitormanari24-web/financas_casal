-- ============================================================================
-- Onboarding de household (briefing, seção 9): criação controlada e convite
-- do parceiro. Nenhuma policy de insert aberta em households/household_members
-- — tudo passa por função security definer, como já indicado em 0001_init.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- create_household: cria o household e o primeiro membro (o criador) em uma
-- única transação.
-- ----------------------------------------------------------------------------
create function public.create_household(household_name text, display_name text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  new_household_id uuid;
begin
  insert into public.households (name)
  values (household_name)
  returning id into new_household_id;

  insert into public.household_members (household_id, user_id, display_name)
  values (new_household_id, auth.uid(), display_name);

  return new_household_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- household_invites: código de convite de uso único para o parceiro entrar
-- no household (briefing, seção 9 — "duas contas autorizadas").
-- ----------------------------------------------------------------------------
create table public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  code text not null unique,
  created_by_member_id uuid not null references public.household_members (id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  used_at timestamptz,
  used_by_user_id uuid references auth.users (id),
  created_at timestamptz not null default now()
);

create index household_invites_household_id_idx on public.household_invites (household_id);

alter table public.household_invites enable row level security;

-- Somente membros do household veem os convites que criaram. A validação
-- e o resgate do código acontecem via função security definer abaixo, que
-- não passa por RLS — nenhum usuário externo precisa de acesso de leitura
-- direto a esta tabela.
create policy "household_invites_select" on public.household_invites
  for select using (public.is_household_member(household_id));

create policy "household_invites_insert" on public.household_invites
  for insert with check (public.is_household_member(household_id));

-- ----------------------------------------------------------------------------
-- create_household_invite: só um membro do household pode gerar convite.
-- ----------------------------------------------------------------------------
create function public.create_household_invite(target_household_id uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  new_code text;
  creator_member_id uuid;
begin
  if not public.is_household_member(target_household_id) then
    raise exception 'not a member of this household';
  end if;

  select id into creator_member_id
  from public.household_members
  where household_id = target_household_id and user_id = auth.uid()
  limit 1;

  new_code := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));

  insert into public.household_invites (household_id, code, created_by_member_id)
  values (target_household_id, new_code, creator_member_id);

  return new_code;
end;
$$;

-- ----------------------------------------------------------------------------
-- redeem_household_invite: valida o código, cria o vínculo de membro para
-- quem está entrando e marca o convite como usado — tudo atômico.
-- ----------------------------------------------------------------------------
create function public.redeem_household_invite(invite_code text, display_name text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  target_household_id uuid;
begin
  select household_id into target_household_id
  from public.household_invites
  where code = invite_code
    and used_at is null
    and expires_at > now()
  for update;

  if target_household_id is null then
    raise exception 'invalid or expired invite code';
  end if;

  insert into public.household_members (household_id, user_id, display_name)
  values (target_household_id, auth.uid(), display_name);

  update public.household_invites
  set used_at = now(), used_by_user_id = auth.uid()
  where code = invite_code;

  return target_household_id;
end;
$$;
