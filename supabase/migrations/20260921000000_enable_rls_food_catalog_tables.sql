-- Issue #74: RLS enablement is unverifiable for the food-vertical catalog
-- tables, and two policies are created without RLS ever being enabled.
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- `supabase/migrations/` contains plenty of `enable row level security`
-- statements, but none of them name the tables the food vertical actually
-- reads. Two separate gaps:
--
--   1. Orphaned policies. 20260727152319_connect_super_app_services.sql
--      creates "Customers read own profile" on public.profiles and
--      "Public reads restaurant locations" on public.restaurant_locations
--      (and grants select on both), but never enables RLS on either table.
--      A policy on a table without RLS enabled is inert: Postgres does not
--      evaluate it, so those two tables are readable in full by anyone
--      holding the grant. Replaying this migration history onto a fresh
--      project reproduces exactly that exposure.
--
--   2. Tables with zero RLS statements anywhere. public.restaurants,
--      public.menu_items and public.item_categories are hand-created live
--      tables that predate this migration history (the same root cause as
--      #34). They are nonetheless cross-referenced by later migrations --
--      20260830120000_add_merchant_role_and_store_ownership.sql adds
--      `public.restaurants.owner_id` and indexes it, and
--      20260830130000_add_merchant_catalog_write_policies.sql adds
--      insert/update/delete policies on public.restaurants and
--      public.menu_items -- and all three are read by the Dart client
--      (`lib/services/food/data/restaurant_repository.dart`,
--      `restaurant_menu_repository.dart`, `category_repository.dart`).
--      So the write policies from 20260830130000 are inert for the same
--      reason as (1), and no select policy has ever been declared for them.
--
-- #34 (closed 2026-09-17) fixed the *live* database: the backlog of pending
-- migrations was applied and Supabase's database linter (`get_advisors`)
-- confirmed RLS is on for every live table in `public`. That closure added
-- no migration files, so the repo's history is still not a replayable
-- record of the live state. This migration closes that gap.
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
--   1. `enable row level security` on public.profiles and
--      public.restaurant_locations -- enable only, the select policies
--      already exist in 20260727152319 and are left untouched.
--   2. `enable row level security` on public.restaurants,
--      public.menu_items and public.item_categories, plus the public
--      `for select` policy each one needs to stay readable.
--
-- The three new select policies are unconditional (`using (true)`) rather
-- than the `using (is_active)` shape used by public.grocery_stores /
-- public.grocery_products. That is deliberate: none of these three tables
-- is queried with an active-flag filter client-side -- the repositories
-- above read them by id or ordered by name, with no such predicate -- so
-- `using (true)` is the predicate that preserves current app behaviour.
-- Narrowing it would silently drop rows the app expects to see. It mirrors
-- the existing "Public reads restaurant locations" policy exactly.
--
-- No `grant` statements are added here. Supabase's project bootstrap grants
-- `anon`/`authenticated` base-table privileges outside of migration
-- history, which is why the other public catalog tables in this repo only
-- ever declare `enable row level security` + `create policy`. The explicit
-- `grant select on public.restaurant_locations to anon` in 20260727152319
-- is a one-off, not the house convention.
--
-- ---------------------------------------------------------------------
-- Deliberately out of scope: public.deals / public.deal_items
-- ---------------------------------------------------------------------
--
-- `lib/services/food/data/food_repository.dart` has a `fetchDeals` method
-- reading public.deals and public.deal_items, but those two tables are not
-- created or referenced by ANY migration in this directory, nor by
-- `supabase/schema.sql` -- zero mentions anywhere. As the existing comment
-- on `FoodDeal.dealPrice` in `lib/services/food/models/food_models.dart`
-- already records, `fetchDeals` has no callers in `lib/` today and this
-- repo has no way to inspect the live tables' real shape.
--
-- Writing `alter table public.deals enable row level security` here would
-- be a materially different bet from the five tables above: those are
-- corroborated by other migrations and by live client reads, whereas deals
-- would be a migration asserting the existence of a table nothing else in
-- the repo has ever seen -- and it would hard-fail the whole migration on
-- replay if the table does not exist under that name. That is the same
-- class of gap #34 covered and it needs the same treatment (verify the
-- live schema first, then backfill a create-table migration). Tracked as a
-- known follow-up, not silently skipped.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Applying it is a deliberate manual follow-up (`supabase db push`) for a
-- human with access to the Supabase project, per this repo's migration
-- convention. Per #34's closure the live database already has RLS enabled
-- on these tables, so `enable row level security` is expected to be a
-- no-op there; it is the migration history that needs to say so.
--
-- After applying, re-run Supabase's database linter and confirm no
-- `rls_disabled_in_public` / `policy_exists_rls_disabled` advisory remains.
-- ---------------------------------------------------------------------

set search_path = '';

-- ---------------------------------------------------------------------
-- 1. Enable-only: policies for these already exist in 20260727152319
-- ---------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.restaurant_locations enable row level security;

-- ---------------------------------------------------------------------
-- 2. Food catalog tables: enable RLS and restore public read access
-- ---------------------------------------------------------------------

alter table public.restaurants enable row level security;
alter table public.menu_items enable row level security;
alter table public.item_categories enable row level security;

drop policy if exists "Public reads restaurants" on public.restaurants;
create policy "Public reads restaurants"
on public.restaurants for select
to anon, authenticated
using (true);

drop policy if exists "Public reads menu items" on public.menu_items;
create policy "Public reads menu items"
on public.menu_items for select
to anon, authenticated
using (true);

drop policy if exists "Public reads item categories" on public.item_categories;
create policy "Public reads item categories"
on public.item_categories for select
to anon, authenticated
using (true);
