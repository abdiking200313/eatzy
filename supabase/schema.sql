-- Zivo Supabase schema -- SNAPSHOT of the LIVE project's public schema.
--
-- Regenerated on 2026-09-18 directly from the live database (project ref
-- jzubookmbrtslocuzepe), replacing the old hand-written starter script, which
-- had drifted badly from what is actually deployed: it defined `addresses`,
-- `categories` and `delivery_partners` (none of which exist live), gave
-- `profiles` a `membership_tier` and timestamps (live has neither, but does
-- have `role` and `deleted_at`), gave `restaurants` `image_url`/`rating`/
-- `delivery_fee`/`category_id` (live has `logo_url`), and omitted about 20
-- tables the app actually uses.
--
-- HOW TO READ THIS FILE
--   * It is REFERENCE DOCUMENTATION of what exists live: tables, columns,
--     constraints, indexes, RLS and policies. When it disagrees with the
--     Dart client, one of them is wrong -- check the live project.
--   * It is NOT a bootstrap script to run before `supabase/migrations/`.
--     Those migrations already ran against the live project, and replaying
--     them on top of a database created from this file would fail on objects
--     that already exist. Standing up a fresh project from scratch is still
--     an open item (issue #34); until then, treat migrations/ as the
--     history and this file as the current result.
--   * Re-generate it (rather than hand-editing) whenever a migration
--     changes structure, so it cannot drift again.
--
-- NOT CAPTURED HERE (defined in supabase/migrations/, whose bodies are the
-- source of truth for them):
--   Functions: admin_list_profiles, admin_lookup_profile_by_email,
--     admin_set_profile_role, advance_{food,grocery,pharmacy}_order_status,
--     can_read_order_status_event, cancel_{food,grocery,pharmacy}_order,
--     delete_own_account, handle_new_user, is_legal_order_status_transition,
--     merchant_owns_order, place_{food,grocery,pharmacy}_order,
--     set_updated_at.
--   Views: customer_activity, grocery_delivery_slots_available.
--   Triggers: set_<table>_updated_at (BEFORE UPDATE) on deals,
--     delivery_addresses, food_orders, grocery_orders, grocery_products,
--     grocery_stores, pharmacy_orders, pharmacy_products, pharmacy_stores;
--     on_auth_user_created on auth.users (calls handle_new_user).
--   Grants (table- and column-level privileges), extensions, and the data.
--
-- OBSERVATIONS WORTH KNOWING (as of the snapshot)
--   * public.profiles has only a SELECT policy ("Customers read own
--     profile"): there is no insert/update policy, so the client cannot
--     update a profile row directly.
--   * public.menu_items.description and .image_url are NOT NULL, so the
--     merchant catalog form sends '' rather than null for them.
--   * public.restaurants has no `rating`, `delivery_fee` or `category_id`.
--   * public.profiles has no `updated_at`/`created_at`.

create type public.wallet_transaction_type as enum (
  'top_up',
  'order_payment',
  'refund',
  'adjustment'
);

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

create table public.deal_items (
  id uuid not null default gen_random_uuid(),
  deal_id uuid not null,
  menu_item_id uuid not null,
  quantity integer not null default 1,
  created_at timestamptz not null default now(),
  constraint deal_items_pkey primary key (id),
  constraint deal_items_unique_item unique (deal_id, menu_item_id),
  constraint deal_items_quantity_check check ((quantity > 0))
);

create table public.deals (
  id uuid not null default gen_random_uuid(),
  restaurant_id uuid not null,
  name text not null,
  description text,
  deal_price numeric(10,2) not null,
  image_url text,
  is_active boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint deals_pkey primary key (id),
  constraint deals_deal_price_check check ((deal_price >= (0)::numeric)),
  constraint deals_valid_date_range check (((ends_at is null) or (starts_at is null) or (ends_at > starts_at)))
);

create table public.delivery_addresses (
  id uuid not null default gen_random_uuid(),
  profile_id uuid not null,
  label text,
  recipient_name text not null,
  phone text not null,
  street text not null,
  district text not null,
  city text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_addresses_pkey primary key (id)
);

create table public.food_order_items (
  id bigint generated always as identity,
  order_id uuid not null,
  menu_item_id uuid,
  item_name text not null,
  quantity integer not null,
  unit_price integer not null,
  created_at timestamptz not null default now(),
  constraint food_order_items_pkey primary key (id),
  constraint food_order_items_quantity_check check ((quantity > 0)),
  constraint food_order_items_unit_price_check check (((unit_price)::numeric >= (0)::numeric))
);

create table public.food_orders (
  id uuid not null default gen_random_uuid(),
  profile_id uuid not null,
  restaurant_id uuid not null,
  restaurant_name text not null,
  status text not null default 'confirmed',
  subtotal integer not null,
  delivery_fee integer not null default 499,
  tax integer not null default 0,
  total integer not null,
  currency text not null default 'USD',
  country text not null default 'Somalia',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  recipient_name text not null default '',
  phone text not null default '',
  street text not null default '',
  district text not null default '',
  city text not null default '',
  payment_method text not null default 'cash_on_delivery',
  payment_status text not null default 'pending_collection',
  idempotency_key text,
  delivery_address_id uuid,
  constraint food_orders_pkey primary key (id),
  constraint food_orders_profile_idempotency_key_key unique (profile_id, idempotency_key),
  constraint food_orders_country_check check ((country = 'Somalia')),
  constraint food_orders_currency_check check ((currency = 'USD')),
  constraint food_orders_delivery_fee_check check (((delivery_fee)::numeric >= (0)::numeric)),
  constraint food_orders_payment_method_check check ((payment_method = 'cash_on_delivery')),
  constraint food_orders_payment_status_check check ((payment_status = any (array['pending_collection', 'collected', 'refunded']))),
  constraint food_orders_status_check check ((status = any (array['confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled']))),
  constraint food_orders_subtotal_check check (((subtotal)::numeric >= (0)::numeric)),
  constraint food_orders_tax_check check (((tax)::numeric >= (0)::numeric)),
  constraint food_orders_total_check check (((total)::numeric >= (0)::numeric))
);

create table public.grocery_delivery_slots (
  id text not null,
  store_id text not null,
  label text not null,
  detail text not null,
  day_offset smallint not null,
  start_time time not null,
  end_time time not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint grocery_delivery_slots_pkey primary key (id),
  constraint grocery_delivery_slots_check check ((start_time < end_time)),
  constraint grocery_delivery_slots_day_offset_check check (((day_offset >= 0) and (day_offset <= 7)))
);

create table public.grocery_order_items (
  id bigint generated always as identity,
  order_id uuid not null,
  product_id text,
  product_name text not null,
  pricing_unit text not null,
  quantity numeric(12,2) not null,
  unit_price integer not null,
  created_at timestamptz not null default now(),
  constraint grocery_order_items_pkey primary key (id),
  constraint grocery_order_items_pricing_unit_check check ((pricing_unit = any (array['each', 'kilogram']))),
  constraint grocery_order_items_quantity_check check ((quantity > (0)::numeric)),
  constraint grocery_order_items_unit_price_check check (((unit_price)::numeric >= (0)::numeric))
);

create table public.grocery_orders (
  id uuid not null default gen_random_uuid(),
  profile_id uuid not null,
  store_id text not null,
  store_name text not null,
  delivery_slot_id text,
  delivery_slot_label text not null,
  delivery_window_start timestamptz not null,
  delivery_window_end timestamptz not null,
  recipient_name text not null,
  phone text not null,
  street text not null,
  district text not null,
  city text not null,
  substitution_preference text not null,
  status text not null default 'confirmed',
  subtotal integer not null,
  delivery_fee integer not null default 250,
  total integer not null,
  currency text not null default 'USD',
  country text not null default 'Somalia',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  idempotency_key text,
  payment_method text not null default 'cash_on_delivery',
  payment_status text not null default 'pending_collection',
  delivery_address_id uuid,
  constraint grocery_orders_pkey primary key (id),
  constraint grocery_orders_profile_idempotency_key_key unique (profile_id, idempotency_key),
  constraint grocery_orders_check check ((delivery_window_start < delivery_window_end)),
  constraint grocery_orders_country_check check ((country = 'Somalia')),
  constraint grocery_orders_currency_check check ((currency = 'USD')),
  constraint grocery_orders_delivery_fee_check check (((delivery_fee)::numeric >= (0)::numeric)),
  constraint grocery_orders_payment_method_check check ((payment_method = 'cash_on_delivery')),
  constraint grocery_orders_payment_status_check check ((payment_status = any (array['pending_collection', 'collected', 'refunded']))),
  constraint grocery_orders_status_check check ((status = any (array['confirmed', 'shopping', 'out_for_delivery', 'delivered', 'cancelled']))),
  constraint grocery_orders_substitution_preference_check check ((substitution_preference = any (array['best_match', 'contact_me', 'no_substitutions']))),
  constraint grocery_orders_subtotal_check check (((subtotal)::numeric >= (0)::numeric)),
  constraint grocery_orders_total_check check (((total)::numeric >= (0)::numeric))
);

create table public.grocery_products (
  id text not null,
  store_id text not null,
  name text not null,
  description text not null default '',
  unit_price integer not null,
  pricing_unit text not null,
  quantity_step numeric(8,2) not null,
  available_quantity numeric(12,2) not null,
  low_stock_threshold numeric(12,2) not null default 5,
  icon text not null default '🛒',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint grocery_products_pkey primary key (id),
  constraint grocery_products_available_quantity_check check ((available_quantity >= (0)::numeric)),
  constraint grocery_products_check check ((((pricing_unit = 'each') and (quantity_step = (1)::numeric)) or ((pricing_unit = 'kilogram') and (quantity_step = 0.5)))),
  constraint grocery_products_low_stock_threshold_check check ((low_stock_threshold >= (0)::numeric)),
  constraint grocery_products_pricing_unit_check check ((pricing_unit = any (array['each', 'kilogram']))),
  constraint grocery_products_quantity_step_check check ((quantity_step > (0)::numeric)),
  constraint grocery_products_unit_price_check check (((unit_price)::numeric >= (0)::numeric))
);

create table public.grocery_stores (
  id text not null,
  name text not null,
  area text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  owner_id uuid,
  constraint grocery_stores_pkey primary key (id)
);

create table public.item_categories (
  id uuid not null default gen_random_uuid(),
  name text,
  icon_url text not null,
  is_active boolean not null default false,
  constraint item_categories_pkey primary key (id)
);

create table public.menu_items (
  id uuid not null default gen_random_uuid(),
  name text not null,
  description text not null,
  price integer not null,
  image_url text not null,
  categorie_id uuid,
  restaurant_id uuid,
  is_available boolean not null default true,
  constraint menu_items_pkey primary key (id)
);

create table public.order_status_events (
  id uuid not null default gen_random_uuid(),
  vertical text not null,
  order_id uuid not null,
  previous_status text not null,
  new_status text not null,
  changed_by uuid not null,
  created_at timestamptz not null default now(),
  constraint order_status_events_pkey primary key (id),
  constraint order_status_events_vertical_check check ((vertical = any (array['food', 'grocery', 'pharmacy'])))
);

-- Card details are never stored here, only display metadata plus the payment
-- provider's own token.
create table public.payment_methods (
  id uuid not null default gen_random_uuid(),
  profile_id uuid not null,
  provider text not null,
  brand text not null,
  last_four text not null,
  provider_payment_method_id text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  constraint payment_methods_pkey primary key (id),
  constraint payment_methods_last_four_check check ((char_length(last_four) = 4))
);

create table public.pharmacy_categories (
  id text not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint pharmacy_categories_pkey primary key (id),
  constraint pharmacy_categories_name_key unique (name)
);

create table public.pharmacy_order_items (
  id bigint generated always as identity,
  order_id uuid not null,
  product_id text,
  product_name text not null,
  quantity integer not null,
  unit_price integer not null,
  created_at timestamptz not null default now(),
  constraint pharmacy_order_items_pkey primary key (id),
  constraint pharmacy_order_items_quantity_check check ((quantity > 0)),
  constraint pharmacy_order_items_unit_price_check check (((unit_price)::numeric >= (0)::numeric))
);

-- No store column: pharmacy ownership is derived through the order's items
-- (see merchant_owns_order), not a direct foreign key.
create table public.pharmacy_orders (
  id uuid not null default gen_random_uuid(),
  profile_id uuid not null,
  recipient_name text not null,
  phone text not null,
  city text not null,
  district text not null,
  street text not null,
  delivery_instructions text not null default '',
  status text not null default 'confirmed',
  subtotal integer not null,
  delivery_fee integer not null default 250,
  total integer not null,
  currency text not null default 'USD',
  country text not null default 'Somalia',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  payment_method text not null default 'cash_on_delivery',
  payment_status text not null default 'pending_collection',
  idempotency_key text,
  delivery_address_id uuid,
  constraint pharmacy_orders_pkey primary key (id),
  constraint pharmacy_orders_profile_idempotency_key_key unique (profile_id, idempotency_key),
  constraint pharmacy_orders_country_check check ((country = 'Somalia')),
  constraint pharmacy_orders_currency_check check ((currency = 'USD')),
  constraint pharmacy_orders_delivery_fee_check check (((delivery_fee)::numeric >= (0)::numeric)),
  constraint pharmacy_orders_payment_method_check check ((payment_method = 'cash_on_delivery')),
  constraint pharmacy_orders_payment_status_check check ((payment_status = any (array['pending_collection', 'collected', 'refunded']))),
  constraint pharmacy_orders_status_check check ((status = any (array['confirmed', 'packing', 'out_for_delivery', 'delivered', 'cancelled']))),
  constraint pharmacy_orders_subtotal_check check (((subtotal)::numeric >= (0)::numeric)),
  constraint pharmacy_orders_total_check check (((total)::numeric >= (0)::numeric))
);

create table public.pharmacy_products (
  id text not null,
  category_id text not null,
  name text not null,
  description text not null default '',
  unit_price integer not null,
  stock_quantity integer not null,
  sale_type text not null default 'otc',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  store_id text not null,
  constraint pharmacy_products_pkey primary key (id),
  constraint pharmacy_products_sale_type_check check ((sale_type = 'otc')),
  constraint pharmacy_products_stock_quantity_check check ((stock_quantity >= 0)),
  constraint pharmacy_products_unit_price_check check (((unit_price)::numeric >= (0)::numeric))
);

create table public.pharmacy_stores (
  id text not null,
  owner_id uuid,
  name text not null,
  address text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pharmacy_stores_pkey primary key (id)
);

create table public.profiles (
  id uuid not null,
  firstname text not null,
  lastname text not null,
  phone text not null,
  avatar_url text,
  role text not null default 'customer',
  deleted_at timestamptz,
  constraint profiles_pkey primary key (id),
  constraint profiles_role_check check ((role = any (array['customer', 'merchant', 'admin'])))
);

create table public.restaurant_locations (
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
  constraint restaurant_locations_pkey primary key (id)
);

create table public.restaurants (
  id uuid not null default gen_random_uuid(),
  name text not null,
  description text,
  logo_url text,
  created_at timestamptz not null default now(),
  owner_id uuid,
  is_open boolean not null default true,
  address text,
  constraint restaurants_pkey primary key (id)
);

create table public.service_pricing (
  service_id text not null,
  delivery_fee_cents integer not null,
  tax_rate numeric not null default 0,
  updated_at timestamptz not null default now(),
  constraint service_pricing_pkey primary key (service_id),
  constraint service_pricing_delivery_fee_cents_check check ((delivery_fee_cents >= 0)),
  constraint service_pricing_service_id_check check ((service_id = any (array['food', 'grocery', 'pharmacy']))),
  constraint service_pricing_tax_rate_check check (((tax_rate >= (0)::numeric) and (tax_rate < (1)::numeric)))
);

-- `order_id` is deliberately unconstrained: the referenced row lives in
-- whichever of food_orders / grocery_orders / pharmacy_orders the
-- transaction relates to, so no single-target foreign key fits.
create table public.wallet_transactions (
  id uuid not null default gen_random_uuid(),
  profile_id uuid not null,
  order_id uuid,
  type public.wallet_transaction_type not null,
  amount integer not null,
  description text not null,
  created_at timestamptz not null default now(),
  constraint wallet_transactions_pkey primary key (id)
);

-- ---------------------------------------------------------------------
-- Foreign keys
-- ---------------------------------------------------------------------

alter table public.deal_items add constraint deal_items_deal_id_fkey foreign key (deal_id) references public.deals(id) on delete cascade;
alter table public.deal_items add constraint deal_items_menu_item_id_fkey foreign key (menu_item_id) references public.menu_items(id) on delete restrict;
alter table public.deals add constraint deals_restaurant_id_fkey foreign key (restaurant_id) references public.restaurants(id) on delete cascade;
alter table public.delivery_addresses add constraint delivery_addresses_profile_id_fkey foreign key (profile_id) references auth.users(id) on delete cascade;
alter table public.food_order_items add constraint food_order_items_menu_item_id_fkey foreign key (menu_item_id) references public.menu_items(id) on delete set null;
alter table public.food_order_items add constraint food_order_items_order_id_fkey foreign key (order_id) references public.food_orders(id) on delete cascade;
alter table public.food_orders add constraint food_orders_delivery_address_id_fkey foreign key (delivery_address_id) references public.delivery_addresses(id) on delete set null;
alter table public.food_orders add constraint food_orders_profile_id_fkey foreign key (profile_id) references auth.users(id) on delete restrict;
alter table public.food_orders add constraint food_orders_restaurant_id_fkey foreign key (restaurant_id) references public.restaurants(id) on delete restrict;
alter table public.grocery_delivery_slots add constraint grocery_delivery_slots_store_id_fkey foreign key (store_id) references public.grocery_stores(id) on delete cascade;
alter table public.grocery_order_items add constraint grocery_order_items_order_id_fkey foreign key (order_id) references public.grocery_orders(id) on delete cascade;
alter table public.grocery_order_items add constraint grocery_order_items_product_id_fkey foreign key (product_id) references public.grocery_products(id) on delete set null;
alter table public.grocery_orders add constraint grocery_orders_delivery_address_id_fkey foreign key (delivery_address_id) references public.delivery_addresses(id) on delete set null;
alter table public.grocery_orders add constraint grocery_orders_delivery_slot_id_fkey foreign key (delivery_slot_id) references public.grocery_delivery_slots(id) on delete set null;
alter table public.grocery_orders add constraint grocery_orders_profile_id_fkey foreign key (profile_id) references auth.users(id) on delete restrict;
alter table public.grocery_orders add constraint grocery_orders_store_id_fkey foreign key (store_id) references public.grocery_stores(id) on delete restrict;
alter table public.grocery_products add constraint grocery_products_store_id_fkey foreign key (store_id) references public.grocery_stores(id) on delete cascade;
alter table public.grocery_stores add constraint grocery_stores_owner_id_fkey foreign key (owner_id) references public.profiles(id) on delete restrict;
alter table public.menu_items add constraint menu_items_categorie_id_fkey foreign key (categorie_id) references public.item_categories(id);
alter table public.menu_items add constraint menu_items_restaurant_id_fkey foreign key (restaurant_id) references public.restaurants(id);
alter table public.order_status_events add constraint order_status_events_changed_by_fkey foreign key (changed_by) references auth.users(id) on delete restrict;
alter table public.payment_methods add constraint payment_methods_profile_id_fkey foreign key (profile_id) references public.profiles(id) on delete cascade;
alter table public.pharmacy_order_items add constraint pharmacy_order_items_order_id_fkey foreign key (order_id) references public.pharmacy_orders(id) on delete cascade;
alter table public.pharmacy_order_items add constraint pharmacy_order_items_product_id_fkey foreign key (product_id) references public.pharmacy_products(id) on delete set null;
alter table public.pharmacy_orders add constraint pharmacy_orders_delivery_address_id_fkey foreign key (delivery_address_id) references public.delivery_addresses(id) on delete set null;
alter table public.pharmacy_orders add constraint pharmacy_orders_profile_id_fkey foreign key (profile_id) references auth.users(id) on delete restrict;
alter table public.pharmacy_products add constraint pharmacy_products_category_id_fkey foreign key (category_id) references public.pharmacy_categories(id) on delete restrict;
alter table public.pharmacy_products add constraint pharmacy_products_store_id_fkey foreign key (store_id) references public.pharmacy_stores(id) on delete restrict;
alter table public.pharmacy_stores add constraint pharmacy_stores_owner_id_fkey foreign key (owner_id) references public.profiles(id) on delete restrict;
alter table public.profiles add constraint profiles_id_fkey foreign key (id) references auth.users(id);
alter table public.restaurant_locations add constraint restaurant_locations_restaurant_id_fkey foreign key (restaurant_id) references public.restaurants(id);
alter table public.restaurants add constraint restaurants_owner_id_fkey foreign key (owner_id) references public.profiles(id) on delete restrict;
alter table public.wallet_transactions add constraint wallet_transactions_profile_id_fkey foreign key (profile_id) references public.profiles(id) on delete cascade;

-- ---------------------------------------------------------------------
-- Indexes (those not backing a primary key / unique constraint)
-- ---------------------------------------------------------------------

create index deal_items_deal_id_idx on public.deal_items using btree (deal_id);
create index deal_items_menu_item_id_idx on public.deal_items using btree (menu_item_id);
create index deals_active_dates_idx on public.deals using btree (is_active, starts_at, ends_at);
create index deals_restaurant_id_idx on public.deals using btree (restaurant_id);
create index delivery_addresses_profile_id_idx on public.delivery_addresses using btree (profile_id);
create index food_order_items_menu_item_idx on public.food_order_items using btree (menu_item_id);
create index food_order_items_order_idx on public.food_order_items using btree (order_id);
create index food_orders_delivery_address_idx on public.food_orders using btree (delivery_address_id);
create index food_orders_profile_created_idx on public.food_orders using btree (profile_id, created_at desc);
create index food_orders_restaurant_status_idx on public.food_orders using btree (restaurant_id, status);
create index grocery_delivery_slots_store_active_sort_idx on public.grocery_delivery_slots using btree (store_id, is_active, sort_order);
create index grocery_order_items_order_idx on public.grocery_order_items using btree (order_id);
create index grocery_order_items_product_idx on public.grocery_order_items using btree (product_id);
create index grocery_orders_delivery_address_idx on public.grocery_orders using btree (delivery_address_id);
create index grocery_orders_delivery_slot_idx on public.grocery_orders using btree (delivery_slot_id);
create index grocery_orders_profile_created_idx on public.grocery_orders using btree (profile_id, created_at desc);
create index grocery_orders_store_status_idx on public.grocery_orders using btree (store_id, status);
create index grocery_products_store_active_name_idx on public.grocery_products using btree (store_id, is_active, name);
create index grocery_stores_owner_id_idx on public.grocery_stores using btree (owner_id);
create index menu_items_categorie_id_idx on public.menu_items using btree (categorie_id);
create index menu_items_restaurant_id_idx on public.menu_items using btree (restaurant_id);
create index order_status_events_changed_by_idx on public.order_status_events using btree (changed_by);
create index order_status_events_order_idx on public.order_status_events using btree (vertical, order_id, created_at desc);
create index payment_methods_profile_id_idx on public.payment_methods using btree (profile_id);
create index pharmacy_order_items_order_idx on public.pharmacy_order_items using btree (order_id);
create index pharmacy_order_items_product_idx on public.pharmacy_order_items using btree (product_id);
create index pharmacy_orders_delivery_address_idx on public.pharmacy_orders using btree (delivery_address_id);
create index pharmacy_orders_profile_created_idx on public.pharmacy_orders using btree (profile_id, created_at desc);
create index pharmacy_products_category_active_name_idx on public.pharmacy_products using btree (category_id, is_active, name);
create index pharmacy_products_store_id_idx on public.pharmacy_products using btree (store_id);
create index pharmacy_stores_owner_id_idx on public.pharmacy_stores using btree (owner_id);
create index restaurant_locations_restaurant_id_idx on public.restaurant_locations using btree (restaurant_id);
create index restaurants_owner_id_idx on public.restaurants using btree (owner_id);
create index wallet_transactions_profile_id_idx on public.wallet_transactions using btree (profile_id);

-- ---------------------------------------------------------------------
-- Row level security: enabled on every table above
-- ---------------------------------------------------------------------

alter table public.deal_items enable row level security;
alter table public.deals enable row level security;
alter table public.delivery_addresses enable row level security;
alter table public.food_order_items enable row level security;
alter table public.food_orders enable row level security;
alter table public.grocery_delivery_slots enable row level security;
alter table public.grocery_order_items enable row level security;
alter table public.grocery_orders enable row level security;
alter table public.grocery_products enable row level security;
alter table public.grocery_stores enable row level security;
alter table public.item_categories enable row level security;
alter table public.menu_items enable row level security;
alter table public.order_status_events enable row level security;
alter table public.payment_methods enable row level security;
alter table public.pharmacy_categories enable row level security;
alter table public.pharmacy_order_items enable row level security;
alter table public.pharmacy_orders enable row level security;
alter table public.pharmacy_products enable row level security;
alter table public.pharmacy_stores enable row level security;
alter table public.profiles enable row level security;
alter table public.restaurant_locations enable row level security;
alter table public.restaurants enable row level security;
alter table public.service_pricing enable row level security;
alter table public.wallet_transactions enable row level security;

-- ---------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------

-- deal_items / deals
create policy "Anyone can view items from active deals"
on public.deal_items for select to anon, authenticated
using (exists (
  select 1 from public.deals d
  where d.id = deal_items.deal_id
    and d.is_active = true
    and (d.starts_at is null or d.starts_at <= now())
    and (d.ends_at is null or d.ends_at > now())
));

create policy "Anyone can view active deals"
on public.deals for select to anon, authenticated
using (is_active = true and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now()));

-- delivery_addresses
create policy "Owners create own delivery addresses"
on public.delivery_addresses for insert to authenticated
with check (profile_id = (select auth.uid()));

create policy "Owners delete own delivery addresses"
on public.delivery_addresses for delete to authenticated
using (profile_id = (select auth.uid()));

create policy "Owners read own delivery addresses"
on public.delivery_addresses for select to authenticated
using (profile_id = (select auth.uid()));

create policy "Owners update own delivery addresses"
on public.delivery_addresses for update to authenticated
using (profile_id = (select auth.uid()))
with check (profile_id = (select auth.uid()));

-- food_order_items / food_orders
create policy "Customers read own food order items"
on public.food_order_items for select to authenticated
using (exists (
  select 1 from public.food_orders orders
  where orders.id = food_order_items.order_id and orders.profile_id = (select auth.uid())
));

create policy "Merchants read own food order items"
on public.food_order_items for select to authenticated
using (public.merchant_owns_order('food', order_id));

create policy "Customers read own food orders"
on public.food_orders for select to authenticated
using ((select auth.uid()) = profile_id);

create policy "Merchants read own food orders"
on public.food_orders for select to authenticated
using (public.merchant_owns_order('food', id));

-- grocery_delivery_slots
create policy "Public reads active grocery slots"
on public.grocery_delivery_slots for select to anon, authenticated
using (is_active and exists (
  select 1 from public.grocery_stores store
  where store.id = grocery_delivery_slots.store_id and store.is_active
));

-- grocery_order_items / grocery_orders
create policy "Customers read own grocery order items"
on public.grocery_order_items for select to authenticated
using (exists (
  select 1 from public.grocery_orders orders
  where orders.id = grocery_order_items.order_id and orders.profile_id = (select auth.uid())
));

create policy "Merchants read own grocery order items"
on public.grocery_order_items for select to authenticated
using (public.merchant_owns_order('grocery', order_id));

create policy "Customers read own grocery orders"
on public.grocery_orders for select to authenticated
using ((select auth.uid()) = profile_id);

create policy "Merchants read own grocery orders"
on public.grocery_orders for select to authenticated
using (public.merchant_owns_order('grocery', id));

-- grocery_products
create policy "Merchants create own grocery products"
on public.grocery_products for insert to authenticated
with check (exists (
  select 1 from public.grocery_stores store
  where store.id = grocery_products.store_id and store.owner_id = (select auth.uid())
));

create policy "Merchants delete own grocery products"
on public.grocery_products for delete to authenticated
using (exists (
  select 1 from public.grocery_stores store
  where store.id = grocery_products.store_id and store.owner_id = (select auth.uid())
));

create policy "Merchants update own grocery products"
on public.grocery_products for update to authenticated
using (exists (
  select 1 from public.grocery_stores store
  where store.id = grocery_products.store_id and store.owner_id = (select auth.uid())
))
with check (exists (
  select 1 from public.grocery_stores store
  where store.id = grocery_products.store_id and store.owner_id = (select auth.uid())
));

create policy "Public reads active grocery products"
on public.grocery_products for select to anon, authenticated
using (is_active and exists (
  select 1 from public.grocery_stores store
  where store.id = grocery_products.store_id and store.is_active
));

-- grocery_stores
create policy "Merchants create own grocery stores"
on public.grocery_stores for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1 from public.profiles profile
    where profile.id = (select auth.uid()) and profile.role = any (array['merchant', 'admin'])
  )
);

