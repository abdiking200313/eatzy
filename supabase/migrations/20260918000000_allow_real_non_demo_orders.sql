-- Allow real (non-demo) orders (issue #31).
--
-- ---------------------------------------------------------------------
-- The problem
-- ---------------------------------------------------------------------
--
-- `20260727152319_connect_super_app_services.sql` declared every order
-- table's demo flag as:
--
--     is_demo boolean not null default true check (is_demo)
--
-- A `check (is_demo)` on a `not null` column is only ever satisfied by
-- `true`. Combined with the `default true`, that made every row in
-- `food_orders` (:134), `grocery_orders` (:189) and `pharmacy_orders`
-- (:232) permanently and un-updatably a demo order: no insert could set
-- `is_demo = false`, and no later `update` could clear it either. The
-- schema structurally forbade a real order.
--
-- (The same migration declared it on `cleaning_bookings` at :279 too, but
-- that table no longer exists -- the cleaning vertical was removed whole in
-- issue #50, `20260815153920_remove_cleaning_vertical.sql`. Nothing here
-- references it; per AGENTS.md the vertical is not to be reintroduced.)
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
--   1. Drops the `check (is_demo)` constraint on each of the three order
--      tables, so `is_demo` can hold `false`.
--   2. Flips each column's default from `true` to `false`. Going forward,
--      the real app flow is the normal case, so an insert that does not
--      mention `is_demo` is a real order. Demo data is now the thing that
--      has to opt in explicitly.
--   3. Restates `place_food_order` / `place_grocery_order` /
--      `place_pharmacy_order` with `is_demo` written out as `false` in the
--      insert (see "Why the RPCs are restated" below).
--
-- The column itself stays -- `is_demo` is still a useful marker for seeded
-- demo activity, it just stops being a one-way door. Existing rows keep
-- whatever value they have (all `true`, since nothing else was possible);
-- this migration does not rewrite data.
--
-- ---------------------------------------------------------------------
-- Deliberately NOT changed: the currency / country CHECK constraints
-- ---------------------------------------------------------------------
--
-- Issue #31 also notes that these tables hard-pin
-- `currency text check (currency = 'USD')` and
-- `country text check (country = 'Somalia')`. Those are left exactly as
-- they are. Unlike `is_demo`, they are not self-contradictory -- they pin
-- a value the product actually operates with today, and every price in the
-- app is integer USD cents (issue #8) with Somalia-only delivery copy
-- throughout. Relaxing them would mean deciding which other
-- markets/currencies are supported and what happens to money handling,
-- rounding and display for them; there is no signal anywhere in this repo
-- about that, and it is a product decision, not a schema cleanup. When a
-- second market is actually planned, that gets its own migration and its
-- own issue.
--
-- ---------------------------------------------------------------------
-- Why the RPCs are restated (and why `create or replace`, not drop)
-- ---------------------------------------------------------------------
--
-- None of the three `place_*_order` RPCs ever mentioned `is_demo`: they
-- relied on the column default, which is why they produced demo rows in
-- the first place. Step 2 alone would therefore already be enough to make
-- app-placed orders real. They are restated anyway so the guarantee is
-- written at the point where an order is created rather than resting on a
-- default that a future migration could flip back by accident -- issue #31
-- explicitly asks for this to be a conscious decision, not an implicit one.
--
-- The argument lists are byte-for-byte identical to the ones created in
-- `20260917000000_add_shared_delivery_addresses.sql`; the only change to
-- each body is the two added lines in its `insert ... into public.*_orders`
-- (`is_demo` in the column list, `false` in the values list). Because the
-- signature does not change, `create or replace function` replaces each
-- function in place and *cannot* create the second overload that issue #136
-- was about -- and, unlike drop-then-create, it leaves the existing ACL
-- intact instead of resetting it to Postgres' PUBLIC EXECUTE default. The
-- revoke/grant pair is still restated at the bottom (idempotent) so the
-- intended ACL is asserted rather than assumed, and a guard at the very end
-- fails the migration loudly if more than one overload of any of the three
-- somehow exists afterwards.
--
-- ---------------------------------------------------------------------
-- Demo seeding is untouched
-- ---------------------------------------------------------------------
--
-- `supabase/seed.sql` (local/dev only, issue #35 -- never reached by
-- `supabase db push`) still creates its demo order history, and is updated
-- alongside this migration to pass `is_demo => true` explicitly on those
-- three inserts, since it can no longer lean on the default to mean "demo".
-- That file is not part of the migration chain and is not applied here.
--
-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
--
-- No policy is added, dropped or altered. No existing policy on
-- `food_orders` / `grocery_orders` / `pharmacy_orders` references
-- `is_demo`, so relaxing the constraint does not widen any policy's
-- predicate: the tables keep row-level security enabled and keep exactly
-- the owner/merchant policies they had before. The three RPCs remain
-- `security definer` with `set search_path = ''`, still resolve the caller
-- via `auth.uid()`, and are still executable only by `authenticated`.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Per this repo's migration convention, a human with access to the Supabase
-- project must run `supabase db push` (or apply this file directly) after
-- reviewing it. This sandbox has no way to run migrations against a real or
-- local Postgres, so the behavior below has only been reasoned through and
-- code-reviewed here -- verify it against a real/staging database before it
-- ships.
-- ---------------------------------------------------------------------

set search_path = '';

-- ---------------------------------------------------------------------
-- 1 + 2. Drop the `check (is_demo)` constraint and flip the default.
--
--    The constraints were declared inline and unnamed, so Postgres named
--    them (`food_orders_is_demo_check` and friends). Rather than trusting
--    that generated name, look each one up by what it actually is: a check
--    constraint whose only referenced column is `is_demo`. Same
--    discover-then-alter shape `20260827103100_restrict_order_profile_
--    deletes.sql` uses for the profile_id foreign keys.
-- ---------------------------------------------------------------------

do $$
declare
  target_table text;
  constraint_name text;
  dropped integer;
begin
  foreach target_table in array array[
    'food_orders',
    'grocery_orders',
    'pharmacy_orders'
  ]
  loop
    if to_regclass('public.' || target_table) is null then
      raise exception
        'Expected table public.% to exist, it does not', target_table;
    end if;

    dropped := 0;

    for constraint_name in
      select con.conname
      from pg_constraint con
      join pg_class rel on rel.oid = con.conrelid
      join pg_namespace nsp on nsp.oid = rel.relnamespace
      where nsp.nspname = 'public'
        and rel.relname = target_table
        and con.contype = 'c'
        and con.conkey = array[
          (
            select attnum
            from pg_attribute
            where attrelid = rel.oid
              and attname = 'is_demo'
              and not attisdropped
          )
        ]
    loop
      execute format(
        'alter table public.%I drop constraint %I',
        target_table,
        constraint_name
      );
      dropped := dropped + 1;
    end loop;

    if dropped = 0 then
      -- Already relaxed (e.g. this migration re-run against a database
      -- where it partially applied). Not an error, but say so.
      raise notice
        'No is_demo check constraint found on public.%, nothing to drop',
        target_table;
    end if;

    execute format(
      'alter table public.%I alter column is_demo set default false',
      target_table
    );
  end loop;
end
$$;

-- ---------------------------------------------------------------------
-- 3. Restate the three order RPCs so a real, app-placed order is written
--    as `is_demo = false` explicitly.
--
--    Bodies are carried over verbatim from
--    `20260917000000_add_shared_delivery_addresses.sql` -- same signatures,
--    same idempotency/advisory-lock handling (#59), same deterministic
--    `for update of product` stock locking (#76), same service_pricing-
--    driven fees and tax (#60), same saved-address resolution (#78), same
--    elapsed-delivery-slot rejection for grocery (#82). The only difference
--    is the `is_demo` / `false` pair added to each insert.
-- ---------------------------------------------------------------------

create or replace function public.place_food_order(
  p_restaurant_id uuid,
  p_recipient_name text,
  p_phone text,
  p_street text,
  p_district text,
  p_city text,
  p_items jsonb,
  p_idempotency_key text default null,
  p_delivery_address_id uuid default null
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
  v_recipient_name text;
  v_phone text;
  v_street text;
  v_district text;
  v_city text;
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

  -- Issue #78: a saved address (verified to belong to the caller) wins over
  -- the individual p_recipient_name/p_phone/p_street/p_district/p_city
  -- parameters when both are given. Ad-hoc entry (p_delivery_address_id
  -- null, the only path every caller uses today) is unaffected.
  if p_delivery_address_id is not null then
    select
      address.recipient_name,
      address.phone,
      address.street,
      address.district,
      address.city
    into v_recipient_name, v_phone, v_street, v_district, v_city
    from public.delivery_addresses address
    where address.id = p_delivery_address_id
      and address.profile_id = v_profile_id;

    if not found then
      raise exception 'Delivery address not found';
    end if;
  else
    v_recipient_name := p_recipient_name;
    v_phone := p_phone;
    v_street := p_street;
    v_district := p_district;
    v_city := p_city;
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
  if coalesce(trim(v_recipient_name), '') = ''
     or coalesce(trim(v_phone), '') = ''
     or coalesce(trim(v_street), '') = ''
     or coalesce(trim(v_district), '') = ''
     or coalesce(trim(v_city), '') = '' then
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
    delivery_address_id,
    subtotal,
    delivery_fee,
    tax,
    total,
    payment_method,
    payment_status,
    idempotency_key,
    is_demo
  )
  values (
    v_profile_id,
    p_restaurant_id,
    v_restaurant_name,
    trim(v_recipient_name),
    trim(v_phone),
    trim(v_street),
    trim(v_district),
    trim(v_city),
    p_delivery_address_id,
    v_subtotal,
    v_delivery_fee,
    v_tax,
    v_total,
    'cash_on_delivery',
    'pending_collection',
    p_idempotency_key,
    false
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

create or replace function public.place_grocery_order(
  p_store_id text,
  p_delivery_slot_id text,
  p_recipient_name text,
  p_phone text,
  p_street text,
  p_district text,
  p_city text,
  p_substitution_preference text,
  p_items jsonb,
  p_idempotency_key text default null,
  p_delivery_address_id uuid default null
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
  v_recipient_name text;
  v_phone text;
  v_street text;
  v_district text;
  v_city text;
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

  -- Issue #78: a saved address (verified to belong to the caller) wins over
  -- the individual p_recipient_name/p_phone/p_street/p_district/p_city
  -- parameters when both are given. Ad-hoc entry (p_delivery_address_id
  -- null, the only path every caller uses today) is unaffected.
  if p_delivery_address_id is not null then
    select
      address.recipient_name,
      address.phone,
      address.street,
      address.district,
      address.city
    into v_recipient_name, v_phone, v_street, v_district, v_city
    from public.delivery_addresses address
    where address.id = p_delivery_address_id
      and address.profile_id = v_profile_id;

    if not found then
      raise exception 'Delivery address not found';
    end if;
  else
    v_recipient_name := p_recipient_name;
    v_phone := p_phone;
    v_street := p_street;
    v_district := p_district;
    v_city := p_city;
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
  if coalesce(trim(v_recipient_name), '') = ''
     or coalesce(trim(v_phone), '') = ''
     or coalesce(trim(v_street), '') = ''
     or coalesce(trim(v_district), '') = ''
     or coalesce(trim(v_city), '') = '' then
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

  -- Issue #82: reject a slot whose computed delivery window has already
  -- elapsed before any item validation, stock locking, or insert below.
  -- `grocery_delivery_slots_available` filters the same condition out of
  -- what is offered for display, but this RPC re-checks it independently
  -- rather than trusting the client to only submit a slot it fetched from
  -- that view.
  if v_delivery_window_start <= now() then
    raise exception
      'The selected delivery window has already passed. Please choose '
      'another delivery slot.';
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
    delivery_address_id,
    substitution_preference,
    subtotal,
    delivery_fee,
    total,
    payment_method,
    payment_status,
    idempotency_key,
    is_demo
  )
  values (
    v_profile_id,
    p_store_id,
    v_store_name,
    p_delivery_slot_id,
    v_slot_label,
    v_delivery_window_start,
    v_delivery_window_end,
    trim(v_recipient_name),
    trim(v_phone),
    trim(v_street),
    trim(v_district),
    trim(v_city),
    p_delivery_address_id,
    p_substitution_preference,
    v_subtotal,
    v_delivery_fee,
    v_total,
    'cash_on_delivery',
    'pending_collection',
    p_idempotency_key,
    false
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

create or replace function public.place_pharmacy_order(
  p_recipient_name text,
  p_phone text,
  p_city text,
  p_district text,
  p_street text,
  p_delivery_instructions text,
  p_items jsonb,
  p_idempotency_key text default null,
  p_delivery_address_id uuid default null
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
  v_recipient_name text;
  v_phone text;
  v_street text;
  v_district text;
  v_city text;
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

  -- Issue #78: a saved address (verified to belong to the caller) wins over
  -- the individual p_recipient_name/p_phone/p_street/p_district/p_city
  -- parameters when both are given. Ad-hoc entry (p_delivery_address_id
  -- null, the only path every caller uses today) is unaffected.
  if p_delivery_address_id is not null then
    select
      address.recipient_name,
      address.phone,
      address.street,
      address.district,
      address.city
    into v_recipient_name, v_phone, v_street, v_district, v_city
    from public.delivery_addresses address
    where address.id = p_delivery_address_id
      and address.profile_id = v_profile_id;

    if not found then
      raise exception 'Delivery address not found';
    end if;
  else
    v_recipient_name := p_recipient_name;
    v_phone := p_phone;
    v_street := p_street;
    v_district := p_district;
    v_city := p_city;
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
  if coalesce(trim(v_recipient_name), '') = ''
     or coalesce(trim(v_phone), '') = ''
     or coalesce(trim(v_city), '') = ''
     or coalesce(trim(v_district), '') = ''
     or coalesce(trim(v_street), '') = '' then
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
    recipient_name,
    phone,
    city,
    district,
    street,
    delivery_instructions,
    delivery_address_id,
    subtotal,
    delivery_fee,
    total,
    payment_method,
    payment_status,
    idempotency_key,
    is_demo
  )
  values (
    v_profile_id,
    trim(v_recipient_name),
    trim(v_phone),
    trim(v_city),
    trim(v_district),
    trim(v_street),
    coalesce(trim(p_delivery_instructions), ''),
    p_delivery_address_id,
    v_subtotal,
    v_delivery_fee,
    v_total,
    'cash_on_delivery',
    'pending_collection',
    p_idempotency_key,
    false
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
-- 4. Restate the ACLs. `create or replace function` preserves the existing
--    grants, so this is a no-op assertion rather than a repair -- but it
--    keeps the intended ACL visible in the same file that touched the
--    functions, exactly as every prior migration in this chain does.
-- ---------------------------------------------------------------------

revoke all on function public.place_food_order(
  uuid, text, text, text, text, text, jsonb, text, uuid
)
from public, anon;
revoke all on function public.place_grocery_order(
  text, text, text, text, text, text, text, text, jsonb, text, uuid
)
from public, anon;
revoke all on function public.place_pharmacy_order(
  text, text, text, text, text, text, jsonb, text, uuid
)
from public, anon;

grant execute on function public.place_food_order(
  uuid, text, text, text, text, text, jsonb, text, uuid
)
to authenticated;
grant execute on function public.place_grocery_order(
  text, text, text, text, text, text, text, text, jsonb, text, uuid
)
to authenticated;
grant execute on function public.place_pharmacy_order(
  text, text, text, text, text, text, jsonb, text, uuid
)
to authenticated;

-- ---------------------------------------------------------------------
-- 5. Overload guard (issue #136). `create or replace function` with an
--    unchanged argument list cannot introduce an overload -- but if the
--    live database had drifted from this migration chain, it could have,
--    and a stray overload carries the default PUBLIC EXECUTE ACL the
--    revokes above would not have touched. Fail the migration instead of
--    shipping that.
-- ---------------------------------------------------------------------

do $$
declare
  target_function text;
  overloads integer;
begin
  foreach target_function in array array[
    'place_food_order',
    'place_grocery_order',
    'place_pharmacy_order'
  ]
  loop
    select count(*)
    into overloads
    from pg_proc proc
    join pg_namespace nsp on nsp.oid = proc.pronamespace
    where nsp.nspname = 'public'
      and proc.proname = target_function;

    if overloads <> 1 then
      raise exception
        'Expected exactly one public.% overload, found %',
        target_function,
        overloads;
    end if;
  end loop;
end
$$;
