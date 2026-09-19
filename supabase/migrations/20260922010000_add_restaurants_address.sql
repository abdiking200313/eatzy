-- The merchant "My Store" screen (`SupabaseMerchantStoreRepository`) reads
-- and writes a free-text location for every store vertical, and for food that
-- column is `public.restaurants.address` (`MerchantVertical.storeLocationColumn`).
-- `supabase/schema.sql` declares it, but the live `public.restaurants` table
-- does not have it (it has id, name, description, logo_url, created_at,
-- owner_id, is_open), so the very first store lookup failed with
-- `column restaurants.address does not exist` and every merchant saw
-- "Your store could not be loaded".
--
-- Additive and nullable: existing rows and the customer app (which never
-- selects `address`) are unaffected. RLS is unchanged -- the existing
-- `restaurants` select/insert/update policies are row-level, not
-- column-level, so they already cover the new column.

alter table public.restaurants
  add column if not exists address text;
