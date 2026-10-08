-- Issue #278: merchant boundaries.
--
-- A merchant may write only its own store's catalog
-- (20260830130000_add_merchant_catalog_write_policies.sql), may read only its
-- own store's orders (20260920000000_add_merchant_order_read_policies.sql)
-- and may transition only its own store's orders, only along the legal
-- transition table (20260830140000_add_order_status_transition_rpcs.sql).
-- Customer cancellation is limited to the caller's own 'confirmed' orders.

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(39);

-- ---------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------

-- A and B are customers; M1 and M2 are merchants owning one store per
-- vertical each.
insert into auth.users (id, email, aud, role, raw_app_meta_data, raw_user_meta_data)
values
  ('11111111-1111-4111-8111-111111111111', 'pgtap-a@example.test',
   'authenticated', 'authenticated', '{}',
   '{"firstname": "Alice", "lastname": "A", "phone": "+252610000001"}'),
  ('22222222-2222-4222-8222-222222222222', 'pgtap-b@example.test',
   'authenticated', 'authenticated', '{}',
   '{"firstname": "Bashir", "lastname": "B", "phone": "+252610000002"}'),
  ('33333333-3333-4333-8333-333333333333', 'pgtap-m1@example.test',
   'authenticated', 'authenticated', '{}',
   '{"firstname": "Merchant", "lastname": "One", "phone": "+252610000003"}'),
  ('44444444-4444-4444-8444-444444444444', 'pgtap-m2@example.test',
   'authenticated', 'authenticated', '{}',
   '{"firstname": "Merchant", "lastname": "Two", "phone": "+252610000004"}');

update public.profiles
set role = 'merchant'
where id in ('33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-444444444444');

insert into public.restaurants (id, name, is_open, owner_id)
values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'M1 Restaurant', true, '33333333-3333-4333-8333-333333333333'),
  ('aaaaaaaa-0000-4000-8000-000000000002', 'M2 Restaurant', true, '44444444-4444-4444-8444-444444444444');

insert into public.menu_items (id, name, description, price, image_url, restaurant_id, is_available)
values
  ('aaaaaaaa-0000-4000-8000-000000000101', 'M1 Dish', 'test', 1000, 'https://example.test/1.png',
   'aaaaaaaa-0000-4000-8000-000000000001', true),
  ('aaaaaaaa-0000-4000-8000-000000000201', 'M2 Dish', 'test', 1000, 'https://example.test/2.png',
   'aaaaaaaa-0000-4000-8000-000000000002', true);

insert into public.grocery_stores (id, name, area, owner_id)
values
  ('pgtap-g1', 'M1 Grocery', 'Test', '33333333-3333-4333-8333-333333333333'),
  ('pgtap-g2', 'M2 Grocery', 'Test', '44444444-4444-4444-8444-444444444444');

insert into public.grocery_products (id, store_id, name, unit_price, pricing_unit, quantity_step, available_quantity)
values
  ('pgtap-g1-rice', 'pgtap-g1', 'M1 Rice', 300, 'each', 1, 10),
  ('pgtap-g2-rice', 'pgtap-g2', 'M2 Rice', 300, 'each', 1, 10);

insert into public.pharmacy_categories (id, name)
values ('pgtap-category', 'pgTAP Category');

insert into public.pharmacy_stores (id, name, owner_id)
values
  ('pgtap-p1', 'M1 Pharmacy', '33333333-3333-4333-8333-333333333333'),
  ('pgtap-p2', 'M2 Pharmacy', '44444444-4444-4444-8444-444444444444');

insert into public.pharmacy_products (id, category_id, store_id, name, unit_price, stock_quantity)
values
  ('pgtap-p1-para', 'pgtap-category', 'pgtap-p1', 'M1 Paracetamol', 500, 10),
  ('pgtap-p2-para', 'pgtap-category', 'pgtap-p2', 'M2 Paracetamol', 500, 10);

-- Customer A's orders: one per vertical at each merchant's store, plus one
-- already-delivered food order at M1.
insert into public.food_orders (id, profile_id, restaurant_id, restaurant_name, subtotal, delivery_fee, tax, total, status)
values
  ('f0000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-0000-4000-8000-000000000001', 'M1 Restaurant', 1000, 499, 100, 1599, 'confirmed'),
  ('f0000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-0000-4000-8000-000000000002', 'M2 Restaurant', 1000, 499, 100, 1599, 'confirmed'),
  ('f0000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-0000-4000-8000-000000000001', 'M1 Restaurant', 1000, 499, 100, 1599, 'delivered'),
  ('f0000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-0000-4000-8000-000000000001', 'M1 Restaurant', 1000, 499, 100, 1599, 'confirmed');

