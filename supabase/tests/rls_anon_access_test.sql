-- Issue #278: what the anon (signed-out) role can and cannot reach.
--
-- Anon must not be able to read any per-user table -- the grants
-- (20260924020000_tighten_public_table_grants.sql and earlier) give anon no
-- privilege on them at all, so every read fails with 42501 -- and must not
-- be able to call the order / account RPCs. It can read the public catalog
-- (active rows only where the select policy says so) and cannot write it.

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(34);

-- ---------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------

insert into auth.users (id, email, aud, role, raw_app_meta_data, raw_user_meta_data)
values
  ('11111111-1111-4111-8111-111111111111', 'pgtap-a@example.test',
   'authenticated', 'authenticated', '{}',
   '{"firstname": "Alice", "lastname": "A", "phone": "+252610000001"}');

insert into public.restaurants (id, name, is_open)
values ('aaaaaaaa-0000-4000-8000-000000000001', 'pgTAP Restaurant', true);

insert into public.menu_items (id, name, description, price, image_url, restaurant_id, is_available)
values ('aaaaaaaa-0000-4000-8000-000000000101', 'pgTAP Dish', 'test', 1000, 'https://example.test/dish.png',
        'aaaaaaaa-0000-4000-8000-000000000001', true);

insert into public.grocery_stores (id, name, area, is_active)
values
  ('pgtap-grocery', 'pgTAP Grocery', 'Test', true),
  ('pgtap-grocery-closed', 'pgTAP Closed Grocery', 'Test', false);

insert into public.grocery_products (id, store_id, name, unit_price, pricing_unit, quantity_step, available_quantity, is_active)
values
  ('pgtap-grocery-rice', 'pgtap-grocery', 'pgTAP Rice', 300, 'each', 1, 10, true),
  ('pgtap-grocery-hidden', 'pgtap-grocery', 'pgTAP Hidden', 300, 'each', 1, 10, false);

insert into public.pharmacy_categories (id, name)
values ('pgtap-category', 'pgTAP Category');

insert into public.pharmacy_stores (id, name)
values ('pgtap-pharmacy', 'pgTAP Pharmacy');

insert into public.pharmacy_products (id, category_id, store_id, name, unit_price, stock_quantity, is_active)
values
  ('pgtap-pharmacy-para', 'pgtap-category', 'pgtap-pharmacy', 'pgTAP Paracetamol', 500, 10, true),
  ('pgtap-pharmacy-hidden', 'pgtap-category', 'pgtap-pharmacy', 'pgTAP Hidden', 500, 10, false);

insert into public.food_orders (id, profile_id, restaurant_id, restaurant_name, subtotal, delivery_fee, tax, total)
values ('f0000000-0000-4000-8000-00000000000a', '11111111-1111-4111-8111-111111111111',
        'aaaaaaaa-0000-4000-8000-000000000001', 'pgTAP Restaurant', 1000, 499, 100, 1599);

-- ---------------------------------------------------------------------
-- As anon
-- ---------------------------------------------------------------------

set local role anon;
set local request.jwt.claims to '{"role": "anon"}';

-- Per-user tables: no read privilege at all.
select throws_ok($$ select * from public.profiles $$, '42501', null, 'anon cannot read profiles');
select throws_ok($$ select * from public.food_orders $$, '42501', null, 'anon cannot read food_orders');
select throws_ok($$ select * from public.food_order_items $$, '42501', null, 'anon cannot read food_order_items');
select throws_ok($$ select * from public.grocery_orders $$, '42501', null, 'anon cannot read grocery_orders');
select throws_ok($$ select * from public.grocery_order_items $$, '42501', null, 'anon cannot read grocery_order_items');
select throws_ok($$ select * from public.pharmacy_orders $$, '42501', null, 'anon cannot read pharmacy_orders');
select throws_ok($$ select * from public.pharmacy_order_items $$, '42501', null, 'anon cannot read pharmacy_order_items');
select throws_ok($$ select * from public.delivery_addresses $$, '42501', null, 'anon cannot read delivery_addresses');
select throws_ok($$ select * from public.wallet_transactions $$, '42501', null, 'anon cannot read wallet_transactions');
select throws_ok($$ select id from public.payment_methods $$, '42501', null, 'anon cannot read payment_methods');
select throws_ok($$ select * from public.order_status_events $$, '42501', null, 'anon cannot read order_status_events');
select throws_ok($$ select * from public.customer_activity $$, '42501', null, 'anon cannot read the customer_activity view');