create policy "Merchants delete own grocery stores"
on public.grocery_stores for delete to authenticated
using (owner_id = (select auth.uid()));

create policy "Merchants update own grocery stores"
on public.grocery_stores for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy "Public reads active grocery stores"
on public.grocery_stores for select to anon, authenticated
using (is_active);

-- item_categories
create policy "Enable read access for all users"
on public.item_categories for select to public
using (true);

create policy "Public reads item categories"
on public.item_categories for select to anon, authenticated
using (true);

-- menu_items
create policy "Enable read access for all users"
on public.menu_items for select to public
using (true);

create policy "Merchants create own menu items"
on public.menu_items for insert to authenticated
with check (exists (
  select 1 from public.restaurants restaurant
  where restaurant.id = menu_items.restaurant_id and restaurant.owner_id = (select auth.uid())
));

create policy "Merchants delete own menu items"
on public.menu_items for delete to authenticated
using (exists (
  select 1 from public.restaurants restaurant
  where restaurant.id = menu_items.restaurant_id and restaurant.owner_id = (select auth.uid())
));

create policy "Merchants update own menu items"
on public.menu_items for update to authenticated
using (exists (
  select 1 from public.restaurants restaurant
  where restaurant.id = menu_items.restaurant_id and restaurant.owner_id = (select auth.uid())
))
with check (exists (
  select 1 from public.restaurants restaurant
  where restaurant.id = menu_items.restaurant_id and restaurant.owner_id = (select auth.uid())
));