insert into public.grocery_orders (
  id, profile_id, store_id, store_name, delivery_slot_label,
  delivery_window_start, delivery_window_end, recipient_name, phone,
  street, district, city, substitution_preference, subtotal, delivery_fee, total
)
values
  ('e0000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
   'pgtap-g1', 'M1 Grocery', 'Tomorrow', now() + interval '1 day',
   now() + interval '1 day 2 hours', 'Alice A', '+252610000001', '', '', '',
   'best_match', 300, 250, 550),
  ('e0000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111',
   'pgtap-g2', 'M2 Grocery', 'Tomorrow', now() + interval '1 day',
   now() + interval '1 day 2 hours', 'Alice A', '+252610000001', '', '', '',
   'best_match', 300, 250, 550);

-- Pharmacy orders have no store column: ownership resolves through items.
insert into public.pharmacy_orders (id, profile_id, recipient_name, phone, city, district, street, subtotal, delivery_fee, total)
values
  ('d0000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
   'Alice A', '+252610000001', '', '', '', 500, 250, 750),
  ('d0000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111',
   'Alice A', '+252610000001', '', '', '', 500, 250, 750);

insert into public.pharmacy_order_items (order_id, product_id, product_name, quantity, unit_price)
values
  ('d0000000-0000-4000-8000-000000000001', 'pgtap-p1-para', 'M1 Paracetamol', 1, 500),
  ('d0000000-0000-4000-8000-000000000002', 'pgtap-p2-para', 'M2 Paracetamol', 1, 500);

-- ---------------------------------------------------------------------
-- Catalog writes as merchant M1
-- ---------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "33333333-3333-4333-8333-333333333333", "role": "authenticated"}';

-- Own store: allowed.
select lives_ok(
  $$ insert into public.menu_items (name, description, price, image_url, restaurant_id)
     values ('M1 New Dish', 'test', 1500, 'https://example.test/new.png', 'aaaaaaaa-0000-4000-8000-000000000001') $$,
  'M1 can add a menu item to its own restaurant'
);
select lives_ok(
  $$ insert into public.grocery_products (id, store_id, name, unit_price, pricing_unit, quantity_step, available_quantity)
     values ('pgtap-g1-new', 'pgtap-g1', 'M1 New', 100, 'each', 1, 5) $$,
  'M1 can add a product to its own grocery store'
);
select lives_ok(
  $$ insert into public.pharmacy_products (id, category_id, store_id, name, unit_price, stock_quantity)
     values ('pgtap-p1-new', 'pgtap-category', 'pgtap-p1', 'M1 New', 100, 5) $$,
  'M1 can add a product to its own pharmacy'
);
select lives_ok(
  $$ insert into public.restaurants (name, owner_id)
     values ('M1 Second Restaurant', '33333333-3333-4333-8333-333333333333') $$,
  'M1 can open a new restaurant it owns'
);

update public.menu_items set price = 1200 where id = 'aaaaaaaa-0000-4000-8000-000000000101';

-- Another merchant's store: inserts rejected by WITH CHECK.
select throws_ok(
  $$ insert into public.menu_items (name, description, price, image_url, restaurant_id)
     values ('Intruder Dish', 'test', 1, 'https://example.test/x.png', 'aaaaaaaa-0000-4000-8000-000000000002') $$,
  '42501', null, 'M1 cannot add a menu item to M2''s restaurant'
);
select throws_ok(
  $$ insert into public.grocery_products (id, store_id, name, unit_price, pricing_unit, quantity_step, available_quantity)
     values ('pgtap-g2-intruder', 'pgtap-g2', 'Intruder', 1, 'each', 1, 5) $$,
  '42501', null, 'M1 cannot add a product to M2''s grocery store'
);
select throws_ok(
  $$ insert into public.pharmacy_products (id, category_id, store_id, name, unit_price, stock_quantity)
     values ('pgtap-p2-intruder', 'pgtap-category', 'pgtap-p2', 'Intruder', 1, 5) $$,
  '42501', null, 'M1 cannot add a product to M2''s pharmacy'
);
select throws_ok(
  $$ insert into public.restaurants (name, owner_id)
     values ('Fake M2 Restaurant', '44444444-4444-4444-8444-444444444444') $$,
  '42501', null, 'M1 cannot create a restaurant owned by M2'
);
select throws_ok(
  $$ update public.menu_items set restaurant_id = 'aaaaaaaa-0000-4000-8000-000000000002'
     where id = 'aaaaaaaa-0000-4000-8000-000000000101' $$,
  '42501', null, 'M1 cannot move its own menu item into M2''s restaurant'
);

