-- Issue #278: the SECURITY DEFINER order-placement RPCs.
--
-- place_food_order / place_grocery_order / place_pharmacy_order must:
--   * recompute every line from the catalog price (a client-supplied price
--     in p_items is ignored) and add the server-side service_pricing fee/tax,
--   * reject unavailable items and items from another store,
--   * be idempotent on (caller, p_idempotency_key): a replay returns the
--     original order and writes no second order, item set or stock change.
--
-- All money is integer cents (issue #8).

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(28);

-- ---------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------

insert into auth.users (id, email, aud, role, raw_app_meta_data, raw_user_meta_data)
values
  ('11111111-1111-4111-8111-111111111111', 'pgtap-a@example.test',
   'authenticated', 'authenticated', '{}',
   '{"firstname": "Alice", "lastname": "A", "phone": "+252610000001"}');

-- Pin the server-side pricing so expected totals are explicit.
update public.service_pricing set delivery_fee_cents = 499, tax_rate = 0.10 where service_id = 'food';
update public.service_pricing set delivery_fee_cents = 250, tax_rate = 0 where service_id = 'grocery';
update public.service_pricing set delivery_fee_cents = 250, tax_rate = 0 where service_id = 'pharmacy';

-- Food: R1 has an available and an unavailable dish; R2 has its own dish.
insert into public.restaurants (id, name, is_open)
values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'pgTAP R1', true),
  ('aaaaaaaa-0000-4000-8000-000000000002', 'pgTAP R2', true);

insert into public.menu_items (id, name, description, price, image_url, restaurant_id, is_available)
values
  ('aaaaaaaa-0000-4000-8000-000000000101', 'R1 Dish', 'test', 1000, 'https://example.test/1.png',
   'aaaaaaaa-0000-4000-8000-000000000001', true),
  ('aaaaaaaa-0000-4000-8000-000000000102', 'R1 Sold Out', 'test', 1000, 'https://example.test/2.png',
   'aaaaaaaa-0000-4000-8000-000000000001', false),
  ('aaaaaaaa-0000-4000-8000-000000000201', 'R2 Dish', 'test', 1000, 'https://example.test/3.png',
   'aaaaaaaa-0000-4000-8000-000000000002', true);

-- Grocery: G1 with an active product, an inactive one and a delivery slot
-- two days out (always in the future); G2 with its own product.
insert into public.grocery_stores (id, name, area)
values
  ('pgtap-g1', 'pgTAP G1', 'Test'),
  ('pgtap-g2', 'pgTAP G2', 'Test');

insert into public.grocery_products (id, store_id, name, unit_price, pricing_unit, quantity_step, available_quantity, is_active)
values
  ('pgtap-g1-rice', 'pgtap-g1', 'G1 Rice', 300, 'each', 1, 10, true),
  ('pgtap-g1-hidden', 'pgtap-g1', 'G1 Hidden', 300, 'each', 1, 10, false),
  ('pgtap-g2-rice', 'pgtap-g2', 'G2 Rice', 300, 'each', 1, 10, true);

insert into public.grocery_delivery_slots (id, store_id, label, detail, day_offset, start_time, end_time)
values ('pgtap-g1-slot', 'pgtap-g1', 'Later', '9:00 AM - 11:00 AM', 2, '09:00', '11:00');

-- Pharmacy: an in-stock product, an inactive one and an out-of-stock one.
insert into public.pharmacy_categories (id, name)
values ('pgtap-category', 'pgTAP Category');

insert into public.pharmacy_stores (id, name)
values ('pgtap-p1', 'pgTAP P1');

insert into public.pharmacy_products (id, category_id, store_id, name, unit_price, stock_quantity, is_active)
values
  ('pgtap-p1-para', 'pgtap-category', 'pgtap-p1', 'P1 Paracetamol', 500, 10, true),
  ('pgtap-p1-hidden', 'pgtap-category', 'pgtap-p1', 'P1 Hidden', 500, 10, false),
  ('pgtap-p1-empty', 'pgtap-category', 'pgtap-p1', 'P1 Out Of Stock', 500, 0, true);

set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-4111-8111-111111111111", "role": "authenticated"}';

-- ---------------------------------------------------------------------
-- place_food_order
-- ---------------------------------------------------------------------

-- 2 x 1000 = 2000; fee 499; tax round(2000 * 0.10) = 200; total 2699.
-- The "price"/"unit_price" keys are a client trying to set its own price.
select results_eq(
  $$ select subtotal, delivery_fee, tax, total
     from public.place_food_order(
       'aaaaaaaa-0000-4000-8000-000000000001', 'Alice A', '+252610000001', '', '', '',
       '[{"menu_item_id": "aaaaaaaa-0000-4000-8000-000000000101", "quantity": 2, "price": 1, "unit_price": 1}]'::jsonb,
       'pgtap-food-1') $$,
  $$ values (2000, 499, 200, 2699) $$,
  'place_food_order recomputes totals from catalog prices, ignoring a client-supplied price'
);

