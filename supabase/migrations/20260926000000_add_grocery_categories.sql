-- Grocery product categories.
--
-- Food (item_categories) and pharmacy (pharmacy_categories) already group
-- their catalogs; grocery had no category concept, so a store's products were
-- one flat list. This adds a public-read category table and a nullable
-- grocery_products.category_id. Nullable so merchant-created products that
-- don't pick a category still work; the app groups them under "Other".

set search_path = '';

create table if not exists public.grocery_categories (
  id text primary key,
  name text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.grocery_categories enable row level security;

drop policy if exists "Public reads active grocery categories"
  on public.grocery_categories;
create policy "Public reads active grocery categories"
on public.grocery_categories for select
to anon, authenticated
using (is_active);

-- Catalog: read-only for the API roles (same as pharmacy_categories).
revoke all on table public.grocery_categories from anon, authenticated;
grant select on table public.grocery_categories to anon, authenticated;

alter table public.grocery_products
  add column if not exists category_id text
  references public.grocery_categories (id) on delete set null;

create index if not exists grocery_products_category_id_idx
  on public.grocery_products (category_id);