-- Updates/deletes of M2's rows silently match nothing; verified below.
update public.menu_items set price = 1 where id = 'aaaaaaaa-0000-4000-8000-000000000201';
delete from public.menu_items where id = 'aaaaaaaa-0000-4000-8000-000000000201';
update public.grocery_products set unit_price = 1 where id = 'pgtap-g2-rice';
delete from public.grocery_products where id = 'pgtap-g2-rice';
update public.pharmacy_products set unit_price = 1 where id = 'pgtap-p2-para';
update public.restaurants set name = 'Hijacked' where id = 'aaaaaaaa-0000-4000-8000-000000000002';
update public.grocery_stores set owner_id = '33333333-3333-4333-8333-333333333333' where id = 'pgtap-g2';

-- A customer cannot open a store at all (role check on insert).
set local request.jwt.claims to '{"sub": "11111111-1111-4111-8111-111111111111", "role": "authenticated"}';

select throws_ok(
  $$ insert into public.restaurants (name, owner_id)
     values ('Customer Restaurant', '11111111-1111-4111-8111-111111111111') $$,
  '42501', null, 'a customer cannot create a restaurant'
);

reset role;

select is(
  (select price from public.menu_items where id = 'aaaaaaaa-0000-4000-8000-000000000101'),
  1200, 'M1 can update its own menu item price'
);
select is(
  (select price from public.menu_items where id = 'aaaaaaaa-0000-4000-8000-000000000201'),
  1000, 'M1 could not update or delete M2''s menu item'
);
select is(
  (select unit_price from public.grocery_products where id = 'pgtap-g2-rice'),
  300, 'M1 could not update or delete M2''s grocery product'
);
select is(
  (select unit_price from public.pharmacy_products where id = 'pgtap-p2-para'),
  500, 'M1 could not update M2''s pharmacy product'
);
select is(
  (select name from public.restaurants where id = 'aaaaaaaa-0000-4000-8000-000000000002'),
  'M2 Restaurant', 'M1 could not rename M2''s restaurant'
);
select is(
  (select owner_id from public.grocery_stores where id = 'pgtap-g2'),
  '44444444-4444-4444-8444-444444444444'::uuid, 'M1 could not take over M2''s grocery store'
);

-- ---------------------------------------------------------------------
-- Order visibility for merchants
-- ---------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "33333333-3333-4333-8333-333333333333", "role": "authenticated"}';

select results_eq(
  $$ select id from public.food_orders order by id $$,
  $$ values ('f0000000-0000-4000-8000-000000000001'::uuid),
            ('f0000000-0000-4000-8000-000000000003'::uuid),
            ('f0000000-0000-4000-8000-000000000004'::uuid) $$,
  'M1 sees only its own restaurant''s food orders'
);
select results_eq(
  $$ select id from public.grocery_orders $$,
  $$ values ('e0000000-0000-4000-8000-000000000001'::uuid) $$,
  'M1 sees only its own store''s grocery orders'
);
select results_eq(
  $$ select id from public.pharmacy_orders $$,
  $$ values ('d0000000-0000-4000-8000-000000000001'::uuid) $$,
  'M1 sees only pharmacy orders for its own pharmacy'
);

-- ---------------------------------------------------------------------
-- Merchant status transitions
-- ---------------------------------------------------------------------

select is(
  public.advance_food_order_status('f0000000-0000-4000-8000-000000000001', 'preparing'),
  'preparing', 'M1 can advance its own food order confirmed -> preparing'
);
select throws_ok(
  $$ select public.advance_food_order_status('f0000000-0000-4000-8000-000000000002', 'preparing') $$,
  'P0001', 'You do not manage this food order',
  'M1 cannot advance M2''s food order'
);
select throws_ok(
  $$ select public.advance_food_order_status('f0000000-0000-4000-8000-000000000001', 'delivered') $$,
  'P0001', 'Illegal food order status transition: preparing -> delivered',
  'a food order cannot skip from preparing to delivered'
);
select throws_ok(
  $$ select public.advance_food_order_status('f0000000-0000-4000-8000-000000000001', 'confirmed') $$,
  'P0001', 'Illegal food order status transition: preparing -> confirmed',
  'a food order cannot move backwards'
);
select throws_ok(
  $$ select public.advance_food_order_status('f0000000-0000-4000-8000-000000000003', 'cancelled') $$,
  'P0001', 'Illegal food order status transition: delivered -> cancelled',
  'a delivered food order cannot be cancelled'
);

