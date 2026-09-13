-- Issue #8: standardize every money column on integer smallest-currency-units
-- (cents), per AGENTS.md's original rule, and stop the drift between
-- `supabase/schema.sql` (integer cents) and the per-vertical order tables
-- created by `supabase/migrations/20260727152319_connect_super_app_services.sql`
-- onward (`numeric(12, 2)` decimal dollars).
--
-- ---------------------------------------------------------------------
-- Why this is a real data migration, not just a type rename
-- ---------------------------------------------------------------------
--
--   * `public.menu_items.price` is declared `integer` by `supabase/schema.sql`,
--     but the live/production column is actually `numeric` holding decimal
--     dollar values (confirmed directly against the REST API: rows like
--     `4.00`, `5.50`). `schema.sql` is a standalone provisioning script run
--     once by hand, not a generated dump of applied migrations (see its own
--     header and the investigation in
--     `20260827090000_drop_client_trusted_order_tables.sql`), so editing its
--     text — already done for other columns/names in issue #3 — never
--     retroactively changed the live column. This migration is what actually
--     converts the live column, in place, multiplying by 100.
--   * `grocery_products.unit_price`, `pharmacy_products.unit_price`, and
--     every `subtotal` / `delivery_fee` / `tax` / `total` / `unit_price`
--     column on `food_orders(_items)`, `grocery_orders(_items)`, and
--     `pharmacy_orders(_items)` were created as `numeric(12, 2)` decimal
--     dollars by `20260727152319_connect_super_app_services.sql` and have
--     stayed that way through every later migration that touches those
--     tables. These are converted the same way.
--   * `public.wallet_transactions.amount` is already `integer` cents (see
--     `supabase/schema.sql` and
--     `20260826140000_ensure_wallet_and_payment_method_tables.sql`) and needs
--     no data change here.
--   * `grocery_products.available_quantity` / `low_stock_threshold` /
--     `quantity_step`, and `grocery_order_items.quantity`, are physical
--     quantities (kilograms or units), not money, and are intentionally left
--     as `numeric` — issue #8 is about currency representation only.
--   * The cleaning vertical's money columns (`cleaning_services.hourly_rate`,
--     `cleaning_bookings.subtotal`/`total`/etc.) are not touched: those
--     tables were dropped entirely in
--     `20260815153920_remove_cleaning_vertical.sql` and no longer exist.
--
-- The issue also asks to drop/annotate the legacy integer-cents tables this
-- drift left as "the odd ones out" (`orders`, `cart_items`,
-- `wallet_transactions`). By the time this migration was written,
-- `public.orders` and `public.cart_items` were already dropped as dead code
-- by `20260827090000_drop_client_trusted_order_tables.sql` (issue #75) —
-- there is nothing left here to drop. `public.wallet_transactions` is very
-- much alive (`lib/features/wallet/data/wallet_repository.dart` reads it,
-- `supabase/schema.sql` grants it a `select` RLS policy) and was already
-- integer cents before this migration, so it needs neither a drop nor a
-- change — it stops being "the odd one out" simply because every other money
-- column above now matches its convention.
--
-- A `numeric(12, 2)` value's decimal places are preserved by
-- `unit_price * 100`, and `round(..., 0)` guards against any pre-existing row
-- with more than two decimal places before the final cast to `integer`.
--
-- Columns that carry a decimal-dollar default (`delivery_fee`) have that
-- default dropped before the type change and re-added in cents afterward:
-- letting `alter column ... type integer` implicitly recast a `4.99`/`2.50`
-- default would round it to the nearest *dollar* (`5`/`3`), not convert it to
-- cents, which is not the same operation as the `USING` expression applied to
-- existing rows.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE by
-- the change that adds this file. Per this repo's migration convention, a
-- human with access to the Supabase project must run `supabase db push` (or
-- apply this file directly) after reviewing it. Take a backup first: this
-- rewrites every row of every table listed below.

-- ---------------------------------------------------------------------
-- 0. Drop public.customer_activity first.
--
-- Postgres refuses to change the type of a column a view's `_RETURN` rule
-- depends on ("cannot alter type of a column used by a view or rule"), and
-- `food_orders.total` / `grocery_orders.total` / `pharmacy_orders.total`
-- feed straight into this view's `amount` column (see
-- `20260815153920_remove_cleaning_vertical.sql`, the current definition).
-- Dropping and recreating it identically (section 6 below) works around
-- that; the view's own type then simply tracks the new integer columns.
-- ---------------------------------------------------------------------

