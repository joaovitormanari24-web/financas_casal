-- ============================================================================
-- Categorias padrão do sistema (household_id null = global, visível a todos
-- os households via a policy "categories_select" de 0001_init.sql).
-- ============================================================================

insert into public.categories (household_id, name, icon, color_hex, is_custom) values
  (null, 'Moradia', 'home', '#1F6F5C', false),
  (null, 'Alimentação', 'restaurant', '#B8862F', false),
  (null, 'Transporte', 'directions_car', '#2E6B8F', false),
  (null, 'Saúde', 'local_hospital', '#C0562F', false),
  (null, 'Lazer', 'sports_esports', '#8F5FA6', false),
  (null, 'Compras', 'shopping_bag', '#A6738F', false),
  (null, 'Educação', 'school', '#3A6B4F', false),
  (null, 'Assinaturas', 'subscriptions', '#5F7A8F', false),
  (null, 'Contas', 'receipt_long', '#6B6E6B', false),
  (null, 'Pets', 'pets', '#8F6B3A', false),
  (null, 'Viagem', 'flight', '#2E8B75', false),
  (null, 'Salário', 'payments', '#1F6F5C', false),
  (null, 'Investimentos', 'trending_up', '#2E6B8F', false),
  (null, 'Outros', 'more_horiz', '#A1A39F', false);
