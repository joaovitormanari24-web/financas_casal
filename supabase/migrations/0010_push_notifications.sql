-- ============================================================================
-- Notificações push (fora do app): guarda as inscrições PushManager de cada
-- membro e dispara o envio via Edge Function "send-push" a cada notificação
-- nova inserida em `notifications` (0008_notifications.sql).
--
-- O segredo compartilhado usado pra autenticar a chamada à Edge Function
-- fica no Vault (nome "push_shared_secret") em vez de embutido aqui — ver
-- instruções de setup único enviadas separadamente.
-- ============================================================================

create extension if not exists pg_net;

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  member_id uuid not null references public.household_members (id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

create index push_subscriptions_household_id_idx on public.push_subscriptions (household_id);

alter table public.push_subscriptions enable row level security;

create policy "push_subscriptions_all" on public.push_subscriptions
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create or replace function public.trigger_send_push()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  shared_secret text;
  function_url text := 'https://bdvuefygecdagwywxrjv.supabase.co/functions/v1/send-push';
begin
  select decrypted_secret into shared_secret
  from vault.decrypted_secrets
  where name = 'push_shared_secret'
  limit 1;

  -- Sem o segredo configurado (setup único ainda não feito), não faz nada —
  -- as notificações in-app continuam funcionando normalmente.
  if shared_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', shared_secret
    ),
    body := jsonb_build_object(
      'household_id', new.household_id,
      'title', new.title,
      'body', new.body
    )
  );

  return new;
end;
$$;

create trigger on_notification_send_push
  after insert on public.notifications
  for each row execute function public.trigger_send_push();
