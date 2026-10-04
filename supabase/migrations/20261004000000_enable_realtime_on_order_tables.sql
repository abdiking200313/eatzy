-- Issue #297: live order tracking without pull-to-refresh.
--
-- ---------------------------------------------------------------------
-- Problem
-- ---------------------------------------------------------------------
--
-- The track-order screen reads public.customer_activity (via
-- lib/platform/activity/data/activity_repository.dart), so it only sees a
-- status change when the user pulls to refresh. customer_activity is a
-- security_invoker VIEW over public.food_orders, public.grocery_orders and
-- public.pharmacy_orders (last redefined in
-- 20260917000000_add_shared_delivery_addresses.sql). Supabase Realtime
-- `postgres_changes` reads the logical-replication stream, which carries
-- only base-table changes, so a view cannot be subscribed to. The client has
-- to subscribe to the underlying per-vertical order table instead, filtered
-- by the order's id (`id=eq.<order id>`), and none of those tables is in the
-- supabase_realtime publication today (nothing in supabase/ references it).
--
-- ---------------------------------------------------------------------
-- Which tables, and why not public.order_status_events
-- ---------------------------------------------------------------------
--
-- Added: public.food_orders, public.grocery_orders, public.pharmacy_orders.
-- An UPDATE event on the order row carries the new `status` (and
-- `payment_status`) directly, and it fires no matter which path changed the
-- row: the advance_*_order_status / cancel_*_order RPCs, a service-role
-- payment update, or a manual dashboard edit.
--
-- Not added: public.order_status_events. It would be redundant (every RPC
-- transition also updates the order row) and strictly less complete (only
-- the RPCs write an event row; any other status/payment write would be
-- missed). Its select policy also calls the SECURITY DEFINER
-- public.can_read_order_status_event() function, which Realtime would have to
-- run per subscriber for every event, versus the plain
-- `(select auth.uid()) = profile_id` comparison on the order tables. Add it
-- later only if a client needs the transition history pushed live.
--
-- The *_order_items tables are not added: line items are written once at
-- placement and never change status.
--
-- ---------------------------------------------------------------------
-- Security
-- ---------------------------------------------------------------------
--
-- postgres_changes applies the subscriber's RLS SELECT policies to INSERT
-- and UPDATE events, so this publishes nothing a client cannot already read
-- with a plain select. Each of the three tables has RLS enabled and exactly
-- two select policies (schema.sql; merchant policies restated in
-- 20260920000000_add_merchant_order_read_policies.sql):
--   * "Customers read own <x> orders": (select auth.uid()) = profile_id
--   * "Merchants read own <x> orders": public.merchant_owns_order('<x>', id)
-- and `authenticated` holds only SELECT (anon holds nothing) per
-- 20260924020000_tighten_public_table_grants.sql. No insert/update/delete
-- policy exists; writes go through SECURITY DEFINER RPCs.
--
-- Realtime does not RLS-filter DELETE events, but with RLS enabled the old
-- record they carry is reduced to the primary key only, and clients cannot
-- delete order rows (no delete grant/policy; profile deletes are restricted).
--
-- Replica identity is left at DEFAULT (primary key): UPDATE events include
-- the full new row, which is all an `id=eq.` filter and a status read need.
--
-- ---------------------------------------------------------------------
-- Safety / application
-- ---------------------------------------------------------------------
--
-- Purely additive: adding a table to a publication changes no data, columns,
-- constraints, grants or RLS policies, and is reversed with
-- `alter publication supabase_realtime drop table <table>;`. Each add is
-- guarded so re-running the migration (or applying it where a table was
-- already enabled from the dashboard) is a no-op instead of an error.
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Applying it is a deliberate manual follow-up (`supabase db push`) for the
-- project owner, per this repo's migration convention.

set search_path = '';

do $$
declare
  v_table text;
begin
  foreach v_table in array array['food_orders', 'grocery_orders', 'pharmacy_orders']
  loop
    if not exists (
      select 1
      from pg_catalog.pg_publication_tables pt
      where pt.pubname = 'supabase_realtime'
        and pt.schemaname = 'public'
        and pt.tablename = v_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        v_table
      );
    end if;
  end loop;
end;
$$;