drop view public.customer_activity;

-- ---------------------------------------------------------------------
-- 1. Food: menu_items.price, food_orders.*, food_order_items.unit_price
-- ---------------------------------------------------------------------

alter table public.menu_items
  alter column price type integer
  using round(price * 100)::integer;

alter table public.food_orders
  alter column delivery_fee drop default;

alter table public.food_orders
  alter column subtotal type integer using round(subtotal * 100)::integer,
  alter column delivery_fee type integer using round(delivery_fee * 100)::integer,
  alter column tax type integer using round(tax * 100)::integer,
  alter column total type integer using round(total * 100)::integer;

alter table public.food_orders
  alter column delivery_fee set default 499;

alter table public.food_order_items
  alter column unit_price type integer
  using round(unit_price * 100)::integer;

-- ---------------------------------------------------------------------
-- 2. Grocery: grocery_products.unit_price, grocery_orders.*,
--    grocery_order_items.unit_price
-- ---------------------------------------------------------------------

alter table public.grocery_products
  alter column unit_price type integer
  using round(unit_price * 100)::integer;

alter table public.grocery_orders
  alter column delivery_fee drop default;

alter table public.grocery_orders
  alter column subtotal type integer using round(subtotal * 100)::integer,
  alter column delivery_fee type integer using round(delivery_fee * 100)::integer,
  alter column total type integer using round(total * 100)::integer;

alter table public.grocery_orders
  alter column delivery_fee set default 250;

alter table public.grocery_order_items
  alter column unit_price type integer
  using round(unit_price * 100)::integer;

-- ---------------------------------------------------------------------
-- 3. Pharmacy: pharmacy_products.unit_price, pharmacy_orders.*,
--    pharmacy_order_items.unit_price
-- ---------------------------------------------------------------------

alter table public.pharmacy_products
  alter column unit_price type integer
  using round(unit_price * 100)::integer;

alter table public.pharmacy_orders
  alter column delivery_fee drop default;

alter table public.pharmacy_orders
  alter column subtotal type integer using round(subtotal * 100)::integer,
  alter column delivery_fee type integer using round(delivery_fee * 100)::integer,
  alter column total type integer using round(total * 100)::integer;

alter table public.pharmacy_orders
  alter column delivery_fee set default 250;

alter table public.pharmacy_order_items
  alter column unit_price type integer
  using round(unit_price * 100)::integer;

-- ---------------------------------------------------------------------
-- 4. Recreate public.customer_activity, identical to
--    `20260815153920_remove_cleaning_vertical.sql`'s definition (the current
--    one) other than `amount` now being integer cents, which follows
--    automatically from `orders.total` above -- the view text itself does
--    not change.
--
-- Dropping a view also drops its grants, so the revoke/grant pair from
-- `20260727152319_connect_super_app_services.sql` (never restated by the
-- cleaning-removal migration, since that one used `create or replace view`
-- rather than drop+recreate) is restated here too.
-- ---------------------------------------------------------------------

create view public.customer_activity
with (security_invoker = true)
as
select
  orders.id,
  orders.profile_id,
  'food'::text as service_id,
  orders.restaurant_name as title,
  'Food order • Somalia'::text as subtitle,
  orders.status,
  orders.created_at as occurred_at,
  orders.total as amount,
  '/food'::text as details_route
