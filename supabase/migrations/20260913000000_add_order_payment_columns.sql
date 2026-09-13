-- Issue #30 ("[Blocking] No payment processing exists anywhere in any
-- checkout flow"). Owner's decision, quoted verbatim on the issue:
--
--   "Decision: cash-on-delivery only for launch. No payment processor
--   integration for now.
--
--   Please still: add a payment_method/payment_status column to each order
--   table (even if the only value today is cash_on_delivery /
--   pending_collection) so the schema doesn't need another migration when a
--   real processor is added later. Update the place_*_order RPCs and
--   checkout screens accordingly."
--
-- ---------------------------------------------------------------------
-- Which tables
-- ---------------------------------------------------------------------
--
-- public.food_orders, public.grocery_orders, public.pharmacy_orders are the
-- only order tables today -- the same "three, not four" scope already
-- recorded by 20260827103100_restrict_order_profile_deletes.sql and
-- 20260830140000_add_order_status_transition_rpcs.sql: the cleaning
-- vertical's public.cleaning_bookings was dropped whole in
-- 20260815153920_remove_cleaning_vertical.sql (issue #50), and AGENTS.md
-- forbids reintroducing it without a fresh product decision.
--
-- ---------------------------------------------------------------------
-- Enum choices (deliberately minimal -- launch scaffolding, not a full
-- payment state machine; nothing calls anything but each column's default
-- today)
-- ---------------------------------------------------------------------
--
--   payment_method: 'cash_on_delivery' only. That is the one option this
--     issue ships; a real processor later adds card/wallet/etc. values to
--     this check constraint without needing to *add* the column itself.
--   payment_status: 'pending_collection' (the default every order is created
--     with), 'collected' (the courier/store collected the cash -- reserved
--     for the fulfilment-status work in issue #131/#79, no RPC sets this
--     yet), 'refunded' (an order was cancelled/refunded after collection --
--     also reserved, no caller yet). Kept to these three rather than also
--     inventing e.g. authorized/disputed/partially_refunded, which only make
--     sense once a real processor exists and have no code path today.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Per this repo's migration convention, a human with access to the Supabase
-- project must run `supabase db push` (or apply this file directly) after
-- reviewing it.

alter table public.food_orders
  add column payment_method text not null default 'cash_on_delivery'
    check (payment_method in ('cash_on_delivery')),
  add column payment_status text not null default 'pending_collection'
    check (payment_status in ('pending_collection', 'collected', 'refunded'));

alter table public.grocery_orders
  add column payment_method text not null default 'cash_on_delivery'
    check (payment_method in ('cash_on_delivery')),
  add column payment_status text not null default 'pending_collection'
    check (payment_status in ('pending_collection', 'collected', 'refunded'));

alter table public.pharmacy_orders
  add column payment_method text not null default 'cash_on_delivery'
    check (payment_method in ('cash_on_delivery')),
  add column payment_status text not null default 'pending_collection'
    check (payment_status in ('pending_collection', 'collected', 'refunded'));

-- ---------------------------------------------------------------------
-- Expose the new columns through public.customer_activity, so
-- TrackOrderScreen (the one real per-order details screen -- see
-- lib/features/orders/presentation/track_order_screen.dart) can show a real
-- payment line instead of nothing.
--
-- `create or replace view` can append new trailing output columns without
-- dropping the view, since no existing column's name, type or position
-- changes -- unlike 20260903000000_convert_money_columns_to_cents.sql, which
-- had to drop and recreate because it changed existing columns' types. So
-- the view keeps its grants and this does not need to restate them.
-- ---------------------------------------------------------------------

create or replace view public.customer_activity
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
  '/food'::text as details_route,
  orders.payment_method,
  orders.payment_status
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
  '/grocery'::text as details_route,
  orders.payment_method,
  orders.payment_status
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
  '/pharmacy'::text as details_route,
  orders.payment_method,
  orders.payment_status
from public.pharmacy_orders orders;

-- ---------------------------------------------------------------------
-- place_food_order / place_grocery_order / place_pharmacy_order: set the new
-- columns explicitly on insert rather than leaning on the column defaults
-- alone. This makes the (currently fixed) payment method a first-class part
-- of what each RPC writes, so a future real processor can turn
-- 'cash_on_delivery' into a real parameter without restructuring the insert.
--
-- Signatures are unchanged from their current definitions in
-- 20260903000000_convert_money_columns_to_cents.sql, so `create or replace
-- function` keeps the existing revoke/grant ACL -- it is not restated here.
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
    total,
    payment_method,
    payment_status
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
    v_subtotal + v_delivery_fee + v_tax,
    'cash_on_delivery',
    'pending_collection'
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
    total,
    payment_method,
    payment_status
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
    v_subtotal + v_delivery_fee,
    'cash_on_delivery',
    'pending_collection'
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
    total,
    payment_method,
    payment_status
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
    v_subtotal + v_delivery_fee,
    'cash_on_delivery',
    'pending_collection'
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
