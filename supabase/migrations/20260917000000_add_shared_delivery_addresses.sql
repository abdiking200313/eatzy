-- Issue #78 ("Every vertical models delivery address and order differently
-- at the schema level -- no shared platform layer for the data AGENTS.md
-- says should be shared").
--
-- ---------------------------------------------------------------------
-- Problem (re-verified against the current tip, 2026-09-17 -- the issue was
-- filed 2026-08-15, before food had address columns and before the cleaning
-- vertical was removed)
-- ---------------------------------------------------------------------
--
-- AGENTS.md lists addresses as a shared-platform capability, but there is no
-- `delivery_addresses` table anywhere in this migration chain, and each
-- vertical's order table still snapshots its own fulfilment details
-- independently:
--   - food_orders / grocery_orders already use the SAME baseline shape
--     (recipient_name, phone, street, district, city) -- grocery from the
--     original schema, food added by issue #2's
--     20260826200000_add_food_order_delivery_address.sql.
--   - pharmacy_orders is the outlier: customer_name, phone_number,
--     city, district, address_line (plus delivery_instructions, a
--     pharmacy-specific extra that stays).
--
-- Owner's decision on the issue thread (final -- see the issue body):
--   1. Shape: a shared `delivery_addresses` table, referenced by FK from
--      each vertical's order table, PLUS the mandated common baseline
--      column set (recipient_name/phone/street/district/city) food and
--      grocery already use. NOT a full `orders` supertype rewrite.
--   2. Pharmacy is renamed to match that baseline:
--      customer_name -> recipient_name, phone_number -> phone,
--      address_line -> street. `city`/`district`/`delivery_instructions`
--      are unchanged (already correctly named / an allowed pharmacy-specific
--      extra).
--   3. Clean-break rewrite: no real orders exist yet (demo/seed data only),
--      so columns are renamed directly rather than added-then-backfilled.
--
-- ---------------------------------------------------------------------
-- Current RPC state this migration builds on (verified against the tip of
-- origin/master, not assumed from any single prior file)
-- ---------------------------------------------------------------------
--
-- Three migrations changed place_food_order / place_grocery_order /
-- place_pharmacy_order very recently, each layering on the last:
--   - 20260914010000_add_order_idempotency.sql (issue #59): added a trailing
--     `p_idempotency_key text default null` parameter to all three.
--   - 20260915000000_add_service_pricing_config.sql (issue #60): changed the
--     return type of all three from bare `uuid` to
--     `table(order_id uuid, subtotal integer, delivery_fee integer,
--     tax integer, total integer)`; introduced `public.service_pricing`.
--   - 20260916000000_reject_elapsed_grocery_delivery_slots.sql (issue #82,
--     grocery only): added an elapsed-delivery-slot check to
--     place_grocery_order's body; its parameter list and return type are
--     unchanged from #60.
--
-- So the authoritative current signatures this migration drops-and-replaces
-- are:
--   place_food_order(uuid, text, text, text, text, text, jsonb, text)
--   place_grocery_order(text, text, text, text, text, text, text, text,
--                        jsonb, text)
--   place_pharmacy_order(text, text, text, text, text, text, jsonb, text)
-- all returning `table(order_id uuid, subtotal integer, delivery_fee
-- integer, tax integer, total integer)`.
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
--   1. Creates `public.delivery_addresses`, one row per saved address, owned
--      by a profile, RLS-scoped to its owner for select/insert/update/
--      delete.
--   2. Renames pharmacy_orders' address columns to the mandated baseline
--      (customer_name -> recipient_name, phone_number -> phone,
--      address_line -> street) via a direct `rename column` -- no real rows
--      exist yet, so no backfill/compat window is needed (owner's decision
--      #3 above).
--   3. Adds a nullable `delivery_address_id uuid references
--      public.delivery_addresses(id) on delete set null` to food_orders,
--      grocery_orders and pharmacy_orders. Nullable because an ad-hoc,
--      not-saved-to-the-address-book checkout must keep working exactly as
--      today.
--   4. Redefines all three place_*_order RPCs (same drop-then-recreate-
--      plus-restate-ACL pattern already established by #59/#60/#82, see
--      "Overload safety" below) to accept a new, trailing
--      `p_delivery_address_id uuid default null` parameter. When provided,
--      the function looks up that delivery_addresses row, verifies it
--      belongs to the caller (`profile_id = v_profile_id`) -- raising an
--      exception otherwise, so one user's checkout can never reference
--      another user's saved address -- and uses ITS
--      recipient_name/phone/street/district/city for the order snapshot
--      INSTEAD OF the individual p_recipient_name/p_phone/... parameters.
--      Those individual parameters are kept (not removed), so ad-hoc address
--      entry keeps working unchanged. If both are given, the saved address
--      wins (see the "saved address wins" comment inside each function
--      body). This is purely additive: a caller that never passes the new
--      parameter (every caller today) is completely unaffected -- same
--      inputs in, same behavior, same row shape out.
--   5. Renames pharmacy's RPC parameters to match: p_customer_name ->
--      p_recipient_name, p_phone_number -> p_phone, p_address_line ->
--      p_street -- the same names food/grocery's RPCs already use for the
--      equivalent parameter, which is the actual point of this issue
--      (finally-consistent naming across all three).
--   6. Updates `public.customer_activity`'s pharmacy branch to read
--      `orders.recipient_name` instead of the now-renamed
--      `orders.customer_name`. The view's own output column list, order and
--      types are unchanged (still `... subtitle ...` at the same position),
--      so `create or replace view` is sufficient here -- no drop needed, and
--      existing grants on the view are undisturbed.
--
-- ---------------------------------------------------------------------
-- Judgment call: where p_delivery_address_id is resolved inside each
-- function body
-- ---------------------------------------------------------------------
--
-- Resolution happens immediately after the idempotency early-return checks
-- (issue #59) and before the "complete delivery details are required"
-- validation: an idempotent retry never needs to re-resolve an address (it
-- returns the already-placed order), so putting the lookup after those
-- checks avoids doing address-book work on a call that is about to
-- short-circuit anyway. The resolved values are held in new
-- v_recipient_name / v_phone / v_street / v_district / v_city locals, which
-- the rest of each function (blank-field validation, the insert) reads
-- instead of the raw p_* parameters -- so the "saved address wins" rule
-- above is enforced in exactly one place per function.
--
-- ---------------------------------------------------------------------
-- Overload safety (issue #136)
-- ---------------------------------------------------------------------
--
-- Same reasoning as every prior migration in this chain that changed one of
-- these three functions' argument lists: `create or replace function`
-- cannot change a function's argument list (adding a new parameter, even
-- with a default, changes the argument type list), so it would silently
-- create a SECOND overload alongside the existing one -- with the old,
-- default (PUBLIC EXECUTE) ACL -- rather than replacing it. That is exactly
-- the production outage issue #136 describes. To avoid it, this migration
-- explicitly drops each function's current (pre-#78) signature before
-- creating the new one, and restates the revoke/grant pair on the new
-- signature.
--
-- ---------------------------------------------------------------------
-- Concurrency, idempotency, pricing, elapsed-slot rejection: unchanged
-- ---------------------------------------------------------------------
--
-- The advisory-lock idempotency handling (#59), the deterministic
-- (primary-key-ordered) `for update of product` stock locking (#76), the
-- service_pricing-driven fee/tax computation (#60), and grocery's elapsed-
-- delivery-slot rejection (#82) are all carried over unchanged -- this
-- migration only adds the address-resolution step described above on top of
-- them.
--
-- ---------------------------------------------------------------------
-- Client-side scope note
-- ---------------------------------------------------------------------
--
-- Nothing calls `p_delivery_address_id` with a non-null value yet: wiring a
-- "select a saved address" UI into the food/grocery/pharmacy checkout
-- screens, and building the real CRUD UI for `lib/screens/addresses.dart`
-- (today hardcoded demo data with a non-functional "Add New Address"
-- button), are both deliberately out of scope for this issue and are left as
-- fast-follows -- see the PR description. This migration's own deliverable
-- is the schema/platform layer: the table, the FK columns, and the RPC
-- parameter existing, additive and backward compatible.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Per this repo's migration convention, a human with access to the Supabase
-- project must run `supabase db push` (or apply this file directly) after
-- reviewing it. The rename/FK/RLS behavior has only been reasoned through
-- and code-reviewed here -- this sandbox has no way to run migrations
-- against a real or local Postgres -- so verify it against a real/staging
-- database before this ships.
-- ---------------------------------------------------------------------

set search_path = '';

-- ---------------------------------------------------------------------
-- 1. public.delivery_addresses: the shared platform table.
-- ---------------------------------------------------------------------

create table public.delivery_addresses (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references auth.users(id) on delete cascade,
  -- e.g. "Home" / "Work" -- matches the existing hardcoded UI's concept
  -- (lib/screens/addresses.dart). Nullable: a saved address is not required
  -- to have a label.
  label text,
  recipient_name text not null,
  phone text not null,
  street text not null,
  district text not null,
  city text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index delivery_addresses_profile_id_idx
  on public.delivery_addresses(profile_id);

alter table public.delivery_addresses enable row level security;

create policy "Owners read own delivery addresses"
on public.delivery_addresses for select
to authenticated
using (profile_id = (select auth.uid()));

create policy "Owners create own delivery addresses"
on public.delivery_addresses for insert
to authenticated
with check (profile_id = (select auth.uid()));

create policy "Owners update own delivery addresses"
on public.delivery_addresses for update
to authenticated
using (profile_id = (select auth.uid()))
with check (profile_id = (select auth.uid()));

create policy "Owners delete own delivery addresses"
on public.delivery_addresses for delete
to authenticated
using (profile_id = (select auth.uid()));

-- Issue #83's shared `updated_at` trigger convention
-- (20260827100000_add_updated_at_triggers.sql) -- this table declares
-- `updated_at` like every order/catalog table, so it gets the same trigger
-- rather than joining the list of tables that silently never maintain it.
drop trigger if exists set_delivery_addresses_updated_at
  on public.delivery_addresses;
create trigger set_delivery_addresses_updated_at
before update on public.delivery_addresses
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 2. Rename pharmacy_orders' address columns to the mandated baseline.
--    Direct rename -- no real rows exist yet (owner's decision #3).
-- ---------------------------------------------------------------------

alter table public.pharmacy_orders rename column customer_name to recipient_name;
alter table public.pharmacy_orders rename column phone_number to phone;
alter table public.pharmacy_orders rename column address_line to street;

-- ---------------------------------------------------------------------
-- 3. Nullable delivery_address_id FK on every order table.
-- ---------------------------------------------------------------------

alter table public.food_orders
  add column delivery_address_id uuid
    references public.delivery_addresses(id) on delete set null;
create index food_orders_delivery_address_idx
  on public.food_orders(delivery_address_id);

alter table public.grocery_orders
  add column delivery_address_id uuid
    references public.delivery_addresses(id) on delete set null;
create index grocery_orders_delivery_address_idx
  on public.grocery_orders(delivery_address_id);

alter table public.pharmacy_orders
  add column delivery_address_id uuid
    references public.delivery_addresses(id) on delete set null;
create index pharmacy_orders_delivery_address_idx
  on public.pharmacy_orders(delivery_address_id);

-- ---------------------------------------------------------------------
-- 4. public.customer_activity: point the pharmacy branch's subtitle at the
--    renamed column. Output column list/order/types are unchanged, so
--    `create or replace view` is sufficient (no drop, no grant restatement
--    needed) -- same reasoning as 20260913000000_add_order_payment_columns
--    .sql used when it only appended trailing columns.
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
  orders.recipient_name || ' • Somalia' as subtitle,
  orders.status,
  orders.created_at as occurred_at,
  orders.total as amount,
  '/pharmacy'::text as details_route,
  orders.payment_method,
  orders.payment_status
from public.pharmacy_orders orders;

-- ---------------------------------------------------------------------
-- 5. Drop the exact pre-#78 signatures (see "Overload safety" above), then
--    create the new signatures with a trailing p_delivery_address_id
--    parameter -- and, for pharmacy, the renamed p_recipient_name/p_phone/
--    p_street parameters.
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
    idempotency_key
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
    idempotency_key
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
-- 6. Restate ACLs on the new signatures (dropping a function resets its
--    grants/revokes to the Postgres default of PUBLIC EXECUTE -- see the
--    overload-safety note above).
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
