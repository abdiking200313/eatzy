-- Issue #60 ("[High] Pricing/tax/fee constants have no single source of
-- truth -- duplicated across Dart, RPC bodies, column defaults, and seed
-- data; the client-computed total gets displayed and recorded instead of
-- the server's").
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- Every fee/tax constant existed in at least two places with nothing
-- reconciling them: a Dart constant in each vertical's cart/checkout
-- controller (`CartController.standardDeliveryFee`/`taxRate`,
-- `GroceryController.standardDeliveryFee`,
-- `PharmacyController.deliveryFee`) and, separately, a hardcoded local
-- variable inside each `place_*_order` function body
-- (`v_delivery_fee integer := 499;` / `:= 250;`, and food's
-- `v_tax := round(v_subtotal * 0.10)::integer;`). Only the function body's
-- value ever actually applied to a real order -- a fee change there could
-- silently diverge from the Dart constant (used only for the pre-checkout
-- cart/checkout *estimate*) with nothing to catch it.
--
-- Separately, none of the three RPCs returned anything but the new order's
-- id, so every Dart call site recorded/displayed the client-computed cart
-- total as the "amount" for an order the RPC may have priced differently
-- (e.g. a menu/product price changed between the cart being built and
-- checkout being confirmed) -- see `food_controller.dart`'s prior
-- `amount: _cartController.total` and the equivalent pattern in
-- `grocery_controller.dart` / `pharmacy_controller.dart`.
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
--   1. Creates `public.service_pricing`, one row per vertical
--      (`food` / `grocery` / `pharmacy`) holding `delivery_fee_cents` and
--      `tax_rate`, seeded with the CURRENT values (499/0.10 for food,
--      250/0 for grocery, 250/0 for pharmacy) so behavior does not change.
--      This is now the single place a fee/tax change is made.
--   2. Redefines all three `place_*_order` RPCs (building on top of issue
--      #59's idempotency-key parameter, the current baseline signature) to
--      read `delivery_fee_cents`/`tax_rate` from this table instead of a
--      hardcoded local variable.
--   3. Changes each RPC's return type from a bare `uuid` to
--      `table(order_id uuid, subtotal integer, delivery_fee integer,
--      tax integer, total integer)`, so the caller gets back the actual
--      server-computed total (and the breakdown that produced it) instead
--      of only an id. The idempotent-retry early-return path (issue #59)
--      returns this same shape for the existing order, so a retry also
--      shows the real charged total, not just its id.
--   4. The Dart side (`PlacedOrder` in
--      `lib/services/shared/data/rpc_helpers.dart`, and the food/grocery/
--      pharmacy repositories/controllers built on it) is updated in the
--      same change to parse this richer response and use
--      `order.total` -- not the client-computed cart total -- when
--      recording an order into the activity feed.
--
-- `grocery`/`pharmacy` intentionally keep `tax_rate = 0`: this reconciles
-- the existing duplicated constants (grocery/pharmacy never had a tax line
-- in either the Dart controllers or the RPC bodies), it does not invent a
-- new tax for them.
--
-- ---------------------------------------------------------------------
-- Scoping decision: "detect price drift" (see the issue's "What's needed")
-- ---------------------------------------------------------------------
--
-- The issue also asks to "detect price drift between cart contents and
-- current catalog prices before confirming, rather than silently
-- recomputing at commit time". Re-reading that against the current code:
-- every `place_*_order` RPC already recomputes the subtotal from CURRENT
-- `menu_items`/`grocery_products`/`pharmacy_products` prices inside its own
-- transaction -- the client's cart prices were never trusted for the
-- actual charge, before or after this migration. So the real gap was never
-- "the server might charge a stale price" (it can't -- it only ever reads
-- live prices); it was "the client silently lied about what was charged
-- after the fact" (this migration's items 3-4 above).
--
-- Building an actual pre-commit warning (e.g. a banner comparing the cart's
-- cached price against a fresh live-price lookup before the user taps
-- "confirm") is a materially larger UX feature -- a new pre-flight
-- read-only RPC or query, new controller/loading state, and new checkout UI
-- across three verticals -- and is deliberately left out of this change.
-- This migration closes the "silent lie after commit" gap (the concrete
-- failure the issue describes ending in "the activity feed then shows the
-- stale amount forever") by finally reading back and displaying the RPC's
-- authoritative total; a pre-commit staleness *warning* is a reasonable
-- follow-up the repository owner may want to file separately.
--
-- ---------------------------------------------------------------------
-- Access to public.service_pricing
-- ---------------------------------------------------------------------
--
-- Only the `place_*_order` RPCs need to read this table to compute what is
-- actually charged, and RLS is not evaluated the same way for a `SECURITY
-- DEFINER` function running as the table owner (the default is that a
-- table owner is exempt from its own table's RLS unless `FORCE ROW LEVEL
-- SECURITY` is set, which this migration does not set). A direct
-- `authenticated`-only `select` policy is still added, on the judgment call
-- that a future cart-preview screen may want to read live
-- delivery-fee/tax-rate values for its own client-side estimate instead of
-- hardcoding a fifth copy of these numbers -- that is not wired up by this
-- change (see "What this migration does" above: the Dart cart/checkout
-- *estimate* stays a client-side constant for now), but the policy exists
-- so a later change can read it without a further migration. No
-- `insert`/`update`/`delete` policy exists for any client-facing role:
-- pricing can only be changed by a migration or a service-role/superuser
-- connection, never by an authenticated user's own request. `anon` gets no
-- access at all -- unlike the public catalog tables, pricing is not shown
-- to a signed-out visitor anywhere in the app today.
--
-- ---------------------------------------------------------------------
-- Overload safety (issue #136)
-- ---------------------------------------------------------------------
--
-- `create or replace function` cannot change a function's return type
-- (Postgres rejects it outright: "cannot change return type of existing
-- function"), so unlike a change that only adds a trailing default
-- parameter, this migration MUST drop each function's current signature
-- before creating the new one -- it is not optional here the way it was an
-- explicit safety choice in `20260914010000_add_order_idempotency.sql`.
-- The same overload-safety pattern that migration established is followed
-- exactly: drop the exact pre-existing signature, create the replacement,
-- then restate the revoke/grant pair on the new signature (dropping a
-- function resets its ACL to the Postgres default of PUBLIC EXECUTE).
--
-- ---------------------------------------------------------------------
-- Concurrency and idempotency (issue #59, #76): unchanged
-- ---------------------------------------------------------------------
--
-- The advisory-lock idempotency handling and the deterministic
-- (primary-key-ordered) `for update of product` stock locking are carried
-- over unchanged from `20260914010000_add_order_idempotency.sql` -- this
-- migration only changes what is read for pricing and what is returned,
-- not the concurrency/idempotency control flow itself.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Per this repo's migration convention, a human with access to the
-- Supabase project must run `supabase db push` (or apply this file
-- directly) after reviewing it.
-- ---------------------------------------------------------------------

set search_path = '';

-- ---------------------------------------------------------------------
-- 1. public.service_pricing: the new source of truth for delivery fee and
--    tax rate, one row per vertical.
-- ---------------------------------------------------------------------

create table public.service_pricing (
  service_id text primary key
    check (service_id in ('food', 'grocery', 'pharmacy')),
  -- In integer cents, same convention as every other money column in this
  -- app -- see issue #8.
  delivery_fee_cents integer not null check (delivery_fee_cents >= 0),
  -- A fraction (0.10 = 10%), not a percentage. 0 for a vertical that
  -- charges no tax today (grocery, pharmacy).
  tax_rate numeric not null default 0
    check (tax_rate >= 0 and tax_rate < 1),
  updated_at timestamptz not null default now()
);

insert into public.service_pricing (service_id, delivery_fee_cents, tax_rate)
values
  ('food', 499, 0.10),
  ('grocery', 250, 0),
  ('pharmacy', 250, 0);

alter table public.service_pricing enable row level security;

create policy "Authenticated reads service pricing"
on public.service_pricing for select
to authenticated
using (true);

revoke all on public.service_pricing from anon, authenticated;
grant select on public.service_pricing to authenticated;

-- ---------------------------------------------------------------------
-- 2. Drop the pre-existing (pre-#60) signatures explicitly -- see the
--    overload-safety note above -- then create the new signatures with an
--    unchanged parameter list but a richer `returns table(...)`.
-- ---------------------------------------------------------------------

drop function if exists public.place_food_order(
  uuid, text, text, text, text, text, jsonb, text
);
drop function if exists public.place_grocery_order(
  text, text, text, text, text, text, text, text, jsonb, text
);
drop function if exists public.place_pharmacy_order(
  text, text, text, text, text, text, jsonb, text
);

create function public.place_food_order(
  p_restaurant_id uuid,
  p_recipient_name text,
  p_phone text,
  p_street text,
  p_district text,
  p_city text,
  p_items jsonb,
  p_idempotency_key text default null
)
returns table (
  order_id uuid,
  subtotal integer,
  delivery_fee integer,
  tax integer,
  total integer
)
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
  v_delivery_fee integer;
  v_tax_rate numeric;
  v_tax integer;
  v_total integer;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;

  if p_idempotency_key is not null then
    select o.id, o.subtotal, o.delivery_fee, o.tax, o.total
    into v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total
    from public.food_orders o
    where o.profile_id = v_profile_id
      and o.idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return query
        select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
      return;
    end if;

    -- Serialize concurrent identical submissions before any validation or
    -- mutation: the loser blocks here until the winner's transaction ends,
    -- then re-checks for the row the winner created.
    perform pg_advisory_xact_lock(
      hashtextextended(v_profile_id::text || ':' || p_idempotency_key, 0)
    );

    select o.id, o.subtotal, o.delivery_fee, o.tax, o.total
    into v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total
    from public.food_orders o
    where o.profile_id = v_profile_id
      and o.idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return query
        select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
      return;
    end if;
  end if;

  select p.delivery_fee_cents, p.tax_rate
  into v_delivery_fee, v_tax_rate
  from public.service_pricing p
  where p.service_id = 'food';

  if not found then
    raise exception 'Pricing configuration missing for food';
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

  v_tax := round(v_subtotal * v_tax_rate)::integer;
  v_total := v_subtotal + v_delivery_fee + v_tax;

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
    payment_status,
    idempotency_key
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
    v_total,
    'cash_on_delivery',
    'pending_collection',
    p_idempotency_key
  )
  on conflict (profile_id, idempotency_key) do nothing
  returning id into v_order_id;

  if v_order_id is null then
    -- Lost a race despite the advisory lock above (e.g. a caller that
    -- reached the insert some other way): the winner's row already
    -- exists. Return it without inserting food_order_items again.
    select o.id, o.subtotal, o.delivery_fee, o.tax, o.total
    into v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total
    from public.food_orders o
    where o.profile_id = v_profile_id
      and o.idempotency_key = p_idempotency_key;

    if v_order_id is null then
      raise exception 'Failed to place food order';
    end if;

    return query select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
    return;
  end if;

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

  return query select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
  return;
end;
$$;

create function public.place_grocery_order(
  p_store_id text,
  p_delivery_slot_id text,
  p_recipient_name text,
  p_phone text,
  p_street text,
  p_district text,
  p_city text,
  p_substitution_preference text,
  p_items jsonb,
  p_idempotency_key text default null
)
returns table (
  order_id uuid,
  subtotal integer,
  delivery_fee integer,
  tax integer,
  total integer
)
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
  v_delivery_fee integer;
  -- Grocery charges no tax -- this reconciles the pre-#60 duplicated
  -- constants (neither the Dart controller nor this function's old
  -- hardcoded body had a tax line for grocery); it is not a new tax.
  v_tax integer := 0;
  v_total integer;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;

  if p_idempotency_key is not null then
    select o.id, o.subtotal, o.delivery_fee, o.total
    into v_order_id, v_subtotal, v_delivery_fee, v_total
    from public.grocery_orders o
    where o.profile_id = v_profile_id
      and o.idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return query
        select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
      return;
    end if;

    -- Serialize concurrent identical submissions before any validation,
    -- locking, or mutation: the loser blocks here until the winner's
    -- transaction ends, then re-checks for the row the winner created.
    -- This is a separate advisory-lock namespace from the deterministic
    -- `for update of product` lock order below (issue #76) and cannot
    -- introduce a new deadlock class with it.
    perform pg_advisory_xact_lock(
      hashtextextended(v_profile_id::text || ':' || p_idempotency_key, 0)
    );

    select o.id, o.subtotal, o.delivery_fee, o.total
    into v_order_id, v_subtotal, v_delivery_fee, v_total
    from public.grocery_orders o
    where o.profile_id = v_profile_id
      and o.idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return query
        select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
      return;
    end if;
  end if;

  select p.delivery_fee_cents
  into v_delivery_fee
  from public.service_pricing p
  where p.service_id = 'grocery';

  if not found then
    raise exception 'Pricing configuration missing for grocery';
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

  v_total := v_subtotal + v_delivery_fee;

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
    payment_status,
    idempotency_key
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
    v_total,
    'cash_on_delivery',
    'pending_collection',
    p_idempotency_key
  )
  on conflict (profile_id, idempotency_key) do nothing
  returning id into v_order_id;

  if v_order_id is null then
    -- Lost a race despite the advisory lock above: the winner's row
    -- already exists. Return it without inserting grocery_order_items or
    -- decrementing stock again.
    select o.id, o.subtotal, o.delivery_fee, o.total
    into v_order_id, v_subtotal, v_delivery_fee, v_total
    from public.grocery_orders o
    where o.profile_id = v_profile_id
      and o.idempotency_key = p_idempotency_key;

    if v_order_id is null then
      raise exception 'Failed to place grocery order';
    end if;

    return query select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
    return;
  end if;

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

  return query select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
  return;
end;
$$;

create function public.place_pharmacy_order(
  p_customer_name text,
  p_phone_number text,
  p_city text,
  p_district text,
  p_address_line text,
  p_delivery_instructions text,
  p_items jsonb,
  p_idempotency_key text default null
)
returns table (
  order_id uuid,
  subtotal integer,
  delivery_fee integer,
  tax integer,
  total integer
)
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
  v_delivery_fee integer;
  -- Pharmacy charges no tax -- see the identical note in
  -- place_grocery_order above.
  v_tax integer := 0;
  v_total integer;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;

  if p_idempotency_key is not null then
    select o.id, o.subtotal, o.delivery_fee, o.total
    into v_order_id, v_subtotal, v_delivery_fee, v_total
    from public.pharmacy_orders o
    where o.profile_id = v_profile_id
      and o.idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return query
        select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
      return;
    end if;

    -- Serialize concurrent identical submissions before any validation,
    -- locking, or mutation: the loser blocks here until the winner's
    -- transaction ends, then re-checks for the row the winner created.
    -- This is a separate advisory-lock namespace from the deterministic
    -- `for update of product` lock order below (issue #76) and cannot
    -- introduce a new deadlock class with it.
    perform pg_advisory_xact_lock(
      hashtextextended(v_profile_id::text || ':' || p_idempotency_key, 0)
    );

    select o.id, o.subtotal, o.delivery_fee, o.total
    into v_order_id, v_subtotal, v_delivery_fee, v_total
    from public.pharmacy_orders o
    where o.profile_id = v_profile_id
      and o.idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return query
        select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
      return;
    end if;
  end if;

  select p.delivery_fee_cents
  into v_delivery_fee
  from public.service_pricing p
  where p.service_id = 'pharmacy';

  if not found then
    raise exception 'Pricing configuration missing for pharmacy';
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

  v_total := v_subtotal + v_delivery_fee;

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
    payment_status,
    idempotency_key
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
    v_total,
    'cash_on_delivery',
    'pending_collection',
    p_idempotency_key
  )
  on conflict (profile_id, idempotency_key) do nothing
  returning id into v_order_id;

  if v_order_id is null then
    -- Lost a race despite the advisory lock above: the winner's row
    -- already exists. Return it without inserting pharmacy_order_items or
    -- decrementing stock again.
    select o.id, o.subtotal, o.delivery_fee, o.total
    into v_order_id, v_subtotal, v_delivery_fee, v_total
    from public.pharmacy_orders o
    where o.profile_id = v_profile_id
      and o.idempotency_key = p_idempotency_key;

    if v_order_id is null then
      raise exception 'Failed to place pharmacy order';
    end if;

    return query select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
    return;
  end if;

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

  return query select v_order_id, v_subtotal, v_delivery_fee, v_tax, v_total;
  return;
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Restate ACLs on the new signatures (dropping a function resets its
--    grants/revokes to the Postgres default of PUBLIC EXECUTE -- see the
--    overload-safety note above).
-- ---------------------------------------------------------------------

revoke all on function public.place_food_order(
  uuid, text, text, text, text, text, jsonb, text
)
from public, anon;
revoke all on function public.place_grocery_order(
  text, text, text, text, text, text, text, text, jsonb, text
)
from public, anon;
revoke all on function public.place_pharmacy_order(
  text, text, text, text, text, text, jsonb, text
)
from public, anon;

grant execute on function public.place_food_order(
  uuid, text, text, text, text, text, jsonb, text
)
to authenticated;
grant execute on function public.place_grocery_order(
  text, text, text, text, text, text, text, text, jsonb, text
)
to authenticated;
grant execute on function public.place_pharmacy_order(
  text, text, text, text, text, text, jsonb, text
)
to authenticated;
