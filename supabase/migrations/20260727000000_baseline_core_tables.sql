-- Issue #276: baseline for the core tables that predate the migration chain.
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- `public.profiles`, `public.restaurants`, `public.menu_items`,
-- `public.item_categories`, `public.restaurant_locations`, `public.deals`
-- and `public.deal_items` were hand-created in the live project before
-- `20260727152319_connect_super_app_services.sql` (the first migration in
-- this directory) ran. Every later migration ALTERs, references, grants on
-- or seeds them, but no migration ever CREATEd them -- so `supabase db
-- reset` on an empty database failed at the very first migration
-- (`food_orders.restaurant_id references public.restaurants(id)`).
--
-- `public.deal_items` is not in the issue's list of six, but it belongs to
-- the same gap: `20260924020000_tighten_public_table_grants.sql` revokes and
-- grants on it by name, so a fresh replay hard-fails there without it.
--
-- ---------------------------------------------------------------------
-- How each shape was reconstructed
-- ---------------------------------------------------------------------
--
-- No live database access was available when this file was written, so the
-- shapes below are `supabase/schema.sql` (the 2026-09-18 live snapshot)
-- MINUS every change a later migration makes to these tables:
--
--   profiles     - `role` + `profiles_role_check`  (20260830120000)
--                - `deleted_at`                     (20260919000000)
--                - `dob`                            (20260923000000, after
--                                                    the snapshot)
--   restaurants  - `owner_id` + `restaurants_owner_id_fkey` and
--                  `restaurants_owner_id_idx`       (20260830120000)
--                - `address`                        (20260922010000)
--   menu_items   - `price` was converted numeric -> integer cents
--                                                   (20260903000000), so it
--                  starts here as `numeric` holding decimal dollars.
--
-- Columns that no migration adds (e.g. `restaurants.is_open`,
-- `menu_items.is_available`, every column of `item_categories`,
-- `restaurant_locations`, `deals`, `deal_items`) are assumed to have
-- existed before 20260727152319. If one was in fact hand-added live later,
-- creating it here still converges a fresh database on the live shape.
--
-- `deals.deal_price` is left `numeric(10, 2)` because that is what live
-- still has (no migration ever converted it to integer cents). That drift
-- from the cents rule in AGENTS.md is pre-existing and out of scope here;
-- this file must reproduce live, not fix it.
--
-- ---------------------------------------------------------------------
-- RLS / policies
-- ---------------------------------------------------------------------
--
-- Deliberately NOT declared here for the five tables whose RLS is owned by
-- later migrations (adding it here would make those migrations fail on
-- `create policy` for an already-existing policy name):
--   profiles, restaurant_locations - policies in 20260727152319, RLS enabled
--                                    in 20260921000000
--   restaurants, menu_items,       - RLS + read policies in 20260921000000,
--   item_categories                  merchant write policies in
--                                    20260830130000
--
-- `public.deals` and `public.deal_items` have RLS enabled and read policies
-- live (see schema.sql) but NO migration declares either, so this baseline
-- is their only home. They are recreated verbatim from schema.sql.
--
-- Not reproduced: the redundant live-only "Enable read access for all
-- users" select policies on restaurants / menu_items / item_categories
-- (dashboard-created, `to public using (true)`, fully covered by the
-- "Public reads ..." policies 20260921000000 creates), and the live-only
-- `set_deals_updated_at` trigger (its function `public.set_updated_at()`
-- is first created by 20260827100000, so it cannot exist this early).
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- Every statement is `if not exists` or guarded, so this file is a no-op
-- against the live project, which already has all seven tables. It still
-- must NOT be run there: record it as applied without executing it:
--
--   supabase migration repair --status applied 20260727000000
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.

-- ---------------------------------------------------------------------
-- profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid not null,
  firstname text not null,
  lastname text not null,
  phone text not null,
  avatar_url text,
  constraint profiles_pkey primary key (id),
  constraint profiles_id_fkey foreign key (id) references auth.users(id)
);

-- ---------------------------------------------------------------------
-- Food catalog
-- ---------------------------------------------------------------------

create table if not exists public.restaurants (
  id uuid not null default gen_random_uuid(),
  name text not null,
  description text,
  logo_url text,
  created_at timestamptz not null default now(),
  is_open boolean not null default true,
  constraint restaurants_pkey primary key (id)
);

create table if not exists public.item_categories (
  id uuid not null default gen_random_uuid(),
  name text,
  icon_url text not null,
  is_active boolean not null default false,
  constraint item_categories_pkey primary key (id)
);

create table if not exists public.menu_items (
  id uuid not null default gen_random_uuid(),
  name text not null,
  description text not null,
  price numeric not null,
  image_url text not null,
  categorie_id uuid,
  restaurant_id uuid,
  is_available boolean not null default true,
  constraint menu_items_pkey primary key (id),
  constraint menu_items_categorie_id_fkey foreign key (categorie_id)
    references public.item_categories(id),
  constraint menu_items_restaurant_id_fkey foreign key (restaurant_id)
    references public.restaurants(id)
);

