-- Issue #131 (third child of the merchant self-service epic #128).
-- Builds on #129 (20260830120000_add_merchant_role_and_store_ownership.sql)
-- and #130 (20260830130000_add_merchant_catalog_write_policies.sql).
--
-- This also resolves the fulfilment-path portion of #79 ("order status can
-- never change today"): #79 asked to choose between a dashboard-only model, a
-- separate ops app, or in-app status-transition RPCs with a role check. #128
-- picked a variant of the third, and this migration implements it -- with the
-- store's own `owner_id` (not a separate operator role) as the operator
-- identity.
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- Every order row is created with status 'confirmed' by the place_*_order
-- RPCs and then can never change. `authenticated` holds SELECT and nothing
-- else on public.food_orders / public.grocery_orders / public.pharmacy_orders
-- (verified on a replayed migration chain, see "Verification" below), and none
-- of those tables carries a `for update` policy, so the status column is
-- effectively immutable outside the service role.
--
-- ---------------------------------------------------------------------
-- Assumptions (flagged on the issue -- correct either if wrong)
-- ---------------------------------------------------------------------
--
--   1. Audit shape: ONE shared public.order_status_events table discriminated
--      by a `vertical` column, rather than one audit table per vertical. The
--      order_id is therefore an unconstrained uuid (no single-target foreign
--      key fits three parent tables), the same pattern and reasoning already
--      used by public.wallet_transactions.order_id.
--   2. Customer-initiated cancellation is in scope, through its own narrowly
--      scoped RPC per vertical, allowed only from the initial 'confirmed'
--      state and only on the caller's own order.
--
-- ---------------------------------------------------------------------
-- Scope correction: three order tables, not four
-- ---------------------------------------------------------------------
--
-- Issue #131 says "the four order tables". Today there are three:
-- public.food_orders, public.grocery_orders, public.pharmacy_orders. The
-- fourth (public.cleaning_bookings) was dropped with the rest of the cleaning
-- vertical in 20260815153920_remove_cleaning_vertical.sql (issue #50), and
-- AGENTS.md forbids reintroducing a cleaning vertical without a fresh product
-- decision. This is the same three-not-four correction already recorded in
-- 20260827103100_restrict_order_profile_deletes.sql. So three
-- advance_*_order_status RPCs and three cancel_*_order RPCs, not four.
--
-- ---------------------------------------------------------------------
-- Status vocabularies (read off the live CHECK constraints, not invented)
-- ---------------------------------------------------------------------
--
--   food     : confirmed -> preparing -> out_for_delivery -> delivered
--   grocery  : confirmed -> shopping  -> out_for_delivery -> delivered
--   pharmacy : confirmed -> packing   -> out_for_delivery -> delivered
--
-- Each vertical may additionally go to 'cancelled' from either of its first
-- two states. 'delivered' and 'cancelled' are terminal: no transition leaves
-- them, and no step may be skipped. Because the legal-transition table lists
-- pairs explicitly, both rules fall out of it rather than needing separate
-- guards.
--
-- ---------------------------------------------------------------------
-- Pharmacy ownership: derived from the order's items
-- ---------------------------------------------------------------------
--
-- public.food_orders.restaurant_id and public.grocery_orders.store_id point
-- straight at an owned parent row. public.pharmacy_orders has NO store column
-- at all -- public.place_pharmacy_order builds a cart across the whole
-- pharmacy catalog, and the pharmacy store entity only arrived in #129. So
-- pharmacy ownership is derived through
-- public.pharmacy_order_items -> public.pharmacy_products.store_id ->
-- public.pharmacy_stores.owner_id, and the caller must own EVERY store the
-- order's items resolve to (and at least one). A cross-store pharmacy order
-- therefore cannot be advanced by anybody, which is the safe failure: giving
-- one of several stores unilateral control of a shared order would be worse.
-- Items whose product row has since been deleted (product_id is nullable, `on
-- delete set null`) are ignored rather than treated as foreign, so a merchant
-- deleting an old product does not strand their own order queue. Adding
-- public.pharmacy_orders.store_id and making the pharmacy cart single-store is
-- per-vertical order modelling -- issue #78 -- and is deliberately not done
-- here, because it would change customer checkout behaviour.
--
-- ---------------------------------------------------------------------
-- Deliberate deviation: changed_by references auth.users, not profiles
-- ---------------------------------------------------------------------
--
-- The issue text specifies `changed_by uuid references profiles(id)`. This
-- migration keeps the column name and type but points the foreign key at
-- auth.users(id) instead, because:
--   * nothing provisions a public.profiles row automatically (there is no
--     handle_new_user trigger anywhere in this repo, and
--     lib/features/profile/data/profile_repository.dart reads the row with
--     `maybeSingle()`, i.e. it tolerates a missing profile). A customer with
--     no profile row would hit a foreign key violation when cancelling their
--     own order -- an audit constraint breaking a legitimate user action.
--   * auth.users(id) is already this repo's reference for the actor on order
--     data: public.{food,grocery,pharmacy}_orders.profile_id all reference
--     auth.users(id) on delete restrict
--     (20260827103100_restrict_order_profile_deletes.sql).
-- public.profiles.id IS auth.users.id, so joining an event to a profile still
-- works; only the enforced target differs. `on delete restrict` matches the
-- order tables, so deleting a user cannot silently erase fulfilment history.
--
-- ---------------------------------------------------------------------
-- Why SECURITY DEFINER helpers instead of plain subqueries
-- ---------------------------------------------------------------------
--
-- A subquery inside an RLS policy is itself subject to RLS on the table it
-- reads. The only select policies on the order tables are "Customers read own
-- <x> orders", so a store owner reading public.order_status_events through a
-- plain `exists (select 1 from public.food_orders ...)` predicate would see
-- nothing. The ownership/visibility predicates are therefore SECURITY DEFINER
-- functions. They take no caller-supplied identity -- both derive the actor
-- from auth.uid() internally -- so they can only ever answer "is the caller
-- related to this order", never "who is".
--
-- Merchant-visible order *queues* (a select policy letting a store owner list
-- the orders themselves) are not added here; #131 covers the transition path
-- only. Until that lands, a merchant client drives these RPCs from order ids
-- it already holds.
--
-- ---------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------
--
-- Replayed supabase/schema.sql plus the full migration chain against a
-- throwaway local Postgres 16 database and exercised, as the `authenticated`
-- role with auth.uid() set per actor: a legal food/grocery/pharmacy sequence
-- through to 'delivered'; a foreign merchant rejected; a skipped step
-- rejected; a transition away from 'delivered' and from 'cancelled' rejected;
-- a customer cancelling their own 'confirmed' order; a customer rejected
-- cancelling somebody else's order and a non-'confirmed' order; and one
-- public.order_status_events row written per successful transition and none
-- per rejected one.
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Applying it is a deliberate manual follow-up (`supabase db push`) for a
-- human with access to the Supabase project, per this repo's migration
-- convention.
-- ---------------------------------------------------------------------

set search_path = '';

-- ---------------------------------------------------------------------
-- 1. The shared audit table
-- ---------------------------------------------------------------------

create table if not exists public.order_status_events (
  id uuid primary key default gen_random_uuid(),
  vertical text not null
    constraint order_status_events_vertical_check
    check (vertical in ('food', 'grocery', 'pharmacy')),
  order_id uuid not null,
  previous_status text not null,
  new_status text not null,
  changed_by uuid not null
    constraint order_status_events_changed_by_fkey
    references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

comment on table public.order_status_events is
  'Append-only audit of every order status transition across all verticals. Written only by the SECURITY DEFINER RPCs in this migration (issue #131); there is no client insert/update/delete path.';

comment on column public.order_status_events.order_id is
  'Unconstrained order reference. The referenced row lives in whichever of public.food_orders / public.grocery_orders / public.pharmacy_orders the vertical column names, so no single-target foreign key fits -- same pattern as public.wallet_transactions.order_id.';

comment on column public.order_status_events.changed_by is
  'The auth.users id that performed the transition, always derived from auth.uid() server-side. Deliberately references auth.users rather than public.profiles: profile rows are not auto-provisioned, and the order tables already reference auth.users for their actor column.';

create index if not exists order_status_events_order_idx
  on public.order_status_events (vertical, order_id, created_at desc);
create index if not exists order_status_events_changed_by_idx
  on public.order_status_events (changed_by);

-- ---------------------------------------------------------------------
-- 2. Shared predicates
-- ---------------------------------------------------------------------

-- The full legal-transition table for all three verticals. Every allowed
-- (vertical, from, to) triple is listed, so illegal jumps, backward steps and
-- any transition out of the terminal 'delivered'/'cancelled' states are all
-- rejected by omission.
create or replace function public.is_legal_order_status_transition(
  p_vertical text,
  p_previous_status text,
  p_new_status text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (p_vertical, p_previous_status, p_new_status) in (
    ('food', 'confirmed', 'preparing'),
    ('food', 'preparing', 'out_for_delivery'),
    ('food', 'out_for_delivery', 'delivered'),
    ('food', 'confirmed', 'cancelled'),
    ('food', 'preparing', 'cancelled'),
    ('grocery', 'confirmed', 'shopping'),
    ('grocery', 'shopping', 'out_for_delivery'),
    ('grocery', 'out_for_delivery', 'delivered'),
    ('grocery', 'confirmed', 'cancelled'),
    ('grocery', 'shopping', 'cancelled'),
    ('pharmacy', 'confirmed', 'packing'),
    ('pharmacy', 'packing', 'out_for_delivery'),
    ('pharmacy', 'out_for_delivery', 'delivered'),
    ('pharmacy', 'confirmed', 'cancelled'),
    ('pharmacy', 'packing', 'cancelled')
  );
$$;

comment on function public.is_legal_order_status_transition(text, text, text) is
  'True when moving an order of the given vertical from one status to another is a legal forward step. Issue #131.';

-- "Does the current caller own the store this order belongs to?" SECURITY
-- DEFINER so it can see the order row regardless of the customer-scoped RLS on
-- the order tables. Never takes an identity argument.
create or replace function public.merchant_owns_order(
  p_vertical text,
  p_order_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_owns boolean := false;
begin
  if v_actor is null or p_order_id is null then
    return false;
  end if;

  if p_vertical = 'food' then
    select exists (
      select 1
      from public.food_orders orders
      join public.restaurants restaurant
        on restaurant.id = orders.restaurant_id
      where orders.id = p_order_id
        and restaurant.owner_id = v_actor
    )
    into v_owns;
  elsif p_vertical = 'grocery' then
    select exists (
      select 1
      from public.grocery_orders orders
      join public.grocery_stores store
        on store.id = orders.store_id
      where orders.id = p_order_id
        and store.owner_id = v_actor
    )
    into v_owns;
  elsif p_vertical = 'pharmacy' then
    -- No store column on public.pharmacy_orders (see the header): the caller
    -- must own every pharmacy the order's still-resolvable items came from,
    -- and at least one item must resolve.
    select exists (
      select 1
      from public.pharmacy_order_items item
      join public.pharmacy_products product
        on product.id = item.product_id
      join public.pharmacy_stores store
        on store.id = product.store_id
      where item.order_id = p_order_id
        and store.owner_id = v_actor
    )
    and not exists (
      select 1
      from public.pharmacy_order_items item
      join public.pharmacy_products product
        on product.id = item.product_id
      join public.pharmacy_stores store
        on store.id = product.store_id
      where item.order_id = p_order_id
        and store.owner_id is distinct from v_actor
    )
    into v_owns;
  else
    return false;
  end if;

  return coalesce(v_owns, false);
end;
$$;

comment on function public.merchant_owns_order(text, uuid) is
  'True when auth.uid() owns the restaurant/store the given order belongs to. SECURITY DEFINER because the order tables are RLS-scoped to the customer; derives the actor from auth.uid() and never from an argument. Issue #131.';

-- Read predicate for public.order_status_events: the customer who placed the
-- order, or the merchant who fulfils it.
create or replace function public.can_read_order_status_event(
  p_vertical text,
  p_order_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_is_customer boolean := false;
begin
  if v_actor is null or p_order_id is null then
    return false;
  end if;

  if p_vertical = 'food' then
    select exists (
      select 1 from public.food_orders orders
      where orders.id = p_order_id and orders.profile_id = v_actor
    ) into v_is_customer;
  elsif p_vertical = 'grocery' then
    select exists (
      select 1 from public.grocery_orders orders
      where orders.id = p_order_id and orders.profile_id = v_actor
    ) into v_is_customer;
  elsif p_vertical = 'pharmacy' then
    select exists (
      select 1 from public.pharmacy_orders orders
      where orders.id = p_order_id and orders.profile_id = v_actor
    ) into v_is_customer;
  else
    return false;
  end if;

  return coalesce(v_is_customer, false)
    or public.merchant_owns_order(p_vertical, p_order_id);
end;
$$;

comment on function public.can_read_order_status_event(text, uuid) is
  'True when auth.uid() is either the customer on the given order or the owner of the store fulfilling it. Backs the public.order_status_events select policy. Issue #131.';

-- ---------------------------------------------------------------------
-- 3. RLS for public.order_status_events
-- ---------------------------------------------------------------------
--
-- Select only. There is deliberately no insert/update/delete policy: the
-- SECURITY DEFINER RPCs below run as the table owner and so bypass RLS, which
-- makes them the only write path and keeps the audit trail append-only from
-- every client's point of view.

alter table public.order_status_events enable row level security;

drop policy if exists "Order parties read status events"
  on public.order_status_events;
create policy "Order parties read status events"
on public.order_status_events for select
to authenticated
using (
  public.can_read_order_status_event(
    order_status_events.vertical,
    order_status_events.order_id
  )
);

revoke all on public.order_status_events from anon, authenticated;
grant select on public.order_status_events to authenticated;

-- ---------------------------------------------------------------------
-- 4. Merchant transition RPCs
-- ---------------------------------------------------------------------

create or replace function public.advance_food_order_status(
  p_order_id uuid,
  p_new_status text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_previous_status text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  select orders.status
  into v_previous_status
  from public.food_orders orders
  where orders.id = p_order_id
  for update;

  if v_previous_status is null then
    raise exception 'Food order not found';
  end if;
  if not public.merchant_owns_order('food', p_order_id) then
    raise exception 'You do not manage this food order';
  end if;
  if not public.is_legal_order_status_transition(
    'food',
    v_previous_status,
    p_new_status
  ) then
    raise exception 'Illegal food order status transition: % -> %',
      v_previous_status, p_new_status;
  end if;

  update public.food_orders
  set status = p_new_status
  where id = p_order_id;

  insert into public.order_status_events (
    vertical,
    order_id,
    previous_status,
    new_status,
    changed_by
  )
  values ('food', p_order_id, v_previous_status, p_new_status, v_actor);

  return p_new_status;
end;
$$;

create or replace function public.advance_grocery_order_status(
  p_order_id uuid,
  p_new_status text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_previous_status text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  select orders.status
  into v_previous_status
  from public.grocery_orders orders
  where orders.id = p_order_id
  for update;

  if v_previous_status is null then
    raise exception 'Grocery order not found';
  end if;
  if not public.merchant_owns_order('grocery', p_order_id) then
    raise exception 'You do not manage this grocery order';
  end if;
  if not public.is_legal_order_status_transition(
    'grocery',
    v_previous_status,
    p_new_status
  ) then
    raise exception 'Illegal grocery order status transition: % -> %',
      v_previous_status, p_new_status;
  end if;

  update public.grocery_orders
  set status = p_new_status
  where id = p_order_id;

  insert into public.order_status_events (
    vertical,
    order_id,
    previous_status,
    new_status,
    changed_by
  )
  values ('grocery', p_order_id, v_previous_status, p_new_status, v_actor);

  return p_new_status;
end;
$$;

create or replace function public.advance_pharmacy_order_status(
  p_order_id uuid,
  p_new_status text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_previous_status text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  select orders.status
  into v_previous_status
  from public.pharmacy_orders orders
  where orders.id = p_order_id
  for update;

  if v_previous_status is null then
    raise exception 'Pharmacy order not found';
  end if;
  if not public.merchant_owns_order('pharmacy', p_order_id) then
    raise exception 'You do not manage this pharmacy order';
  end if;
  if not public.is_legal_order_status_transition(
    'pharmacy',
    v_previous_status,
    p_new_status
  ) then
    raise exception 'Illegal pharmacy order status transition: % -> %',
      v_previous_status, p_new_status;
  end if;

  update public.pharmacy_orders
  set status = p_new_status
  where id = p_order_id;

  insert into public.order_status_events (
    vertical,
    order_id,
    previous_status,
    new_status,
    changed_by
  )
  values ('pharmacy', p_order_id, v_previous_status, p_new_status, v_actor);

  return p_new_status;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. Customer cancellation RPCs
-- ---------------------------------------------------------------------
--
-- Deliberately separate from the merchant RPCs and far narrower: the caller's
-- own order only, from the initial 'confirmed' state only, to 'cancelled'
-- only. There is no status argument, so there is nothing to widen. The
-- ownership predicate is on profile_id, not on store ownership.

create or replace function public.cancel_food_order(p_order_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_previous_status text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  select orders.status
  into v_previous_status
  from public.food_orders orders
  where orders.id = p_order_id
    and orders.profile_id = v_actor
  for update;

  if v_previous_status is null then
    raise exception 'Food order not found';
  end if;
  if v_previous_status <> 'confirmed' then
    raise exception
      'A food order can only be cancelled while it is still confirmed (it is %)',
      v_previous_status;
  end if;

  update public.food_orders
  set status = 'cancelled'
  where id = p_order_id;

  insert into public.order_status_events (
    vertical,
    order_id,
    previous_status,
    new_status,
    changed_by
  )
  values ('food', p_order_id, v_previous_status, 'cancelled', v_actor);

  return 'cancelled';
end;
$$;

create or replace function public.cancel_grocery_order(p_order_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_previous_status text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  select orders.status
  into v_previous_status
  from public.grocery_orders orders
  where orders.id = p_order_id
    and orders.profile_id = v_actor
  for update;

  if v_previous_status is null then
    raise exception 'Grocery order not found';
  end if;
  if v_previous_status <> 'confirmed' then
    raise exception
      'A grocery order can only be cancelled while it is still confirmed (it is %)',
      v_previous_status;
  end if;

  update public.grocery_orders
  set status = 'cancelled'
  where id = p_order_id;

  insert into public.order_status_events (
    vertical,
    order_id,
    previous_status,
    new_status,
    changed_by
  )
  values ('grocery', p_order_id, v_previous_status, 'cancelled', v_actor);

  return 'cancelled';
end;
$$;

create or replace function public.cancel_pharmacy_order(p_order_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_previous_status text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  select orders.status
  into v_previous_status
  from public.pharmacy_orders orders
  where orders.id = p_order_id
    and orders.profile_id = v_actor
  for update;

  if v_previous_status is null then
    raise exception 'Pharmacy order not found';
  end if;
  if v_previous_status <> 'confirmed' then
    raise exception
      'A pharmacy order can only be cancelled while it is still confirmed (it is %)',
      v_previous_status;
  end if;

  update public.pharmacy_orders
  set status = 'cancelled'
  where id = p_order_id;

  insert into public.order_status_events (
    vertical,
    order_id,
    previous_status,
    new_status,
    changed_by
  )
  values ('pharmacy', p_order_id, v_previous_status, 'cancelled', v_actor);

  return 'cancelled';
end;
$$;

-- ---------------------------------------------------------------------
-- 6. Function grants
-- ---------------------------------------------------------------------
--
-- Same shape as the place_*_order grants in
-- 20260727152319_connect_super_app_services.sql: revoke from public and anon
-- first (a newly created function is executable by PUBLIC by default), then
-- grant execute to `authenticated` only.
--
-- public.merchant_owns_order and public.is_legal_order_status_transition are
-- internal and are NOT granted to any client role. The RPCs above are SECURITY
-- DEFINER, so their internal calls are checked against the function owner, not
-- the caller. public.can_read_order_status_event IS granted, because an RLS
-- policy predicate is evaluated with the querying role's privileges.

revoke all on function public.is_legal_order_status_transition(text, text, text)
from public, anon, authenticated;
revoke all on function public.merchant_owns_order(text, uuid)
from public, anon, authenticated;
revoke all on function public.can_read_order_status_event(text, uuid)
from public, anon;
grant execute on function public.can_read_order_status_event(text, uuid)
to authenticated;

revoke all on function public.advance_food_order_status(uuid, text)
from public, anon;
revoke all on function public.advance_grocery_order_status(uuid, text)
from public, anon;
revoke all on function public.advance_pharmacy_order_status(uuid, text)
from public, anon;
revoke all on function public.cancel_food_order(uuid) from public, anon;
revoke all on function public.cancel_grocery_order(uuid) from public, anon;
revoke all on function public.cancel_pharmacy_order(uuid) from public, anon;

grant execute on function public.advance_food_order_status(uuid, text)
to authenticated;
grant execute on function public.advance_grocery_order_status(uuid, text)
to authenticated;
grant execute on function public.advance_pharmacy_order_status(uuid, text)
to authenticated;
grant execute on function public.cancel_food_order(uuid) to authenticated;
grant execute on function public.cancel_grocery_order(uuid) to authenticated;
grant execute on function public.cancel_pharmacy_order(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 7. Keep the RPCs the only write path onto the order tables
-- ---------------------------------------------------------------------
--
-- On the replayed migration chain `authenticated` already holds SELECT and
-- nothing else here (20260727152319 does `revoke all ... grant select`), and
-- no order table has an update policy, so this is defence in depth rather than
-- a fix. It is still stated explicitly because Supabase's default privileges
-- grant new public tables broadly, and because a future migration adding an
-- update policy should have to also re-grant the privilege deliberately.

revoke insert, update, delete, truncate on
  public.food_orders,
  public.food_order_items,
  public.grocery_orders,
  public.grocery_order_items,
  public.pharmacy_orders,
  public.pharmacy_order_items
from anon, authenticated;

reset search_path;
