-- Issue #83: `updated_at timestamptz not null default now()` columns exist on
-- several tables but nothing ever maintains them after the initial insert —
-- no `create trigger` existed anywhere under `supabase/` before this file.
-- The column was only ever set by hand in a few `on conflict do update` seed
-- clauses and in the stock-decrement branch of `place_grocery_order`; every
-- other write path (including plain `update ... set status = ...` on the
-- order tables) left it stale at the row's original insert time.
--
-- ---------------------------------------------------------------------
-- Live table list, verified against the current repo (2026-08-27) rather
-- than trusting the issue's original "twelve tables" count
-- ---------------------------------------------------------------------
--
-- The issue was filed 2026-08-15 against
-- `20260727152319_connect_super_app_services.sql` and
-- `20260727164413_add_long_stay_cleaner_marketplace.sql`. Those two files
-- together declare `updated_at` on ten tables, but four of them belonged to
-- the cleaning vertical, which `20260815153920_remove_cleaning_vertical.sql`
-- (also issue #50) dropped outright:
--   - public.cleaning_services               -- dropped
--   - public.cleaning_professionals           -- dropped
--   - public.cleaning_bookings                -- dropped
--   - public.cleaning_professional_stay_plans -- dropped
--
-- That leaves six still-live tables from those two migrations:
--   - public.grocery_stores
--   - public.grocery_products
--   - public.pharmacy_products
--   - public.food_orders
--   - public.grocery_orders
--   - public.pharmacy_orders
--
-- Separately, `supabase/schema.sql` (the standalone provisioning script run
-- once against the live project, ahead of this migration chain) declares
-- `updated_at` on four more tables that are unambiguously still live and
-- share the exact same defect:
--   - public.profiles
--   - public.addresses
--   - public.restaurants
--   - public.menu_items
-- (`payment_methods`, `categories`, `delivery_partners` and
-- `wallet_transactions` in schema.sql do NOT declare `updated_at` and are
-- left alone.)
--
-- The issue's own diagnosis ("no create trigger exists anywhere in
-- supabase/") is not scoped to just the two migration files it happened to
-- cite, so this migration covers all ten tables above rather than only the
-- six that survive from the originally-cited files. No column is dropped:
-- every one of these ten tables plausibly benefits from an accurate
-- `updated_at` (order status transitions, catalog edits, profile/address
-- edits), so the trigger is the right fix everywhere, per the issue's own
-- preferred approach.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE by
-- the change that adds this file. It is purely additive (one shared function,
-- ten `before update` triggers) and touches no existing rows or columns.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Shared BEFORE UPDATE trigger function: stamps NEW.updated_at = now() on every row update. Attached to every table below that declares an updated_at column (issue #83).';

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_addresses_updated_at on public.addresses;
create trigger set_addresses_updated_at
before update on public.addresses
for each row execute function public.set_updated_at();

drop trigger if exists set_restaurants_updated_at on public.restaurants;
create trigger set_restaurants_updated_at
before update on public.restaurants
for each row execute function public.set_updated_at();

drop trigger if exists set_menu_items_updated_at on public.menu_items;
create trigger set_menu_items_updated_at
before update on public.menu_items
for each row execute function public.set_updated_at();

drop trigger if exists set_grocery_stores_updated_at on public.grocery_stores;
create trigger set_grocery_stores_updated_at
before update on public.grocery_stores
for each row execute function public.set_updated_at();

drop trigger if exists set_grocery_products_updated_at on public.grocery_products;
create trigger set_grocery_products_updated_at
before update on public.grocery_products
for each row execute function public.set_updated_at();

drop trigger if exists set_pharmacy_products_updated_at on public.pharmacy_products;
create trigger set_pharmacy_products_updated_at
before update on public.pharmacy_products
for each row execute function public.set_updated_at();

drop trigger if exists set_food_orders_updated_at on public.food_orders;
create trigger set_food_orders_updated_at
before update on public.food_orders
for each row execute function public.set_updated_at();

drop trigger if exists set_grocery_orders_updated_at on public.grocery_orders;
create trigger set_grocery_orders_updated_at
before update on public.grocery_orders
for each row execute function public.set_updated_at();

drop trigger if exists set_pharmacy_orders_updated_at on public.pharmacy_orders;
create trigger set_pharmacy_orders_updated_at
before update on public.pharmacy_orders
for each row execute function public.set_updated_at();