select results_eq(
  $$ select item.unit_price, item.quantity
     from public.food_order_items item
     join public.food_orders o on o.id = item.order_id
     where o.idempotency_key = 'pgtap-food-1' $$,
  $$ values (1000, 2) $$,
  'place_food_order stores the catalog unit price on the order item'
);

select throws_ok(
  $$ select * from public.place_food_order(
       'aaaaaaaa-0000-4000-8000-000000000001', 'Alice A', '+252610000001', '', '', '',
       '[{"menu_item_id": "aaaaaaaa-0000-4000-8000-000000000102", "quantity": 1}]'::jsonb) $$,
  'P0001', 'Food order contains invalid items',
  'place_food_order rejects an unavailable menu item'
);

select throws_ok(
  $$ select * from public.place_food_order(
       'aaaaaaaa-0000-4000-8000-000000000001', 'Alice A', '+252610000001', '', '', '',
       '[{"menu_item_id": "aaaaaaaa-0000-4000-8000-000000000201", "quantity": 1}]'::jsonb) $$,
  'P0001', 'Food order contains invalid items',
  'place_food_order rejects a menu item from another restaurant'
);

-- Replay with the same key (and a different quantity): original order back.
select results_eq(
  $$ select order_id, subtotal, total
     from public.place_food_order(
       'aaaaaaaa-0000-4000-8000-000000000001', 'Alice A', '+252610000001', '', '', '',
       '[{"menu_item_id": "aaaaaaaa-0000-4000-8000-000000000101", "quantity": 5}]'::jsonb,
       'pgtap-food-1') $$,
  $$ select id, 2000, 2699 from public.food_orders where idempotency_key = 'pgtap-food-1' $$,
  'place_food_order returns the original order for a repeated idempotency key'
);

select is(
  (select count(*)::integer from public.food_orders where idempotency_key = 'pgtap-food-1'),
  1, 'place_food_order replay did not create a second order'
);

select is(
  (select count(*)::integer
   from public.food_order_items item
   join public.food_orders o on o.id = item.order_id
   where o.idempotency_key = 'pgtap-food-1'),
  1, 'place_food_order replay did not insert the items again'
);

select is(
  (select count(*)::integer from public.food_orders where profile_id = '11111111-1111-4111-8111-111111111111'),
  1, 'rejected food orders wrote nothing'
);

-- ---------------------------------------------------------------------
-- place_grocery_order
-- ---------------------------------------------------------------------

-- 3 x 300 = 900; fee 250; no grocery tax; total 1150.
select results_eq(
  $$ select subtotal, delivery_fee, tax, total
     from public.place_grocery_order(
       'pgtap-g1', 'pgtap-g1-slot', 'Alice A', '+252610000001', '', '', '', 'best_match',
       '[{"product_id": "pgtap-g1-rice", "quantity": 3, "unit_price": 1}]'::jsonb,
       'pgtap-grocery-1') $$,
  $$ values (900, 250, 0, 1150) $$,
  'place_grocery_order recomputes totals from catalog prices, ignoring a client-supplied price'
);

select results_eq(
  $$ select item.unit_price, item.quantity
     from public.grocery_order_items item
     join public.grocery_orders o on o.id = item.order_id
     where o.idempotency_key = 'pgtap-grocery-1' $$,
  $$ values (300, 3.00::numeric) $$,
  'place_grocery_order stores the catalog unit price on the order item'
);

select throws_ok(
  $$ select * from public.place_grocery_order(
       'pgtap-g1', 'pgtap-g1-slot', 'Alice A', '+252610000001', '', '', '', 'best_match',
       '[{"product_id": "pgtap-g1-hidden", "quantity": 1}]'::jsonb) $$,
  'P0001', 'Grocery order contains invalid items',
  'place_grocery_order rejects an inactive product'
);

select throws_ok(
  $$ select * from public.place_grocery_order(
       'pgtap-g1', 'pgtap-g1-slot', 'Alice A', '+252610000001', '', '', '', 'best_match',
       '[{"product_id": "pgtap-g1-rice", "quantity": 50}]'::jsonb) $$,
  'P0001', 'Grocery order contains invalid items',
  'place_grocery_order rejects a quantity above available stock'
);

select throws_ok(
  $$ select * from public.place_grocery_order(
       'pgtap-g1', 'pgtap-g1-slot', 'Alice A', '+252610000001', '', '', '', 'best_match',
       '[{"product_id": "pgtap-g2-rice", "quantity": 1}]'::jsonb) $$,
  'P0001', 'Grocery order contains invalid items',
  'place_grocery_order rejects a product from another store'
);

