-- Remove demo/seed data that was inserted by the migration chain instead of
-- a proper seed file (issue #35).
--
-- `20260727154405_seed_demo_customer_activity.sql` attached fake "delivered"
-- food/grocery/pharmacy orders (and, at the time, a cleaning booking) to
-- `select id from public.profiles order by id limit 1` -- i.e. whichever
-- real signed-up user happened to be first, not a dedicated demo account.
-- Migrations run on every environment including production, so a real
-- customer could see fake completed orders in their own history.
-- `20260727152319_connect_super_app_services.sql` also embedded the demo
-- grocery/pharmacy catalog directly in the schema-creating migration.
--
-- Both are now provided the correct way, via `supabase/seed.sql` (Supabase's
-- standard seed-file convention), which only ever runs against local/dev
-- databases through `supabase db reset` / `supabase seed` -- never through
-- `supabase db push` / the normal migration-apply path that reaches
-- production. Those historical migrations are left untouched per this
-- repo's convention (append-only history, see
-- 20260815153920_remove_cleaning_vertical.sql for the precedent); this is a
-- new migration that subtracts what they added.
--
-- NOT applied to the live/production database as part of this change. Per
-- this repo's migration convention, a human must apply this manually, and
-- only after confirming no real customer order references the demo catalog
-- rows removed below -- see the PR description for the exact pre-flight
-- check (`grocery_orders.store_id` and `pharmacy_products.category_id` are
-- both `on delete restrict`, so this migration fails loudly instead of
-- corrupting data if a real order still depends on them).
--
-- Demo food orders are intentionally NOT deleted here: unlike the grocery
-- and pharmacy demo orders (which carry an exact, unique
-- "Demo Customer" / "+252 61 000 0000" fingerprint), the demo food order
-- has no such marker -- it just references a real restaurant/menu item, so
-- there is no reliable way to identify it after the fact without risking a
-- real customer's order. A human who knows which profile was first in
-- `public.profiles` at the time this migration was written (see the issue)
-- can look up and remove that one row by hand if needed.

-- Demo grocery order (recipient_name/phone/street match the exact fake
-- values 20260727154405 always used). Order items cascade automatically.
delete from public.grocery_orders
where recipient_name = 'Demo Customer'
  and phone = '+252 61 000 0000'
  and street = 'Demo fulfilment location';

-- Demo pharmacy order (same fingerprint fields, pharmacy_orders' equivalent
-- columns).
delete from public.pharmacy_orders
where customer_name = 'Demo Customer'
  and phone_number = '+252 61 000 0000'
  and address_line = 'Demo fulfilment location';

-- Demo pharmacy catalog. category_id is `on delete restrict`, so products
-- must go before categories.
delete from public.pharmacy_products
where id in (
  'pain-paracetamol',
  'cold-cough-syrup',
  'first-aid-bandages',
  'wellness-vitamin-c',
  'allergy-antihistamine'
);

delete from public.pharmacy_categories
where id in ('pain-relief', 'cold-flu', 'first-aid', 'vitamins', 'allergy');

-- Demo grocery catalog. grocery_products and grocery_delivery_slots both
-- reference grocery_stores `on delete cascade`, so deleting the two demo
-- stores removes their products and slots automatically.
delete from public.grocery_stores
where id in ('bakaal-fresh', 'suuqa-hamar');