-- Public catalog: readable.
select is(
  (select count(*)::integer from public.restaurants where id = 'aaaaaaaa-0000-4000-8000-000000000001'),
  1, 'anon can read restaurants'
);
select is(
  (select count(*)::integer from public.menu_items where id = 'aaaaaaaa-0000-4000-8000-000000000101'),
  1, 'anon can read menu items'
);
select lives_ok($$ select * from public.item_categories $$, 'anon can read item categories');
select lives_ok($$ select * from public.restaurant_locations $$, 'anon can read restaurant locations');
select is(
  (select count(*)::integer from public.grocery_stores where id = 'pgtap-grocery'),
  1, 'anon can read an active grocery store'
);
select is(
  (select count(*)::integer from public.grocery_stores where id = 'pgtap-grocery-closed'),
  0, 'anon cannot see an inactive grocery store'
);
select is(
  (select count(*)::integer from public.grocery_products where id = 'pgtap-grocery-rice'),
  1, 'anon can read an active grocery product'
);
select is(
  (select count(*)::integer from public.grocery_products where id = 'pgtap-grocery-hidden'),
  0, 'anon cannot see an inactive grocery product'
);
select lives_ok($$ select * from public.grocery_categories $$, 'anon can read grocery categories');
select lives_ok($$ select * from public.grocery_delivery_slots $$, 'anon can read grocery delivery slots');
select is(
  (select count(*)::integer from public.pharmacy_stores where id = 'pgtap-pharmacy'),
  1, 'anon can read an active pharmacy store'
);
select is(
  (select count(*)::integer from public.pharmacy_categories where id = 'pgtap-category'),
  1, 'anon can read an active pharmacy category'
);
select is(
  (select count(*)::integer from public.pharmacy_products where id = 'pgtap-pharmacy-para'),
  1, 'anon can read an active OTC pharmacy product'
);
select is(
  (select count(*)::integer from public.pharmacy_products where id = 'pgtap-pharmacy-hidden'),
  0, 'anon cannot see an inactive pharmacy product'
);

-- Public catalog: not writable by anon.
select throws_ok(
  $$ insert into public.restaurants (name) values ('anon restaurant') $$,
  '42501', null, 'anon cannot create a restaurant'
);
select throws_ok(
  $$ update public.menu_items set price = 1 where id = 'aaaaaaaa-0000-4000-8000-000000000101' $$,
  '42501', null, 'anon cannot change a menu item price'
);
select throws_ok(
  $$ delete from public.grocery_products where id = 'pgtap-grocery-rice' $$,
  '42501', null, 'anon cannot delete a grocery product'
);

-- RPCs: execute is revoked from anon.
select throws_ok(
  $$ select * from public.place_food_order(
       'aaaaaaaa-0000-4000-8000-000000000001', 'x', '+252610000009', '', '', '',
       '[{"menu_item_id": "aaaaaaaa-0000-4000-8000-000000000101", "quantity": 1}]'::jsonb) $$,
  '42501', null, 'anon cannot call place_food_order'
);
select throws_ok(
  $$ select public.advance_food_order_status('f0000000-0000-4000-8000-00000000000a', 'preparing') $$,
  '42501', null, 'anon cannot call advance_food_order_status'
);
select throws_ok(
  $$ select public.cancel_food_order('f0000000-0000-4000-8000-00000000000a') $$,
  '42501', null, 'anon cannot call cancel_food_order'
);
select throws_ok(
  $$ select public.delete_own_account() $$,
  '42501', null, 'anon cannot call delete_own_account'
);
select throws_ok(
  $$ select * from public.admin_list_profiles() $$,
  '42501', null, 'anon cannot call admin_list_profiles'
);

reset role;

select * from finish();

rollback;