select results_eq(
  $$ select order_id, subtotal, total
     from public.place_grocery_order(
       'pgtap-g1', 'pgtap-g1-slot', 'Alice A', '+252610000001', '', '', '', 'best_match',
       '[{"product_id": "pgtap-g1-rice", "quantity": 1}]'::jsonb,
       'pgtap-grocery-1') $$,
  $$ select id, 900, 1150 from public.grocery_orders where idempotency_key = 'pgtap-grocery-1' $$,
  'place_grocery_order returns the original order for a repeated idempotency key'
);

select is(
  (select count(*)::integer from public.grocery_orders where idempotency_key = 'pgtap-grocery-1'),
  1, 'place_grocery_order replay did not create a second order'
);

select is(
  (select count(*)::integer
   from public.grocery_order_items item
   join public.grocery_orders o on o.id = item.order_id
   where o.idempotency_key = 'pgtap-grocery-1'),
  1, 'place_grocery_order replay did not insert the items again'
);

select is(
  (select available_quantity from public.grocery_products where id = 'pgtap-g1-rice'),
  7.00::numeric, 'place_grocery_order decremented stock exactly once (10 - 3)'
);

select is(
  (select count(*)::integer from public.grocery_orders where profile_id = '11111111-1111-4111-8111-111111111111'),
  1, 'rejected grocery orders wrote nothing'
);

-- ---------------------------------------------------------------------
-- place_pharmacy_order
-- ---------------------------------------------------------------------

-- 2 x 500 = 1000; fee 250; no pharmacy tax; total 1250.
select results_eq(
  $$ select subtotal, delivery_fee, tax, total
     from public.place_pharmacy_order(
       'Alice A', '+252610000001', '', '', '', '',
       '[{"product_id": "pgtap-p1-para", "quantity": 2, "unit_price": 1}]'::jsonb,
       'pgtap-pharmacy-1') $$,
  $$ values (1000, 250, 0, 1250) $$,
  'place_pharmacy_order recomputes totals from catalog prices, ignoring a client-supplied price'
);

select results_eq(
  $$ select item.unit_price, item.quantity
     from public.pharmacy_order_items item
     join public.pharmacy_orders o on o.id = item.order_id
     where o.idempotency_key = 'pgtap-pharmacy-1' $$,
  $$ values (500, 2) $$,
  'place_pharmacy_order stores the catalog unit price on the order item'
);

select throws_ok(
  $$ select * from public.place_pharmacy_order(
       'Alice A', '+252610000001', '', '', '', '',
       '[{"product_id": "pgtap-p1-hidden", "quantity": 1}]'::jsonb) $$,
  'P0001', 'Pharmacy order contains invalid or non-OTC items',
  'place_pharmacy_order rejects an inactive product'
);

select throws_ok(
  $$ select * from public.place_pharmacy_order(
       'Alice A', '+252610000001', '', '', '', '',
       '[{"product_id": "pgtap-p1-empty", "quantity": 1}]'::jsonb) $$,
  'P0001', 'Pharmacy order contains invalid or non-OTC items',
  'place_pharmacy_order rejects an out-of-stock product'
);

select results_eq(
  $$ select order_id, subtotal, total
     from public.place_pharmacy_order(
       'Alice A', '+252610000001', '', '', '', '',
       '[{"product_id": "pgtap-p1-para", "quantity": 1}]'::jsonb,
       'pgtap-pharmacy-1') $$,
  $$ select id, 1000, 1250 from public.pharmacy_orders where idempotency_key = 'pgtap-pharmacy-1' $$,
  'place_pharmacy_order returns the original order for a repeated idempotency key'
);

select is(
  (select count(*)::integer from public.pharmacy_orders where idempotency_key = 'pgtap-pharmacy-1'),
  1, 'place_pharmacy_order replay did not create a second order'
);

select is(
  (select count(*)::integer
   from public.pharmacy_order_items item
   join public.pharmacy_orders o on o.id = item.order_id
   where o.idempotency_key = 'pgtap-pharmacy-1'),
  1, 'place_pharmacy_order replay did not insert the items again'
);

select is(
  (select stock_quantity from public.pharmacy_products where id = 'pgtap-p1-para'),
  8, 'place_pharmacy_order decremented stock exactly once (10 - 2)'
);

-- ---------------------------------------------------------------------
-- Ownership and side effects.
-- ---------------------------------------------------------------------

select is(
  (select profile_id from public.food_orders where idempotency_key = 'pgtap-food-1'),
  '11111111-1111-4111-8111-111111111111'::uuid,
  'the order is owned by auth.uid(), not by anything the client sent'
);

reset role;

select is(
  (select count(*)::integer
   from public.order_status_events
   where order_id in (select id from public.food_orders where idempotency_key = 'pgtap-food-1')),
  0, 'placing an order writes no status event'
);

select * from finish();

rollback;
