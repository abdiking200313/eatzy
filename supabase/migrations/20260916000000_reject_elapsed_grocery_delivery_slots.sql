-- Issue #82 ("[Medium] place_grocery_order can commit orders whose delivery
-- window has already elapsed").
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- `place_grocery_order` derives the delivery window as
-- `(now() at time zone 'Africa/Mogadishu')::date + day_offset + start_time`,
-- using a `day_offset`/`start_time` pair stored per delivery-slot row
-- (`public.grocery_delivery_slots`). Nothing checked the computed window was
-- actually in the future -- the table-level
-- `check (delivery_window_start < delivery_window_end)` on `grocery_orders`
-- (added in `20260727152319_connect_super_app_services.sql`) does not catch
-- this either, since both timestamps can be equally in the past and still
-- satisfy `start < end`.
--
-- A customer ordering at 20:00 local and selecting a slot seeded as "today,
-- 14:00-16:00" got a committed order with a delivery window four hours in
-- the past. Separately, the Dart client fetched slots to display
-- (`SupabaseGroceryCatalogRepository.fetchDeliverySlots`, see
-- `lib/services/grocery/data/grocery_repository.dart`) queried
-- `public.grocery_delivery_slots` directly with only
-- `is_active`/RLS controlling visibility -- an elapsed-but-still-`is_active`
-- slot ("today, 14:00-16:00" seed row, browsed at 20:00) was still returned
-- and offered for selection, which is how a customer could pick it in the
-- first place.
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
--   1. Redefines `place_grocery_order` to `raise exception` when the
--      computed `v_delivery_window_start` is not strictly after `now()`,
--      immediately after the slot lookup and before any item validation,
--      stock locking, or insert -- so an elapsed slot is rejected before any
--      side effect, matching every other validation failure in this
--      function.
--   2. Adds `public.grocery_delivery_slots_available`, a `security_invoker`
--      view over `public.grocery_delivery_slots` that adds a `where` clause
--      excluding any slot whose computed delivery window has already
--      elapsed, using the exact same `day_offset`/`start_time` expression as
--      the RPC. `SupabaseGroceryCatalogRepository.fetchDeliverySlots` is
--      switched to query this view instead of the table directly, so an
--      elapsed slot is filtered out server-side rather than only being
--      caught if/when the customer tries to check out with it.
--
-- ---------------------------------------------------------------------
-- Judgment call: view vs. inline filter (see the issue's "What's needed")
-- ---------------------------------------------------------------------
--
-- `fetchDeliverySlots` is a plain client-side `select` on
-- `public.grocery_delivery_slots` -- there is no existing server-side
-- function or view already fetching slots for display that an inline
-- `where` could be dropped into. Per the issue's own guidance for that
-- shape ("adding a database view ... and pointing the Dart fetch at that
-- view"), a new view is the smallest correct fix here: it keeps the time
-- computation and its rollover behavior in exactly one further place
-- (alongside the RPC), rather than duplicating raw SQL/PostgREST filter
-- syntax for a timestamp arithmetic expression that isn't expressible as a
-- flat column comparison PostgREST's `.eq`/`.lt` filters could apply to the
-- base table. RLS on the base table already restricts to active,
-- active-store slots for `anon`/`authenticated` (see the "Public reads
-- active grocery slots" policy in `20260727152319_connect_super_app_services
-- .sql`); `security_invoker = true` (the same option already used by
-- `public.customer_activity`) makes the view enforce that same RLS for the
-- querying role rather than the view owner's, so this migration only needs
-- to add the new time condition on top of it. The view still repeats
-- `is_active` explicitly in its own `where` (redundant with RLS, but the
-- same defensive-duplication style `place_grocery_order` itself already
-- uses when it re-checks `is_active` inline despite RLS existing) so the
-- view stays independently correct even if RLS were ever misconfigured.
--
-- ---------------------------------------------------------------------
-- Judgment call: no further schema change for day_offset/start_time
-- ---------------------------------------------------------------------
--
-- The issue notes `day_offset` is stored per-slot and asks whether the
-- "Today"/"Tomorrow" label drift implies something persists a stale
-- absolute date. It does not: `day_offset`/`start_time`/`end_time` are a
-- fixed daily-recurring template (e.g. `day_offset = 0` always means
-- "today, relative to whenever this expression is evaluated"), and both the
-- RPC and the new view recompute
-- `(now() at time zone 'Africa/Mogadishu')::date + day_offset + start_time`
-- fresh on every call -- there is no persisted absolute timestamp column on
-- `grocery_delivery_slots` to go stale. This is why a same-request `where`/
-- `raise exception` time check is sufficient: once a `day_offset = 0` slot's
-- window elapses it is filtered out for the rest of that day, and it
-- becomes available again the next day purely because `now()::date` moved
-- forward, with no migration or cron needed to roll it over. What the issue
-- separately flags -- the `label` column itself (a static seeded string,
-- e.g. `'Today'`) not being recomputed -- is a *display text* accuracy
-- problem distinct from "is this slot's window still open", which is the
-- concrete defect this issue's "What's needed" section asks to fix; a
-- elapsed slot with a stale "Today" label is no longer offered at all once
-- filtered out by this migration, so the visible symptom the issue's "Why it
-- matters" section describes cannot recur, even though the label column's
-- own staleness (for a slot that is still within its window) is left as a
-- separate, smaller cosmetic concern the repository owner may want to file
-- if it matters in practice.
--
-- ---------------------------------------------------------------------
-- Overload safety (issue #136)
-- ---------------------------------------------------------------------
--
-- This migration does not change `place_grocery_order`'s parameter list or
-- return type -- only its body. The same overload-safety pattern
-- established in `20260915000000_add_service_pricing_config.sql` is still
-- followed exactly (drop the exact pre-existing signature, create the
-- replacement, then restate the revoke/grant pair) rather than relying on
-- `create or replace function`, so a future signature change to this same
-- function cannot land on top of an accidental leftover overload from this
-- one.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Per this repo's migration convention, a human with access to the Supabase
-- project must run `supabase db push` (or apply this file directly) after
-- reviewing it.
-- ---------------------------------------------------------------------

set search_path = '';

-- ---------------------------------------------------------------------
-- 1. public.grocery_delivery_slots_available: server-side filter for slot
--    display, excluding any slot whose computed delivery window has already
--    elapsed. RLS on the base table (unchanged) still restricts rows to
--    active slots at active stores for the querying role; this view only
--    adds the time condition on top of that.
-- ---------------------------------------------------------------------

create view public.grocery_delivery_slots_available
with (security_invoker = true)
as
select
  slot.id,
  slot.store_id,
  slot.label,
  slot.detail,
  slot.sort_order
from public.grocery_delivery_slots slot
where slot.is_active
  and (
    (now() at time zone 'Africa/Mogadishu')::date
      + slot.day_offset
      + slot.start_time
  ) at time zone 'Africa/Mogadishu' > now();

revoke all on public.grocery_delivery_slots_available
from public, anon, authenticated;
grant select on public.grocery_delivery_slots_available to anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. place_grocery_order: reject an elapsed delivery window before any
--    item validation, stock locking, or insert. Drop the exact
--    pre-existing signature first -- see the overload-safety note above.
-- ---------------------------------------------------------------------

drop function if exists public.place_grocery_order(
  text, text, text, text, text, text, text, text, jsonb, text
);

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

  -- Issue #82: reject a slot whose computed delivery window has already
  -- elapsed before any item validation, stock locking, or insert below.
  -- `grocery_delivery_slots_available` (above) filters the same condition
  -- out of what is offered for display, but this RPC re-checks it
  -- independently rather than trusting the client to only submit a slot it
  -- fetched from that view.
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

revoke all on function public.place_grocery_order(
  text, text, text, text, text, text, text, text, jsonb, text
)
from public, anon;

grant execute on function public.place_grocery_order(
  text, text, text, text, text, text, text, text, jsonb, text
)
to authenticated;