select is(
  public.advance_grocery_order_status('e0000000-0000-4000-8000-000000000001', 'shopping'),
  'shopping', 'M1 can advance its own grocery order confirmed -> shopping'
);
select throws_ok(
  $$ select public.advance_grocery_order_status('e0000000-0000-4000-8000-000000000002', 'shopping') $$,
  'P0001', 'You do not manage this grocery order',
  'M1 cannot advance M2''s grocery order'
);
select throws_ok(
  $$ select public.advance_grocery_order_status('e0000000-0000-4000-8000-000000000001', 'packing') $$,
  'P0001', 'Illegal grocery order status transition: shopping -> packing',
  'a grocery order cannot use another vertical''s status'
);

select is(
  public.advance_pharmacy_order_status('d0000000-0000-4000-8000-000000000001', 'packing'),
  'packing', 'M1 can advance its own pharmacy order confirmed -> packing'
);
select throws_ok(
  $$ select public.advance_pharmacy_order_status('d0000000-0000-4000-8000-000000000002', 'packing') $$,
  'P0001', 'You do not manage this pharmacy order',
  'M1 cannot advance a pharmacy order for M2''s products'
);
select throws_ok(
  $$ select public.advance_pharmacy_order_status('d0000000-0000-4000-8000-000000000001', 'delivered') $$,
  'P0001', 'Illegal pharmacy order status transition: packing -> delivered',
  'a pharmacy order cannot skip from packing to delivered'
);

-- The customer who placed the order is not its merchant.
set local request.jwt.claims to '{"sub": "11111111-1111-4111-8111-111111111111", "role": "authenticated"}';

select throws_ok(
  $$ select public.advance_food_order_status('f0000000-0000-4000-8000-000000000004', 'preparing') $$,
  'P0001', 'You do not manage this food order',
  'a customer cannot advance their own order as if they were the merchant'
);

-- ---------------------------------------------------------------------
-- Customer cancellation
-- ---------------------------------------------------------------------

set local request.jwt.claims to '{"sub": "22222222-2222-4222-8222-222222222222", "role": "authenticated"}';

select throws_ok(
  $$ select public.cancel_food_order('f0000000-0000-4000-8000-000000000004') $$,
  'P0001', 'Food order not found',
  'B cannot cancel A''s food order'
);
select throws_ok(
  $$ select public.cancel_grocery_order('e0000000-0000-4000-8000-000000000002') $$,
  'P0001', 'Grocery order not found',
  'B cannot cancel A''s grocery order'
);
select throws_ok(
  $$ select public.cancel_pharmacy_order('d0000000-0000-4000-8000-000000000002') $$,
  'P0001', 'Pharmacy order not found',
  'B cannot cancel A''s pharmacy order'
);

set local request.jwt.claims to '{"sub": "11111111-1111-4111-8111-111111111111", "role": "authenticated"}';

select throws_ok(
  $$ select public.cancel_food_order('f0000000-0000-4000-8000-000000000001') $$,
  'P0001', 'A food order can only be cancelled while it is still confirmed (it is preparing)',
  'A cannot cancel their own order once the merchant has started it'
);
select is(
  public.cancel_food_order('f0000000-0000-4000-8000-000000000004'),
  'cancelled', 'A can cancel their own confirmed food order'
);

reset role;

select results_eq(
  $$ select previous_status, new_status, changed_by
     from public.order_status_events
     where order_id = 'f0000000-0000-4000-8000-000000000001' $$,
  $$ values ('confirmed'::text, 'preparing'::text, '33333333-3333-4333-8333-333333333333'::uuid) $$,
  'exactly one status event was written for the successful transition, none for the rejected ones'
);
select is(
  (select count(*)::integer from public.order_status_events
   where order_id in ('f0000000-0000-4000-8000-000000000002', 'f0000000-0000-4000-8000-000000000003',
                      'e0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000002')),
  0, 'rejected transitions wrote no status events'
);
select is(
  (select status from public.food_orders where id = 'f0000000-0000-4000-8000-000000000002'),
  'confirmed', 'M2''s food order status is unchanged'
);

select * from finish();

rollback;