from public.food_orders orders
union all
select
  orders.id,
  orders.profile_id,
  'grocery'::text as service_id,
  orders.store_name as title,
  orders.delivery_slot_label as subtitle,
  orders.status,
  orders.created_at as occurred_at,
  orders.total as amount,
  '/grocery'::text as details_route
from public.grocery_orders orders
union all
select
  orders.id,
  orders.profile_id,
  'pharmacy'::text as service_id,
  'Pharmacy order'::text as title,
  orders.customer_name || ' • Somalia' as subtitle,
  orders.status,
  orders.created_at as occurred_at,
  orders.total as amount,
  '/pharmacy'::text as details_route
from public.pharmacy_orders orders;

revoke all on public.customer_activity from public, anon, authenticated;
grant select on public.customer_activity to authenticated, service_role;

-- ---------------------------------------------------------------------
-- 5. place_food_order / place_grocery_order / place_pharmacy_order now
--    compute entirely in integer cents instead of decimal-dollar literals.
--
-- Signatures are unchanged from their current definitions
-- (`20260830150000_fix_place_food_order_overload.sql` for place_food_order,
-- `20260827101327_deterministic_lock_order_grocery_pharmacy.sql` for the
-- other two), so `create or replace function` keeps the existing
-- revoke/grant ACL — it is not restated here.
-- ---------------------------------------------------------------------

