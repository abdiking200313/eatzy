-- Remove the cleaning/cleaner service vertical entirely (issue #50).
--
-- Cleaning was the least-developed vertical (booking-only, no real
-- marketplace behind it) and has been repeatedly flagged for removal. This
-- migration drops every cleaning-related table, policy, index, and RPC
-- introduced across:
--   - 20260727152319_connect_super_app_services.sql
--   - 20260727164413_add_long_stay_cleaner_marketplace.sql
--   - 20260727164643_index_cleaning_booking_specialties.sql
-- Those historical migrations are left untouched per this repo's convention
-- (append-only history); this is a new migration that subtracts what they
-- added. The demo cleaning booking row seeded in
-- 20260727154405_seed_demo_customer_activity.sql is removed implicitly when
-- public.cleaning_bookings is dropped below.
--
-- NOT applied to the live database as part of this change. Per this repo's
-- migration convention, run this manually against the live Supabase project
-- only after explicit human confirmation.

-- Redefine customer_activity without the cleaning branch first. The view
-- currently selects from public.cleaning_bookings, so it must stop
-- referencing that table before the table can be dropped below. The
-- surviving column list, order, and types are unchanged from the original
-- definition, which `create or replace view` requires.
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

-- Drop the cleaning booking RPCs (hourly + long-stay contracts).
drop function if exists public.place_cleaning_booking(
  text, smallint, text, text, timestamptz, text
);
drop function if exists public.place_long_stay_cleaning_booking(
  text, text, smallint, text, text, timestamptz, text
);

-- Drop cleaning tables in dependency order (children before the parents
-- they reference), so no explicit `cascade` is needed. Row-level security
-- policies, indexes, and grants on each table are dropped automatically
-- along with it.
drop table if exists public.cleaning_bookings;
drop table if exists public.cleaning_professional_stay_plans;
drop table if exists public.cleaning_professional_specialties;
drop table if exists public.cleaning_professional_services;
drop table if exists public.cleaning_service_durations;
drop table if exists public.cleaning_specialties;
drop table if exists public.cleaning_professionals;
drop table if exists public.cleaning_services;

-- Note: the `btree_gist` extension (enabled in
-- 20260727152319_connect_super_app_services.sql only to support
-- cleaning_bookings' exclusion constraint) is intentionally left installed
-- rather than dropped — extensions are shared, low-cost to leave in place,
-- and dropping one is out of scope for this subtraction.