create policy "Public reads menu items"
on public.menu_items for select to anon, authenticated
using (true);

-- order_status_events
create policy "Order parties read status events"
on public.order_status_events for select to authenticated
using (public.can_read_order_status_event(vertical, order_id));

-- payment_methods (read-only for the client; provider tokens are written
-- server-side only)
create policy "Owners read own payment methods"
on public.payment_methods for select to authenticated
using ((select auth.uid()) = profile_id);

-- pharmacy_categories
create policy "Public reads active pharmacy categories"
on public.pharmacy_categories for select to anon, authenticated
using (is_active);

-- pharmacy_order_items / pharmacy_orders
create policy "Customers read own pharmacy order items"
on public.pharmacy_order_items for select to authenticated
using (exists (
  select 1 from public.pharmacy_orders orders
  where orders.id = pharmacy_order_items.order_id and orders.profile_id = (select auth.uid())
));

create policy "Merchants read own pharmacy order items"
on public.pharmacy_order_items for select to authenticated
using (public.merchant_owns_order('pharmacy', order_id));

create policy "Customers read own pharmacy orders"
on public.pharmacy_orders for select to authenticated
using ((select auth.uid()) = profile_id);

create policy "Merchants read own pharmacy orders"
on public.pharmacy_orders for select to authenticated
using (public.merchant_owns_order('pharmacy', id));

