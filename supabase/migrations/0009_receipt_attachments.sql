-- ============================================================================
-- Comprovantes: foto opcional anexada a um lançamento, guardada no Storage
-- (bucket privado, acesso via RLS + URL assinada — mesma regra de acesso
-- por household que já vale pro resto do app).
-- ============================================================================

alter table public.transactions add column receipt_path text;

insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- Convenção de caminho: "{household_id}/{transaction_id}.{ext}" — o primeiro
-- segmento do caminho é o household, checado com o mesmo helper das outras
-- tabelas (is_household_member, de 0001_init.sql).
create policy "receipts_select" on storage.objects
  for select using (
    bucket_id = 'receipts'
    and public.is_household_member((storage.foldername(name))[1]::uuid)
  );

create policy "receipts_insert" on storage.objects
  for insert with check (
    bucket_id = 'receipts'
    and public.is_household_member((storage.foldername(name))[1]::uuid)
  );

create policy "receipts_update" on storage.objects
  for update using (
    bucket_id = 'receipts'
    and public.is_household_member((storage.foldername(name))[1]::uuid)
  );

create policy "receipts_delete" on storage.objects
  for delete using (
    bucket_id = 'receipts'
    and public.is_household_member((storage.foldername(name))[1]::uuid)
  );