create table if not exists public.restaurant_locations (
  id uuid not null default gen_random_uuid(),
  restaurant_id uuid not null,
  store_name text not null,
  phonenumber text,
  latitude numeric,
  longitude numeric,
  mapcode text,
  mapcode_territory text,
  is_active boolean default false,
  created_at timestamptz not null default now(),
  constraint restaurant_locations_pkey primary key (id),
  constraint restaurant_locations_restaurant_id_fkey foreign key (restaurant_id)
    references public.restaurants(id)
);

create table if not exists public.deals (
  id uuid not null default gen_random_uuid(),
  restaurant_id uuid not null,
  name text not null,
  description text,
  deal_price numeric(10, 2) not null,
  image_url text,
  is_active boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint deals_pkey primary key (id),
  constraint deals_restaurant_id_fkey foreign key (restaurant_id)
    references public.restaurants(id) on delete cascade,
  constraint deals_deal_price_check check (deal_price >= 0),
  constraint deals_valid_date_range check (
    ends_at is null or starts_at is null or ends_at > starts_at
  )
);

create table if not exists public.deal_items (
  id uuid not null default gen_random_uuid(),
  deal_id uuid not null,
  menu_item_id uuid not null,
  quantity integer not null default 1,
  created_at timestamptz not null default now(),
  constraint deal_items_pkey primary key (id),
  constraint deal_items_unique_item unique (deal_id, menu_item_id),
  constraint deal_items_quantity_check check (quantity > 0),
  constraint deal_items_deal_id_fkey foreign key (deal_id)
    references public.deals(id) on delete cascade,
  constraint deal_items_menu_item_id_fkey foreign key (menu_item_id)
    references public.menu_items(id) on delete restrict
);

-- ---------------------------------------------------------------------
-- Indexes: foreign keys and the deals active-window filter
-- ---------------------------------------------------------------------

create index if not exists menu_items_categorie_id_idx
  on public.menu_items using btree (categorie_id);
create index if not exists menu_items_restaurant_id_idx
  on public.menu_items using btree (restaurant_id);
create index if not exists restaurant_locations_restaurant_id_idx
  on public.restaurant_locations using btree (restaurant_id);
create index if not exists deals_restaurant_id_idx
  on public.deals using btree (restaurant_id);
create index if not exists deals_active_dates_idx
  on public.deals using btree (is_active, starts_at, ends_at);
create index if not exists deal_items_deal_id_idx
  on public.deal_items using btree (deal_id);
create index if not exists deal_items_menu_item_id_idx
  on public.deal_items using btree (menu_item_id);

-- ---------------------------------------------------------------------
-- Transient legacy table: public.orders
-- ---------------------------------------------------------------------
--
-- The old hand-written starter schema also had a generic
-- `public.orders` table (with carts/cart_items/order_items/order_events).
-- It no longer exists live, but it did exist when this chain started:
-- 20260826140000_ensure_wallet_and_payment_method_tables.sql declares
-- `wallet_transactions.order_id references public.orders(id)`, and
-- 20260827090000_drop_client_trusted_order_tables.sql then drops that FK
-- and the table (issue #75). Only `orders.id` is ever referenced, and the
-- original column list is not recoverable from this repo's history, so a
-- minimal id-only stand-in is created here purely so the chain replays.
--
-- Guarded on `public.food_orders` not existing yet (i.e. a fresh database
-- that has not run 20260727152319), so this never recreates the dropped
-- table on live or on any already-migrated database. Deny-all RLS (no
-- policies) for the short window before 20260827090000 drops it.

do $$
begin
  if to_regclass('public.food_orders') is null
     and to_regclass('public.orders') is null then
    create table public.orders (
      id uuid not null default gen_random_uuid(),
      constraint orders_pkey primary key (id)
    );
    alter table public.orders enable row level security;
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- RLS for deals / deal_items (no later migration owns these)
-- ---------------------------------------------------------------------

alter table public.deals enable row level security;
alter table public.deal_items enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'deals'
      and policyname = 'Anyone can view active deals'
  ) then
    create policy "Anyone can view active deals"
    on public.deals for select
    to anon, authenticated
    using (
      is_active = true
      and (starts_at is null or starts_at <= now())
      and (ends_at is null or ends_at > now())
    );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'deal_items'
      and policyname = 'Anyone can view items from active deals'
  ) then
    create policy "Anyone can view items from active deals"
    on public.deal_items for select
    to anon, authenticated
    using (
      exists (
        select 1
        from public.deals d
        where d.id = deal_items.deal_id
          and d.is_active = true
          and (d.starts_at is null or d.starts_at <= now())
          and (d.ends_at is null or d.ends_at > now())
      )
    );
  end if;
end;
$$;