-- pharmacy_products
create policy "Merchants create own pharmacy products"
on public.pharmacy_products for insert to authenticated
with check (exists (
  select 1 from public.pharmacy_stores store
  where store.id = pharmacy_products.store_id and store.owner_id = (select auth.uid())
));

create policy "Merchants delete own pharmacy products"
on public.pharmacy_products for delete to authenticated
using (exists (
  select 1 from public.pharmacy_stores store
  where store.id = pharmacy_products.store_id and store.owner_id = (select auth.uid())
));

create policy "Merchants update own pharmacy products"
on public.pharmacy_products for update to authenticated
using (exists (
  select 1 from public.pharmacy_stores store
  where store.id = pharmacy_products.store_id and store.owner_id = (select auth.uid())
))
with check (exists (
  select 1 from public.pharmacy_stores store
  where store.id = pharmacy_products.store_id and store.owner_id = (select auth.uid())
));

create policy "Public reads active OTC pharmacy products"
on public.pharmacy_products for select to anon, authenticated
using (
  is_active
  and sale_type = 'otc'
  and exists (
    select 1 from public.pharmacy_categories category
    where category.id = pharmacy_products.category_id and category.is_active
  )
);

-- pharmacy_stores
create policy "Merchants create own pharmacy stores"
on public.pharmacy_stores for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1 from public.profiles profile
    where profile.id = (select auth.uid()) and profile.role = any (array['merchant', 'admin'])
  )
);

