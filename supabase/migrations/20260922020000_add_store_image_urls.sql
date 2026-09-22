-- Cross-vertical "Popular Stores" feed needs a photo for every store type.
-- Food already has one (`public.restaurants.logo_url`), but the grocery and
-- pharmacy store entities carry no image column at all:
--   * `public.grocery_stores` (id, name, area, is_active, created_at,
--     updated_at, owner_id) -- 20260727152319 + 20260830120000
--   * `public.pharmacy_stores` (id, owner_id, name, address, is_active,
--     created_at, updated_at) -- 20260830120000
--
-- Additive and nullable, so existing rows and every current query are
-- unaffected; the feed treats null as "no photo" and falls back to a
-- placeholder. The column is named `image_url` rather than `logo_url`
-- because these are storefront photos, not brand marks -- the food side
-- keeps `logo_url` and callers map both into one feed field.
--
-- RLS is unchanged. Every policy on both tables is row-level, not
-- column-level -- reads are "Public reads active grocery stores" /
-- "Public reads active pharmacy stores" (`using (is_active)`) and writes are
-- the merchant `owner_id = (select auth.uid())` policies from
-- 20260830130000 -- so they already cover the new column. The table-level
-- `grant select on public.pharmacy_stores to anon, authenticated`
-- (20260830120000) is likewise not column-scoped and needs no restatement.

alter table public.grocery_stores
  add column if not exists image_url text;

comment on column public.grocery_stores.image_url is
  'Optional storefront photo URL, shown in the cross-vertical Popular Stores feed. Null means no photo -- clients fall back to a placeholder.';

alter table public.pharmacy_stores
  add column if not exists image_url text;

comment on column public.pharmacy_stores.image_url is
  'Optional storefront photo URL, shown in the cross-vertical Popular Stores feed. Null means no photo -- clients fall back to a placeholder.';
