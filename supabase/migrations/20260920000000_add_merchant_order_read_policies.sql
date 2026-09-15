-- Issue #134 (sixth/final child of the merchant self-service epic #128):
-- the merchant app's incoming-order queue and fulfillment screens.
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- #131 (20260830140000_add_order_status_transition_rpcs.sql) deliberately
-- shipped no merchant-visible order queue: its header says outright
-- "Merchant-visible order *queues* (a select policy letting a store owner
-- list the orders themselves) are not added here; #131 covers the
-- transition path only. Until that lands, a merchant client drives these
-- RPCs from order ids it already holds." That gap is exactly what blocks
-- #134's "Orders" screen: today `public.food_orders` /
-- `public.grocery_orders` / `public.pharmacy_orders` (and their `_items`
-- tables) carry only a "Customers read own ... orders" select policy scoped
-- to `profile_id = auth.uid()`. A merchant querying any of these tables for
-- their own store's orders gets zero rows back, so #134's acceptance
-- criterion ("a merchant sees only orders belonging to their own store(s)")
-- cannot be met by the client alone -- it has to be enforced here, in RLS.
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
-- Adds one additional, purely additive select policy per order table and
-- per its `_items` table, scoped through `public.merchant_owns_order`
-- (`vertical`, `order_id`) -- the exact SECURITY DEFINER predicate #131
-- already wrote, comments, and exercised for the status-transition RPCs.
-- It is reused verbatim rather than reimplemented, so the "does this
-- merchant own this order" rule stays defined in exactly one place:
--   - food:     public.food_orders.restaurant_id -> restaurants.owner_id
--   - grocery:  public.grocery_orders.store_id -> grocery_stores.owner_id
--   - pharmacy: no store column on pharmacy_orders (unchanged since #131 --
--     see that migration's header); ownership is derived through
--     pharmacy_order_items -> pharmacy_products.store_id ->
--     pharmacy_stores.owner_id, requiring the caller to own every store the
--     order's still-resolvable items came from.
--
-- `public.merchant_owns_order` was deliberately NOT granted to any client
-- role in #131 ("is internal and NOT granted to any client role"), because
-- nothing needed to call it directly at the time. This migration grants
-- `execute` on it to `authenticated` so a select policy can invoke it --
-- the same reasoning #131 used to grant `can_read_order_status_event`
-- instead of leaving it ungranted: "an RLS policy predicate is evaluated
-- with the querying role's privileges", not the privileges of whatever
-- SECURITY DEFINER function it is nested inside.
--
-- Nothing else changes. The existing customer-facing select policies, the
-- write-side merchant RPCs, and every other grant/policy on these tables
-- are untouched -- RLS combines multiple permissive select policies with
-- OR, so a customer keeps seeing their own orders and a merchant
-- additionally sees their store's orders; neither can see the other's.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Applying it is a deliberate manual follow-up (`supabase db push`) for a
-- human with access to the Supabase project, per this repo's migration
-- convention. Verified by reading `public.merchant_owns_order`'s existing
-- definition directly in
-- `supabase/migrations/20260830140000_add_order_status_transition_rpcs.sql`
-- rather than re-deriving it, and reasoning through the policy the same way
-- #131 did; this sandbox has no way to run migrations against a live
-- Postgres instance.
-- ---------------------------------------------------------------------

set search_path = '';

-- ---------------------------------------------------------------------
-- 1. Let a select policy call the existing ownership predicate.
-- ---------------------------------------------------------------------

grant execute on function public.merchant_owns_order(text, uuid)
to authenticated;

-- ---------------------------------------------------------------------
-- 2. Merchant read policies, one pair per vertical.
-- ---------------------------------------------------------------------

drop policy if exists "Merchants read own food orders" on public.food_orders;
create policy "Merchants read own food orders"
on public.food_orders for select
to authenticated
using (public.merchant_owns_order('food', food_orders.id));

drop policy if exists "Merchants read own food order items"
  on public.food_order_items;
create policy "Merchants read own food order items"
on public.food_order_items for select
to authenticated
using (public.merchant_owns_order('food', food_order_items.order_id));

drop policy if exists "Merchants read own grocery orders"
  on public.grocery_orders;
create policy "Merchants read own grocery orders"
on public.grocery_orders for select
to authenticated
using (public.merchant_owns_order('grocery', grocery_orders.id));

drop policy if exists "Merchants read own grocery order items"
  on public.grocery_order_items;
create policy "Merchants read own grocery order items"
on public.grocery_order_items for select
to authenticated
using (
  public.merchant_owns_order('grocery', grocery_order_items.order_id)
);

drop policy if exists "Merchants read own pharmacy orders"
  on public.pharmacy_orders;
create policy "Merchants read own pharmacy orders"
on public.pharmacy_orders for select
to authenticated
using (public.merchant_owns_order('pharmacy', pharmacy_orders.id));

drop policy if exists "Merchants read own pharmacy order items"
  on public.pharmacy_order_items;
create policy "Merchants read own pharmacy order items"
on public.pharmacy_order_items for select
to authenticated
using (
  public.merchant_owns_order('pharmacy', pharmacy_order_items.order_id)
);

reset search_path;