create or replace function public.place_food_order(
  p_restaurant_id uuid,
  p_recipient_name text,
  p_phone text,
  p_street text,
  p_district text,
  p_city text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_order_id uuid;
  v_restaurant_name text;
  v_input_count integer;
  v_valid_count integer;
  v_unique_count integer;
  v_subtotal integer;
  v_delivery_fee integer := 499;
  v_tax integer;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'A food order requires at least one item';
  end if;
  if jsonb_array_length(p_items) > 100 then
    raise exception 'A food order cannot contain more than 100 items';
  end if;
  if coalesce(trim(p_recipient_name), '') = ''
     or coalesce(trim(p_phone), '') = ''
     or coalesce(trim(p_street), '') = ''
     or coalesce(trim(p_district), '') = ''
     or coalesce(trim(p_city), '') = '' then
    raise exception 'Complete food delivery details are required';
  end if;

  select name
  into v_restaurant_name
  from public.restaurants
  where id = p_restaurant_id
    and is_open;

  if v_restaurant_name is null then
    raise exception 'Restaurant not found';
  end if;

  v_input_count := jsonb_array_length(p_items);

  select
    count(*)::integer,
    count(distinct input.menu_item_id)::integer,
    coalesce(sum(menu.price * input.quantity), 0)::integer
  into v_valid_count, v_unique_count, v_subtotal
  from jsonb_to_recordset(p_items)
    as input(menu_item_id uuid, quantity integer)
  join public.menu_items menu
    on menu.id = input.menu_item_id
   and menu.restaurant_id = p_restaurant_id
   and menu.is_available
  where input.quantity > 0
    and input.quantity <= 99;

  if v_valid_count <> v_input_count
     or v_unique_count <> v_input_count
     or v_subtotal <= 0 then
    raise exception 'Food order contains invalid items';
  end if;

  v_tax := round(v_subtotal * 0.10)::integer;

  insert into public.food_orders (
    profile_id,
    restaurant_id,
    restaurant_name,
    recipient_name,
    phone,
    street,
    district,
    city,
    subtotal,
    delivery_fee,
    tax,
    total
  )
  values (
    v_profile_id,
    p_restaurant_id,
    v_restaurant_name,
    trim(p_recipient_name),
    trim(p_phone),
    trim(p_street),
    trim(p_district),
    trim(p_city),
    v_subtotal,
    v_delivery_fee,
    v_tax,
    v_subtotal + v_delivery_fee + v_tax
  )
  returning id into v_order_id;

  insert into public.food_order_items (
    order_id,
    menu_item_id,
    item_name,
    quantity,
    unit_price
  )
  select
    v_order_id,
    menu.id,
    menu.name,
    input.quantity,
    menu.price
  from jsonb_to_recordset(p_items)
    as input(menu_item_id uuid, quantity integer)
  join public.menu_items menu
    on menu.id = input.menu_item_id
   and menu.restaurant_id = p_restaurant_id
   and menu.is_available
  where input.quantity > 0
    and input.quantity <= 99;

  return v_order_id;
end;
$$;

create or replace function public.place_grocery_order(
  p_store_id text,
  p_delivery_slot_id text,
  p_recipient_name text,
  p_phone text,
  p_street text,
  p_district text,
  p_city text,
  p_substitution_preference text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_order_id uuid;
  v_store_name text;
  v_slot_label text;
  v_delivery_window_start timestamptz;
  v_delivery_window_end timestamptz;
  v_input_count integer;
  v_valid_count integer;
  v_unique_count integer;
  v_subtotal integer;
  v_delivery_fee integer := 250;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'A grocery order requires at least one item';
  end if;
  if coalesce(trim(p_recipient_name), '') = ''
     or coalesce(trim(p_phone), '') = ''
     or coalesce(trim(p_street), '') = ''
     or coalesce(trim(p_district), '') = ''
     or coalesce(trim(p_city), '') = '' then
    raise exception 'Complete grocery delivery details are required';
  end if;
  if p_substitution_preference not in (
    'best_match',
    'contact_me',
    'no_substitutions'
  ) then
    raise exception 'Invalid substitution preference';
  end if;

  select name
  into v_store_name
  from public.grocery_stores
  where id = p_store_id and is_active;

  if v_store_name is null then
    raise exception 'Grocery store not found';
  end if;

  select
    label || ', ' || detail,
    (
      (now() at time zone 'Africa/Mogadishu')::date
        + day_offset
        + start_time
    ) at time zone 'Africa/Mogadishu',
    (
      (now() at time zone 'Africa/Mogadishu')::date
        + day_offset
        + end_time
    ) at time zone 'Africa/Mogadishu'
  into
    v_slot_label,
    v_delivery_window_start,
    v_delivery_window_end
  from public.grocery_delivery_slots
  where id = p_delivery_slot_id
    and store_id = p_store_id
    and is_active;

  if v_slot_label is null then
    raise exception 'Delivery slot not found';
  end if;

  v_input_count := jsonb_array_length(p_items);

  perform 1
  from public.grocery_products product
  join jsonb_to_recordset(p_items)
    as input(product_id text, quantity numeric)
    on product.id = input.product_id
  where product.store_id = p_store_id
  order by product.id
  for update of product;

  -- unit_price (integer cents) * quantity (numeric, e.g. 0.5 kg) can land on
  -- a fractional cent, so the sum is rounded to the nearest cent before the
  -- cast to integer -- the same rounding `place_food_order`'s tax line uses.
  select
    count(*)::integer,
    count(distinct input.product_id)::integer,
    round(coalesce(sum(product.unit_price * input.quantity), 0))::integer
  into v_valid_count, v_unique_count, v_subtotal
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity numeric)
  join public.grocery_products product
    on product.id = input.product_id
   and product.store_id = p_store_id
   and product.is_active
  where input.quantity > 0
    and input.quantity <= product.available_quantity
    and mod(input.quantity, product.quantity_step) = 0;

  if v_valid_count <> v_input_count
     or v_unique_count <> v_input_count
     or v_subtotal <= 0 then
    raise exception 'Grocery order contains invalid items';
  end if;

  insert into public.grocery_orders (
    profile_id,
    store_id,
    store_name,
    delivery_slot_id,
    delivery_slot_label,
    delivery_window_start,
    delivery_window_end,
    recipient_name,
    phone,
    street,
    district,
    city,
    substitution_preference,
    subtotal,
    delivery_fee,
    total
  )
  values (
    v_profile_id,
    p_store_id,
    v_store_name,
    p_delivery_slot_id,
    v_slot_label,
    v_delivery_window_start,
    v_delivery_window_end,
    trim(p_recipient_name),
    trim(p_phone),
    trim(p_street),
    trim(p_district),
    trim(p_city),
    p_substitution_preference,
    v_subtotal,
    v_delivery_fee,
    v_subtotal + v_delivery_fee
  )
  returning id into v_order_id;

  insert into public.grocery_order_items (
    order_id,
    product_id,
    product_name,
    pricing_unit,
    quantity,
    unit_price
  )
  select
    v_order_id,
    product.id,
    product.name,
    product.pricing_unit,
    input.quantity,
    product.unit_price
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity numeric)
  join public.grocery_products product
    on product.id = input.product_id
   and product.store_id = p_store_id
   and product.is_active
  where input.quantity > 0
    and input.quantity <= product.available_quantity
    and mod(input.quantity, product.quantity_step) = 0;

  update public.grocery_products product
  set available_quantity = product.available_quantity - input.quantity,
      updated_at = now()
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity numeric)
  where product.id = input.product_id;

  return v_order_id;