create policy "Merchants delete own pharmacy stores"
on public.pharmacy_stores for delete to authenticated
using (owner_id = (select auth.uid()));

create policy "Merchants update own pharmacy stores"
on public.pharmacy_stores for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy "Public reads active pharmacy stores"
on public.pharmacy_stores for select to anon, authenticated
using (is_active);

-- profiles (SELECT only -- see OBSERVATIONS at the top)
create policy "Customers read own profile"
on public.profiles for select to authenticated
using ((select auth.uid()) = id);

-- restaurant_locations
create policy "Public reads restaurant locations"
on public.restaurant_locations for select to anon, authenticated
using (true);

-- restaurants
create policy "Enable read access for all users"
on public.restaurants for select to public
using (true);

create policy "Merchants create own restaurants"
on public.restaurants for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1 from public.profiles profile
    where profile.id = (select auth.uid()) and profile.role = any (array['merchant', 'admin'])
  )
);

create policy "Merchants delete own restaurants"
on public.restaurants for delete to authenticated
using (owner_id = (select auth.uid()));

create policy "Merchants update own restaurants"
on public.restaurants for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy "Public reads restaurants"
on public.restaurants for select to anon, authenticated
using (true);

-- service_pricing
create policy "Authenticated reads service pricing"
on public.service_pricing for select to authenticated
using (true);

-- wallet_transactions
create policy "Wallet transactions belong to owner"
on public.wallet_transactions for select to public
using (auth.uid() = profile_id);
