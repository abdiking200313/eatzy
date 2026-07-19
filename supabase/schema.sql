-- Zivo Supabase starter schema.
-- Run this in the Supabase SQL editor after creating the project.

create extension if not exists "pgcrypto";

create type public.cart_status as enum ('active', 'ordered', 'abandoned');
create type public.order_status as enum (
  'pending',
  'confirmed',
  'preparing',
  'out_for_delivery',
  'delivered',
  'cancelled'
);
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

create table public.carts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  status public.cart_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.carts(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id) on delete cascade,
  quantity integer not null default 1 check (quantity > 0),
  unit_price integer not null check (unit_price >= 0),
  created_at timestamptz not null default now(),
  unique (cart_id, menu_item_id)
);

create table public.delivery_partners (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  avatar_url text,
  rating numeric(2, 1) not null default 0 check (rating >= 0 and rating <= 5),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete restrict,
  restaurant_id uuid not null references public.restaurants(id) on delete restrict,
  address_id uuid references public.addresses(id) on delete set null,
  payment_method_id uuid references public.payment_methods(id) on delete set null,
  delivery_partner_id uuid references public.delivery_partners(id) on delete set null,
  status public.order_status not null default 'pending',
  subtotal integer not null check (subtotal >= 0),
  delivery_fee integer not null default 0 check (delivery_fee >= 0),
  tax integer not null default 0 check (tax >= 0),
  total integer not null check (total >= 0),
  notes text,
  estimated_delivery_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id) on delete set null,
  item_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price integer not null check (unit_price >= 0),
  created_at timestamptz not null default now()
);

create table public.order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status public.order_status not null,
  message text,
  created_at timestamptz not null default now()
);

create table public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  type public.wallet_transaction_type not null,
  amount integer not null,
  description text not null,
  created_at timestamptz not null default now()
);

create index addresses_profile_id_idx on public.addresses(profile_id);
create index payment_methods_profile_id_idx on public.payment_methods(profile_id);
create index restaurants_category_id_idx on public.restaurants(category_id);
create index menu_items_restaurant_id_idx on public.menu_items(restaurant_id);
create index carts_profile_status_idx on public.carts(profile_id, status);
create index cart_items_cart_id_idx on public.cart_items(cart_id);
create index orders_profile_created_idx on public.orders(profile_id, created_at desc);
create index orders_restaurant_status_idx on public.orders(restaurant_id, status);
create index order_items_order_id_idx on public.order_items(order_id);
create index order_events_order_id_idx on public.order_events(order_id, created_at);
create index wallet_transactions_profile_id_idx on public.wallet_transactions(profile_id);

alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.payment_methods enable row level security;
alter table public.categories enable row level security;
alter table public.restaurants enable row level security;
alter table public.menu_items enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.delivery_partners enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_events enable row level security;
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

create policy "Payment methods belong to owner"
on public.payment_methods for all
using (auth.uid() = profile_id)
with check (auth.uid() = profile_id);

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

create policy "Carts belong to owner"
on public.carts for all
using (auth.uid() = profile_id)
with check (auth.uid() = profile_id);

create policy "Cart items belong to cart owner"
on public.cart_items for all
using (
  exists (
    select 1
    from public.carts
    where carts.id = cart_items.cart_id
      and carts.profile_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.carts
    where carts.id = cart_items.cart_id
      and carts.profile_id = auth.uid()
  )
);

create policy "Delivery partners are visible for tracking"
on public.delivery_partners for select
to authenticated
using (is_active = true);

create policy "Orders belong to owner"
on public.orders for select
using (auth.uid() = profile_id);

create policy "Customers create their own orders"
on public.orders for insert
with check (auth.uid() = profile_id);

create policy "Order items belong to order owner"
on public.order_items for select
using (
  exists (
    select 1
    from public.orders
    where orders.id = order_items.order_id
      and orders.profile_id = auth.uid()
  )
);

create policy "Customers insert items for own orders"
on public.order_items for insert
with check (
  exists (
    select 1
    from public.orders
    where orders.id = order_items.order_id
      and orders.profile_id = auth.uid()
  )
);

create policy "Order events belong to order owner"
on public.order_events for select
using (
  exists (
    select 1
    from public.orders
    where orders.id = order_events.order_id
      and orders.profile_id = auth.uid()
  )
);

create policy "Wallet transactions belong to owner"
on public.wallet_transactions for select
using (auth.uid() = profile_id);
