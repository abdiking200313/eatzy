-- Issue #129 (first child of the merchant self-service epic #128).
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- Nothing in the schema records who owns a store. `public.restaurants` and
-- `public.grocery_stores` are schema-public catalog tables with no owner or
-- creator concept, `public.profiles` has no `role` column, and the pharmacy
-- vertical has no store entity at all -- `public.pharmacy_products` links
-- only to `public.pharmacy_categories`. Every other child issue of #128
-- (merchant RLS #130, status-transition RPCs #131, the merchant app itself
-- #132/#133/#134) needs these columns to exist first.
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
--   1. `public.profiles.role` -- 'customer' | 'merchant' | 'admin', default
--      'customer' so every existing profile keeps its current (customer)
--      behaviour.
--   2. `public.restaurants.owner_id` -> `public.profiles(id)`, nullable.
--   3. `public.grocery_stores.owner_id` -> `public.profiles(id)`, nullable.
--      Existing seeded/legacy rows in both tables stay `null`, which means
--      "unowned, admin-managed". No owner is force-backfilled, because no
--      merchant profile exists yet.
--   4. `public.pharmacy_stores` -- a new store entity for the pharmacy
--      vertical, mirroring `public.grocery_stores` (which is the closest
--      existing shape: a text semantic primary key, matching the text ids
--      already used by `pharmacy_categories` / `pharmacy_products`; the
--      uuid-keyed `public.restaurants` is the older food-only table).
--      `public.pharmacy_products.store_id` then references it, and every
--      pre-existing product row is backfilled onto a single placeholder
--      store before the `not null` constraint is added, so no row is left
--      dangling.
--   5. Indexes for each new foreign key, matching this repo's convention of
--      indexing every FK used by a policy or a common query.
--
-- All of it is additive: no column, row, constraint, or table is dropped.
--
-- ---------------------------------------------------------------------
-- Deliberately NOT in this migration
-- ---------------------------------------------------------------------
--
--   * RLS write/ownership policies for the new `owner_id` columns. Merchant
--     read/write policies are the next child issue (#130). Until then the
--     columns exist but are unused and unenforceable -- no client path
--     writes them, so nothing regresses.
--   * Order-table changes (merchant-visible order queues) -- separate child
--     issue.
--
-- `public.pharmacy_stores` does get RLS enabled plus the same
-- "public reads active rows" select policy and explicit Data API grants that
-- `public.grocery_stores` already carries, because a new table exposed
-- through the Data API must never ship unrestricted. That is the read side
-- only; merchant writes stay deferred to #130.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Applying it is a deliberate manual follow-up (`supabase db push`) for a
-- human with access to the Supabase project, per this repo's migration
-- convention. It was verified by replaying `supabase/schema.sql` plus the
-- full migration chain and `supabase/seed.sql` against a throwaway local
-- Postgres 16 database.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 1. profiles.role
-- ---------------------------------------------------------------------

alter table public.profiles
  add column if not exists role text not null default 'customer'
    constraint profiles_role_check
    check (role in ('customer', 'merchant', 'admin'));

comment on column public.profiles.role is
  'Account role: customer (default), merchant (owns one or more stores, uses the merchant app), or admin. Added in issue #129; the policies that read it land in #130.';

-- ---------------------------------------------------------------------
-- 2 & 3. Store ownership on the existing catalog tables
-- ---------------------------------------------------------------------
--
-- `on delete restrict`: a profile that still owns a store cannot be deleted
-- out from under it, matching the `on delete restrict` convention already
-- used for order history (20260827103100_restrict_order_profile_deletes).

alter table public.restaurants
  add column if not exists owner_id uuid
    constraint restaurants_owner_id_fkey
    references public.profiles(id) on delete restrict;

comment on column public.restaurants.owner_id is
  'Merchant profile that owns this restaurant. Null means legacy/unowned (admin-managed) -- existing seeded rows are deliberately not backfilled. Issue #129.';

alter table public.grocery_stores
  add column if not exists owner_id uuid
    constraint grocery_stores_owner_id_fkey
    references public.profiles(id) on delete restrict;

comment on column public.grocery_stores.owner_id is
  'Merchant profile that owns this grocery store. Null means legacy/unowned (admin-managed). Issue #129.';

-- ---------------------------------------------------------------------
-- 4. Pharmacy store entity + product backfill
-- ---------------------------------------------------------------------

create table if not exists public.pharmacy_stores (
  id text primary key,
  owner_id uuid
    constraint pharmacy_stores_owner_id_fkey
    references public.profiles(id) on delete restrict,
  name text not null,
  address text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.pharmacy_stores is
  'Pharmacy vertical store entity, the pharmacy counterpart of public.grocery_stores. Added in issue #129 so pharmacy products can have an owner; merchant write policies land in #130.';

comment on column public.pharmacy_stores.owner_id is
  'Merchant profile that owns this pharmacy. Null means legacy/unowned (admin-managed). Issue #129.';

-- Shared updated_at trigger, same as every other table carrying the column
-- (20260827100000_add_updated_at_triggers.sql).
drop trigger if exists set_pharmacy_stores_updated_at on public.pharmacy_stores;
create trigger set_pharmacy_stores_updated_at
before update on public.pharmacy_stores
for each row execute function public.set_updated_at();

-- The placeholder every pre-existing product is attached to. Inserted
-- unconditionally and left active, so products that are publicly readable
-- today stay publicly readable once #130 starts joining through the store.
insert into public.pharmacy_stores (id, name, address)
values ('legacy-pharmacy', 'Legacy Pharmacy', 'Mogadishu, Somalia')
on conflict (id) do nothing;

alter table public.pharmacy_products
  add column if not exists store_id text
    constraint pharmacy_products_store_id_fkey
    references public.pharmacy_stores(id) on delete restrict;

comment on column public.pharmacy_products.store_id is
  'Pharmacy that stocks this product. Backfilled to the legacy-pharmacy placeholder for every row that predates issue #129.';

-- Backfill before the not-null constraint, so no existing row is left
-- dangling and the constraint cannot fail on live data.
update public.pharmacy_products
set store_id = 'legacy-pharmacy'
where store_id is null;

alter table public.pharmacy_products
  alter column store_id set not null;

-- RLS for the new table. Read side only -- mirrors
-- "Public reads active grocery stores" from
-- 20260727152319_connect_super_app_services.sql. Merchant/owner write
-- policies are issue #130.
alter table public.pharmacy_stores enable row level security;

drop policy if exists "Public reads active pharmacy stores"
  on public.pharmacy_stores;
create policy "Public reads active pharmacy stores"
on public.pharmacy_stores for select
to anon, authenticated
using (is_active);

revoke all on public.pharmacy_stores from anon, authenticated;
grant select on public.pharmacy_stores to anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. Indexes for the new foreign keys
-- ---------------------------------------------------------------------

create index if not exists restaurants_owner_id_idx
  on public.restaurants(owner_id);
create index if not exists grocery_stores_owner_id_idx
  on public.grocery_stores(owner_id);
create index if not exists pharmacy_stores_owner_id_idx
  on public.pharmacy_stores(owner_id);
create index if not exists pharmacy_products_store_id_idx
  on public.pharmacy_products(store_id);
