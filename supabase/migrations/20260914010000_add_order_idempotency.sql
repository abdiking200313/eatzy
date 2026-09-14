-- Issue #59 ("[High] Checkout has no idempotency at any layer -- a
-- double-tap or retried request creates duplicate orders and
-- double-decrements stock").
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- None of place_food_order, place_grocery_order, place_pharmacy_order
-- accepted a client-generated idempotency token, and no order table had a
-- unique constraint that would collapse a repeat submission -- every order
-- id is a fresh server-side gen_random_uuid(). Combined with the client
-- clearing its cart only *after* the RPC returns (fixed alongside this
-- migration on the Dart side with an `_isSubmitting`-equivalent guard on
-- each checkout controller), a double-tap or a retried request on a slow
-- connection could create two orders -- and for grocery/pharmacy,
-- decrement stock twice for real.
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
--   1. Adds a nullable `idempotency_key text` column to `food_orders`,
--      `grocery_orders`, `pharmacy_orders`, each with a
--      `unique (profile_id, idempotency_key)` constraint. Nullable so
--      existing rows (and any future caller that omits the new RPC
--      parameter) are unaffected -- Postgres unique constraints never
--      consider two NULLs equal, so any number of NULL-key rows coexist
--      per profile without conflict.
--   2. Redefines all three place_*_order RPCs to accept a new, final
--      `p_idempotency_key text default null` parameter. Passing the same
--      key for the same profile on a repeat submission returns the
--      existing order's id instead of inserting a duplicate row or
--      re-running the stock decrement.
--
-- ---------------------------------------------------------------------
-- Overload safety (issue #136)
-- ---------------------------------------------------------------------
--
-- issue #136 was a real production outage: `create or replace function`
-- cannot change a function's argument list -- adding a new parameter,
-- even with a default, changes the argument type list, so `create or
-- replace function` would silently create a SECOND overload alongside the
-- existing one (with the old, default ACL) rather than replacing it,
-- exactly like the resurrected 2-arg place_food_order overload #136
-- describes. To avoid that, this migration explicitly drops each
-- function's current (pre-idempotency) signature before creating the new
-- one, and restates the revoke/grant pair on the new signature -- dropping
-- and recreating a function resets its ACL to the Postgres default (PUBLIC
-- EXECUTE), which is itself part of what made #136 a privilege problem,
-- not only a resolution problem.
--
-- ---------------------------------------------------------------------
-- Concurrency: composing with the deterministic lock order (issue #76)
-- ---------------------------------------------------------------------
--
-- grocery/pharmacy already lock product rows in deterministic (primary
-- key) order before validating stock and decrementing it (see
-- 20260827101327_deterministic_lock_order_grocery_pharmacy.sql) to avoid
-- an AB/BA deadlock between two unrelated concurrent checkouts. That
-- ordering is untouched here.
--
-- Idempotency handling is layered in front of it, in two parts:
--
--   a. An early lookup, immediately after the auth check and before any
--      validation: if a `food_orders`/`grocery_orders`/`pharmacy_orders`
--      row already exists for (profile_id, p_idempotency_key), its id is
--      returned immediately. This matters for correctness, not just
--      performance -- re-running stock validation on a retry would check
--      *already-decremented* stock and could wrongly reject a legitimate
--      retry of an order that in fact already succeeded.
--   b. Two requests carrying the same (profile_id, p_idempotency_key) that
--      race past step (a) simultaneously (neither sees the other's row
--      yet) are serialized with `pg_advisory_xact_lock`, keyed on a hash
--      of profile_id and the idempotency key -- a lock namespace entirely
--      separate from the row-level `for update` locks used for stock, so
--      it cannot introduce a new deadlock class with that existing
--      ordering. The loser blocks until the winner's transaction commits
--      or rolls back, then re-checks for an existing order before
--      proceeding, so at most one of the two ever reaches validation and
--      insert.
--   c. As a final belt-and-braces guard against any gap between (a)/(b)
--      and the insert, the insert itself is
--      `on conflict (profile_id, idempotency_key) do nothing returning
--      id`; if it reports no row (lost a race despite (b), or a caller
--      that skipped the lock path some other way), a lookup returns the
--      winner's id and the item-insert/stock-decrement that would
--      otherwise follow is skipped -- so stock is only ever decremented
--      once per idempotency key.
--
-- When p_idempotency_key is null (a caller that does not yet pass one),
-- none of this triggers: (a) and (b) are skipped outright, and the insert
-- never conflicts (NULL is never equal to NULL), so behavior for such a
-- caller is unchanged from before this migration.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Per this repo's migration convention, a human with access to the
-- Supabase project must run `supabase db push` (or apply this file
-- directly) after reviewing it. In particular, the conflict/race-handling
-- logic above has only been reasoned through and code-reviewed here --
-- this sandbox has no way to run migrations against a real or local
-- Postgres, so it has not been exercised against actual concurrent
-- transactions. Verify the conflict path (two identical submissions, and
-- a genuine concurrent race) against a real/staging database before this
-- ships.
-- ---------------------------------------------------------------------

set search_path = '';

-- ---------------------------------------------------------------------
-- 1. Idempotency key columns + per-profile unique constraints
-- ---------------------------------------------------------------------

alter table public.food_orders
  add column idempotency_key text,
  add constraint food_orders_profile_idempotency_key_key
    unique (profile_id, idempotency_key);

alter table public.grocery_orders
  add column idempotency_key text,
  add constraint grocery_orders_profile_idempotency_key_key
    unique (profile_id, idempotency_key);

alter table public.pharmacy_orders
  add column idempotency_key text,
  add constraint pharmacy_orders_profile_idempotency_key_key
    unique (profile_id, idempotency_key);

-- ---------------------------------------------------------------------
-- 2. Drop the pre-idempotency signatures explicitly (issue #136 safety --
--    see comment above), then create the new signatures.
-- ---------------------------------------------------------------------

drop function if exists public.place_food_order(
  uuid, text, text, text, text, text, jsonb
);
drop function if exists public.place_grocery_order(
  text, text, text, text, text, text, text, text, jsonb
);
drop function if exists public.place_pharmacy_order(
  text, text, text, text, text, text, jsonb
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

  if p_idempotency_key is not null then
    select id into v_order_id
    from public.food_orders
    where profile_id = v_profile_id
      and idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return v_order_id;
    end if;

    -- Serialize concurrent identical submissions before any validation or
    -- mutation: the loser blocks here until the winner's transaction ends,
    -- then re-checks for the row the winner created.
    perform pg_advisory_xact_lock(
      hashtextextended(v_profile_id::text || ':' || p_idempotency_key, 0)
    );

    select id into v_order_id
    from public.food_orders
    where profile_id = v_profile_id
      and idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return v_order_id;
    end if;
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
    v_subtotal + v_delivery_fee + v_tax,
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
    select id into v_order_id
    from public.food_orders
    where profile_id = v_profile_id
      and idempotency_key = p_idempotency_key;

    if v_order_id is null then
      raise exception 'Failed to place food order';
    end if;

    return v_order_id;
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

  return v_order_id;
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

  if p_idempotency_key is not null then
    select id into v_order_id
    from public.grocery_orders
    where profile_id = v_profile_id
      and idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return v_order_id;
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

    select id into v_order_id
    from public.grocery_orders
    where profile_id = v_profile_id
      and idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return v_order_id;
    end if;
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
    v_subtotal + v_delivery_fee,
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
    select id into v_order_id
    from public.grocery_orders
    where profile_id = v_profile_id
      and idempotency_key = p_idempotency_key;

    if v_order_id is null then
      raise exception 'Failed to place grocery order';
    end if;

    return v_order_id;
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

  return v_order_id;
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

  if p_idempotency_key is not null then
    select id into v_order_id
    from public.pharmacy_orders
    where profile_id = v_profile_id
      and idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return v_order_id;
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

    select id into v_order_id
    from public.pharmacy_orders
    where profile_id = v_profile_id
      and idempotency_key = p_idempotency_key;

    if v_order_id is not null then
      return v_order_id;
    end if;
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
    v_subtotal + v_delivery_fee,
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
    select id into v_order_id
    from public.pharmacy_orders
    where profile_id = v_profile_id
      and idempotency_key = p_idempotency_key;

    if v_order_id is null then
      raise exception 'Failed to place pharmacy order';
    end if;

    return v_order_id;
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

  return v_order_id;
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
