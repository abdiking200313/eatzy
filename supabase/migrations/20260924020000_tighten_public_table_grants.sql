-- Least-privilege table grants for the API roles (anon, authenticated).
--
-- Audit of the live DB on 2026-09-24: many public tables still carried
-- Supabase's default "grant all" to anon and authenticated -- INSERT, UPDATE,
-- DELETE, TRUNCATE, TRIGGER, REFERENCES -- on tables that only ever need
-- SELECT. RLS blocked most of it, but:
--
--   * TRUNCATE is not subject to RLS at all.
--   * profiles: `authenticated` could UPDATE every column, including `role`.
--     Only the absence of an UPDATE policy stopped a user from making
--     themselves admin; one well-meant "owner can update" policy would have
--     opened it.
--
-- Every grant below is exactly what RLS policies and the app actually use:
--
--   catalog (public read)       deals, deal_items, item_categories,
--                               restaurant_locations, grocery_delivery_slots,
--                               pharmacy_categories
--   merchant-writable catalog   restaurants, menu_items, grocery_stores,
--                               grocery_products, pharmacy_stores,
--                               pharmacy_products  (merchant_*_repository.dart
--                               writes these directly; per-owner RLS policies)
--   customer-writable           delivery_addresses (delivery_address_repository
--                               .dart writes directly; per-owner RLS policies)
--   customer read-only          profiles, wallet_transactions, *_orders,
--                               *_order_items, order_status_events,
--                               service_pricing  (all writes go through
--                               SECURITY DEFINER RPCs/triggers)
--
-- Left untouched: payment_methods (deliberate column-level SELECT grants that
-- hide the provider token) and the two security_invoker views, which already
-- carry SELECT-only grants.
--
-- Trigger functions only need EXECUTE when a trigger is created, not when it
-- fires, so revoking it from the API roles doesn't affect the triggers.
-- set_updated_at stays executable because it isn't SECURITY DEFINER.

set search_path = '';

-- Catalog: read-only for everyone.
revoke all on table
  public.deals,
  public.deal_items,
  public.item_categories,
  public.restaurant_locations,
  public.grocery_delivery_slots,
  public.pharmacy_categories
from anon, authenticated;
grant select on table
  public.deals,
  public.deal_items,
  public.item_categories,
  public.restaurant_locations,
  public.grocery_delivery_slots,
  public.pharmacy_categories
to anon, authenticated;

-- Merchant-writable catalog: public read, merchants write through RLS.
revoke all on table
  public.restaurants,
  public.menu_items,
  public.grocery_stores,
  public.grocery_products,
  public.pharmacy_stores,
  public.pharmacy_products
from anon, authenticated;
grant select on table
  public.restaurants,
  public.menu_items,
  public.grocery_stores,
  public.grocery_products,
  public.pharmacy_stores,
  public.pharmacy_products
to anon;
grant select, insert, update, delete on table
  public.restaurants,
  public.menu_items,
  public.grocery_stores,
  public.grocery_products,
  public.pharmacy_stores,
  public.pharmacy_products
to authenticated;

-- Customer-owned, written directly by the app.
revoke all on table public.delivery_addresses from anon, authenticated;
grant select, insert, update, delete on table public.delivery_addresses
  to authenticated;

-- Customer read-only; writes go through SECURITY DEFINER functions.
revoke all on table
  public.profiles,
  public.wallet_transactions,
  public.food_orders,
  public.food_order_items,
  public.grocery_orders,
  public.grocery_order_items,
  public.pharmacy_orders,
  public.pharmacy_order_items,
  public.order_status_events,
  public.service_pricing
from anon, authenticated;
grant select on table
  public.profiles,
  public.wallet_transactions,
  public.food_orders,
  public.food_order_items,
  public.grocery_orders,
  public.grocery_order_items,
  public.pharmacy_orders,
  public.pharmacy_order_items,
  public.order_status_events,
  public.service_pricing
to authenticated;

revoke all on function public.handle_new_user() from public, anon, authenticated;
