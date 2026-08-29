-- Zivo Supabase starter schema.
-- Run this in the Supabase SQL editor after creating the project, before the
-- files in supabase/migrations/ (which build the per-vertical service tables
-- on top of profiles/restaurants/menu_items/categories defined here).
--
-- ---------------------------------------------------------------------
-- Removed in issue #75 — do not reintroduce without a server-side price path
-- ---------------------------------------------------------------------
--
-- This file used to define a generic ordering model: `carts`, `cart_items`,
-- `orders`, `order_items` and `order_events`, plus the `cart_status` and
-- `order_status` enums. All of it is gone, along with the
-- `"Customers create their own orders"` / `"Customers insert items for own
-- orders"` insert policies, which checked ownership
-- (auth.uid() = profile_id) but placed no constraint at all on
-- subtotal/delivery_fee/tax/total or unit_price/quantity — a client holding
-- the public anon key could have written itself an order with total = 0.
--
-- Nothing in lib/ ever queried those tables. Order placement goes through the
-- SECURITY DEFINER RPCs place_food_order / place_grocery_order /
-- place_pharmacy_order (supabase/migrations/), which derive profile_id from
-- auth.uid() and recompute every price from the database instead of trusting
-- the client; orders are read back from public.food_orders /
-- public.grocery_orders / public.pharmacy_orders and the
-- public.customer_activity view. Any future ordering surface belongs in that
-- pattern, not in a direct-insert RLS policy.
--
-- `supabase/migrations/20260827090000_drop_client_trusted_order_tables.sql`
-- performs the same removal on a database where an older copy of this file
-- was already applied.

create extension if not exists "pgcrypto";

create type public.wallet_transaction_type as enum (
  'top_up',
  'order_payment',
  'refund',
  'adjustment'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  avatar_url text,
  membership_tier text not null default 'standard',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  line1 text not null,
  line2 text,
  city text not null,
  state text,
  country text not null default 'Nigeria',
  postal_code text,
  latitude numeric(10, 7),
  longitude numeric(10, 7),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Card details are never stored here, only display metadata plus the payment
-- provider's own token. `provider_payment_method_id` is that token: it is
-- written server-side after a provider handshake and is deliberately not
-- readable by the client (see the grants further down).
create table public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null,
  brand text not null,
  last_four text not null check (char_length(last_four) = 4),
  provider_payment_method_id text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  icon_name text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  description text,
  image_url text,
  rating numeric(2, 1) not null default 0 check (rating >= 0 and rating <= 5),
  delivery_fee integer not null default 0 check (delivery_fee >= 0),
  minimum_order integer not null default 0 check (minimum_order >= 0),
  address text,
  is_open boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  name text not null,
  description text,
  price integer not null check (price >= 0),
  image_url text,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Courier directory. Rows carry personal data (full_name, phone), so nothing
-- here is client-readable — see the grants further down.
create table public.delivery_partners (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  avatar_url text,
  rating numeric(2, 1) not null default 0 check (rating >= 0 and rating <= 5),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  -- Unconstrained on purpose: the referenced order lives in whichever of
  -- public.food_orders / public.grocery_orders / public.pharmacy_orders the
  -- transaction relates to, so no single-target foreign key fits.
  order_id uuid,
  type public.wallet_transaction_type not null,
  amount integer not null,
  description text not null,
  created_at timestamptz not null default now()
);

comment on column public.wallet_transactions.order_id is
  'Unconstrained order reference. The referenced row lives in one of public.food_orders, public.grocery_orders or public.pharmacy_orders; the public.orders table this used to reference was dropped as dead code in issue #75.';

create index addresses_profile_id_idx on public.addresses(profile_id);
create index payment_methods_profile_id_idx on public.payment_methods(profile_id);
create index restaurants_category_id_idx on public.restaurants(category_id);
create index menu_items_restaurant_id_idx on public.menu_items(restaurant_id);
create index wallet_transactions_profile_id_idx on public.wallet_transactions(profile_id);

alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.payment_methods enable row level security;
alter table public.categories enable row level security;
alter table public.restaurants enable row level security;
alter table public.menu_items enable row level security;
alter table public.delivery_partners enable row level security;
alter table public.wallet_transactions enable row level security;

create policy "Profiles are readable by owner"
on public.profiles for select
using (auth.uid() = id);

create policy "Profiles are editable by owner"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "Profiles can be inserted by owner"
on public.profiles for insert
with check (auth.uid() = id);

create policy "Addresses belong to owner"
on public.addresses for all
using (auth.uid() = profile_id)
with check (auth.uid() = profile_id);

-- Read-only, and only your own rows. There is no client write path for
-- payment methods: adding one requires a provider handshake and must be done
-- by a SECURITY DEFINER RPC that writes provider_payment_method_id itself
-- (the same shape as place_food_order). A `for all` policy here would have
-- let any signed-in client forge its own provider token.
create policy "Owners read own payment methods"
on public.payment_methods for select
to authenticated
using ((select auth.uid()) = profile_id);

-- Column grants back the policy up: provider_payment_method_id is not
-- selectable by the client at all. Postgres ignores column privileges while a
-- table-wide grant exists, so the table-wide grant is revoked and the safe
-- columns are re-granted individually. service_role keeps full access.
revoke all on public.payment_methods from public, anon, authenticated;
grant select (id, profile_id, provider, brand, last_four, is_default, created_at)
  on public.payment_methods to authenticated;

create policy "Categories are public"
on public.categories for select
to authenticated, anon
using (is_active = true);

create policy "Restaurants are public"
on public.restaurants for select
to authenticated, anon
using (true);

create policy "Menu items are public"
on public.menu_items for select
to authenticated, anon
using (true);

-- public.delivery_partners deliberately has NO policy and no client grants:
-- RLS is enabled above, so it is deny-by-default for anon and authenticated.
--
-- This replaces a `for select to authenticated using (is_active = true)`
-- policy that published every active courier's full_name and phone number to
-- every signed-in account. The right scope is "only the courier(s) handling
-- the requesting user's own active orders", but no table currently links a
-- profile to a courier — the old public.orders.delivery_partner_id column was
-- part of the dead ordering model removed in issue #75, and none of
-- food_orders / grocery_orders / pharmacy_orders has a courier column. That
-- scoped set is empty for every user today, so deny-by-default *is* the
-- scoping. When courier assignment is built, add the assignment column or
-- table and write the policy through it — do not restore a blanket
-- `is_active = true` read.
revoke all on public.delivery_partners from public, anon, authenticated;

create policy "Wallet transactions belong to owner"
on public.wallet_transactions for select
using (auth.uid() = profile_id);
