-- Issue #130 (second child of the merchant self-service epic #128).
-- Builds directly on #129
-- (20260830120000_add_merchant_role_and_store_ownership.sql), which added
-- `public.profiles.role`, `public.restaurants.owner_id`,
-- `public.grocery_stores.owner_id`, `public.pharmacy_stores` and
-- `public.pharmacy_products.store_id` but deliberately shipped no write
-- policies for them.
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- All six catalog tables (three store tables, three item tables) have RLS
-- enabled with a public `for select` policy and nothing else. That is
-- deny-by-default for every write, so a merchant cannot create or maintain
-- their own listings from the client at all -- catalog data can only be
-- changed with the service role. The merchant app (#132/#133/#134) needs a
-- client-side write path that is scoped to the rows a merchant actually owns.
--
-- ---------------------------------------------------------------------
-- Trust model (decided on #128)
-- ---------------------------------------------------------------------
--
-- Immediate-live, no approval queue: a profile with role 'merchant' (or
-- 'admin') may create a store and its items, and those rows are publicly
-- readable straight away under the existing select policies. There is no
-- pending/approved state and no admin gate -- that was considered and
-- rejected for this pass. Ownership is the entire boundary:
--
--   * store rows  -- `owner_id = auth.uid()`
--   * item rows   -- the parent store's `owner_id = auth.uid()`
--
-- Role is checked only on store *creation*. Once a store row exists, the
-- `owner_id` on it is the authority for every later write, so update/delete
-- and all item writes do not re-read `profiles.role`. Demoting a profile back
-- to 'customer' therefore stops it opening new stores but does not orphan the
-- ones it already owns; revoking those is an admin/service-role action.
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
--   1. insert / update / delete policies on public.restaurants,
--      public.grocery_stores and public.pharmacy_stores, scoped to
--      `owner_id = auth.uid()`, with insert additionally requiring a
--      merchant/admin profile role.
--   2. insert / update / delete policies on public.menu_items,
--      public.grocery_products and public.pharmacy_products, scoped through
--      the parent store's `owner_id` (these tables have no owner column of
--      their own):
--        public.menu_items.restaurant_id     -> public.restaurants.id
--        public.grocery_products.store_id    -> public.grocery_stores.id
--        public.pharmacy_products.store_id   -> public.pharmacy_stores.id
--      The `with check` predicate is identical to the `using` predicate, so a
--      row cannot be moved from a store you own into one you do not (or out
--      of one you do not own into one you do).
--   3. The Data API write grants those policies need. RLS is the row-level
--      boundary, but a policy is inert without a table privilege: #129 and
--      20260727152319 both do `revoke all ... grant select` on the grocery /
--      pharmacy tables, so `authenticated` currently has select only. Writes
--      are granted to `authenticated` only, never to `anon`, and the same
--      privileges are explicitly revoked from `anon` on all six tables
--      (defence in depth against Supabase's default `grant all` on new public
--      tables -- anon has no write policy here, so this changes no behaviour).
--
-- No existing policy is dropped or altered. The public `for select` policies
-- ("Restaurants are public", "Menu items are public", "Public reads active
-- grocery stores", "Public reads active grocery products", "Public reads
-- active pharmacy stores", "Public reads active OTC pharmacy products") are
-- untouched, so anonymous and authenticated read behaviour is unchanged.
--
-- ---------------------------------------------------------------------
-- Known limitation, deliberately left for the merchant app issues
-- ---------------------------------------------------------------------
--
-- The item policies join to the parent store, and that subquery is itself
-- subject to RLS on the store table. public.restaurants reads `using (true)`
-- so food is unaffected, but the grocery and pharmacy store select policies
-- read `using (is_active)`. A merchant who deactivates their own grocery or
-- pharmacy store therefore cannot write its products until it is reactivated
-- (reactivating still works -- the store update policy does not depend on a
-- select policy). Fixing that means an owner-scoped `for select` policy on
-- the store tables, which changes select behaviour and so belongs with the
-- merchant app work, not here.
--
-- Order fulfilment (merchant-visible order queues and status transitions) is
-- issue #131 and is not touched here.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Applying it is a deliberate manual follow-up (`supabase db push`) for a
-- human with access to the Supabase project, per this repo's migration
-- convention.
--
-- Style: names are fully schema-qualified under `search_path = ''`, matching
-- the SECURITY DEFINER RPCs in this repo. `auth.uid()` is wrapped in a
-- scalar subquery so Postgres evaluates it once per statement as an InitPlan
-- instead of once per row, the same shape as the existing
-- "Owners read own payment methods" / "Customers read own profile" policies.
-- ---------------------------------------------------------------------

set search_path = '';

-- ---------------------------------------------------------------------
-- 1. Store tables -- owned directly via owner_id
-- ---------------------------------------------------------------------

-- public.restaurants

drop policy if exists "Merchants create own restaurants" on public.restaurants;
create policy "Merchants create own restaurants"
on public.restaurants for insert
to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles profile
    where profile.id = (select auth.uid())
      and profile.role in ('merchant', 'admin')
  )
);

drop policy if exists "Merchants update own restaurants" on public.restaurants;
create policy "Merchants update own restaurants"
on public.restaurants for update
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

drop policy if exists "Merchants delete own restaurants" on public.restaurants;
create policy "Merchants delete own restaurants"
on public.restaurants for delete
to authenticated
using (owner_id = (select auth.uid()));

-- public.grocery_stores

drop policy if exists "Merchants create own grocery stores"
  on public.grocery_stores;