end;
$$;

create or replace function public.place_pharmacy_order(
  p_customer_name text,
  p_phone_number text,
  p_city text,
  p_district text,
  p_address_line text,
  p_delivery_instructions text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_order_id uuid;
  v_input_count integer;
  v_valid_count integer;
  v_unique_count integer;
  v_subtotal integer;
  v_delivery_fee integer := 250;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'A pharmacy order requires at least one item';
  end if;
  if coalesce(trim(p_customer_name), '') = ''
     or coalesce(trim(p_phone_number), '') = ''
     or coalesce(trim(p_city), '') = ''
     or coalesce(trim(p_district), '') = ''
     or coalesce(trim(p_address_line), '') = '' then
    raise exception 'Complete pharmacy delivery details are required';
  end if;

  v_input_count := jsonb_array_length(p_items);

  perform 1
  from public.pharmacy_products product
  join jsonb_to_recordset(p_items)
    as input(product_id text, quantity integer)
    on product.id = input.product_id
  order by product.id
  for update of product;

  select
    count(*)::integer,
    count(distinct input.product_id)::integer,
    coalesce(sum(product.unit_price * input.quantity), 0)::integer
  into v_valid_count, v_unique_count, v_subtotal
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity integer)
  join public.pharmacy_products product
    on product.id = input.product_id
   and product.is_active
   and product.sale_type = 'otc'
  where input.quantity > 0
    and input.quantity <= product.stock_quantity;

  if v_valid_count <> v_input_count
     or v_unique_count <> v_input_count
     or v_subtotal <= 0 then
    raise exception 'Pharmacy order contains invalid or non-OTC items';
  end if;

  insert into public.pharmacy_orders (
    profile_id,
    customer_name,
    phone_number,
    city,
    district,
    address_line,
    delivery_instructions,
    subtotal,
    delivery_fee,
    total
  )
  values (
    v_profile_id,
    trim(p_customer_name),
    trim(p_phone_number),
    trim(p_city),
    trim(p_district),
    trim(p_address_line),
    coalesce(trim(p_delivery_instructions), ''),
    v_subtotal,
    v_delivery_fee,
    v_subtotal + v_delivery_fee
  )
  returning id into v_order_id;

  insert into public.pharmacy_order_items (
    order_id,
    product_id,
    product_name,
    quantity,
    unit_price
  )
  select
    v_order_id,
    product.id,
    product.name,
    input.quantity,
    product.unit_price
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity integer)
  join public.pharmacy_products product
    on product.id = input.product_id
   and product.is_active
   and product.sale_type = 'otc'
  where input.quantity > 0
    and input.quantity <= product.stock_quantity;

  update public.pharmacy_products product
  set stock_quantity = product.stock_quantity - input.quantity,
      updated_at = now()
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity integer)
  where product.id = input.product_id;

  return v_order_id;
end;
$$;