create policy "Merchants create own grocery stores"
on public.grocery_stores for insert
to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles profile
    where profile.id = (select auth.uid())
      and profile.role in ('merchant', 'admin')
  )
);

drop policy if exists "Merchants update own grocery stores"
  on public.grocery_stores;
create policy "Merchants update own grocery stores"
on public.grocery_stores for update
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

drop policy if exists "Merchants delete own grocery stores"
  on public.grocery_stores;
create policy "Merchants delete own grocery stores"
on public.grocery_stores for delete
to authenticated
using (owner_id = (select auth.uid()));

-- public.pharmacy_stores

drop policy if exists "Merchants create own pharmacy stores"
  on public.pharmacy_stores;
create policy "Merchants create own pharmacy stores"
on public.pharmacy_stores for insert
to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles profile
    where profile.id = (select auth.uid())
      and profile.role in ('merchant', 'admin')
  )
);

drop policy if exists "Merchants update own pharmacy stores"
  on public.pharmacy_stores;
create policy "Merchants update own pharmacy stores"
on public.pharmacy_stores for update
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

drop policy if exists "Merchants delete own pharmacy stores"
  on public.pharmacy_stores;
create policy "Merchants delete own pharmacy stores"
on public.pharmacy_stores for delete
to authenticated
using (owner_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 2. Item tables -- ownership is inherited from the parent store
-- ---------------------------------------------------------------------

-- public.menu_items -> public.restaurants

drop policy if exists "Merchants create own menu items" on public.menu_items;
create policy "Merchants create own menu items"
on public.menu_items for insert
to authenticated
with check (
  exists (
    select 1
    from public.restaurants restaurant
    where restaurant.id = menu_items.restaurant_id
      and restaurant.owner_id = (select auth.uid())
  )
);

drop policy if exists "Merchants update own menu items" on public.menu_items;
create policy "Merchants update own menu items"
on public.menu_items for update
to authenticated
using (
  exists (
    select 1
    from public.restaurants restaurant
    where restaurant.id = menu_items.restaurant_id
      and restaurant.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.restaurants restaurant
    where restaurant.id = menu_items.restaurant_id
      and restaurant.owner_id = (select auth.uid())
  )
);

drop policy if exists "Merchants delete own menu items" on public.menu_items;
create policy "Merchants delete own menu items"
on public.menu_items for delete
to authenticated
using (
  exists (
    select 1
    from public.restaurants restaurant
    where restaurant.id = menu_items.restaurant_id
      and restaurant.owner_id = (select auth.uid())
  )
);

-- public.grocery_products -> public.grocery_stores

drop policy if exists "Merchants create own grocery products"
  on public.grocery_products;
create policy "Merchants create own grocery products"
on public.grocery_products for insert
to authenticated
with check (
  exists (
    select 1
    from public.grocery_stores store
    where store.id = grocery_products.store_id
      and store.owner_id = (select auth.uid())
  )
);

drop policy if exists "Merchants update own grocery products"
  on public.grocery_products;
create policy "Merchants update own grocery products"
on public.grocery_products for update
to authenticated
using (
  exists (
    select 1
    from public.grocery_stores store
    where store.id = grocery_products.store_id
      and store.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.grocery_stores store
    where store.id = grocery_products.store_id
      and store.owner_id = (select auth.uid())
  )
);

drop policy if exists "Merchants delete own grocery products"
  on public.grocery_products;
create policy "Merchants delete own grocery products"
on public.grocery_products for delete
to authenticated
using (
  exists (
    select 1
    from public.grocery_stores store
    where store.id = grocery_products.store_id
      and store.owner_id = (select auth.uid())
  )
);

-- public.pharmacy_products -> public.pharmacy_stores

drop policy if exists "Merchants create own pharmacy products"
  on public.pharmacy_products;
create policy "Merchants create own pharmacy products"
on public.pharmacy_products for insert
to authenticated
with check (
  exists (
    select 1
    from public.pharmacy_stores store
    where store.id = pharmacy_products.store_id
      and store.owner_id = (select auth.uid())
  )
);

drop policy if exists "Merchants update own pharmacy products"
  on public.pharmacy_products;
create policy "Merchants update own pharmacy products"
on public.pharmacy_products for update
to authenticated
using (
  exists (
    select 1
    from public.pharmacy_stores store
    where store.id = pharmacy_products.store_id
      and store.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.pharmacy_stores store
    where store.id = pharmacy_products.store_id
      and store.owner_id = (select auth.uid())
  )
);

drop policy if exists "Merchants delete own pharmacy products"
  on public.pharmacy_products;
create policy "Merchants delete own pharmacy products"
on public.pharmacy_products for delete
to authenticated
using (
  exists (
    select 1
    from public.pharmacy_stores store
    where store.id = pharmacy_products.store_id
      and store.owner_id = (select auth.uid())
  )
);

-- ---------------------------------------------------------------------
-- 3. Data API write grants
-- ---------------------------------------------------------------------
--
-- Only `authenticated` gets write privileges, and only on these six catalog
-- tables. Every row-level decision stays with the policies above.

grant insert, update, delete on
  public.restaurants,
  public.menu_items,
  public.grocery_stores,
  public.grocery_products,
  public.pharmacy_stores,
  public.pharmacy_products
to authenticated;

revoke insert, update, delete on
  public.restaurants,
  public.menu_items,
  public.grocery_stores,
  public.grocery_products,
  public.pharmacy_stores,
  public.pharmacy_products
from anon;

reset search_path;
