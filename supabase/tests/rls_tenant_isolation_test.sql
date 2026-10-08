-- Issue #278: tenant isolation for every per-user table.
--
-- User B must not be able to read, update or delete user A's orders, order
-- items, delivery addresses, wallet transactions or profile. Reads are
-- enforced by RLS select policies (a leak shows up as an extra row in B's
-- result set); writes on the order/wallet/profile tables are enforced by the
-- table grants (authenticated holds SELECT only, so a write fails with
-- 42501), and on delivery_addresses -- which authenticated may write -- by
-- the owner-scoped update/delete/insert policies.
--
-- Run with `supabase test db`. Everything happens inside one transaction
-- that is rolled back at the end, so no fixture survives the run.

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(32);

-- ---------------------------------------------------------------------
-- Fixtures (as the migration owner, which bypasses RLS)
-- ---------------------------------------------------------------------

-- handle_new_user() creates the public.profiles row from the metadata.
insert into auth.users (id, email, aud, role, raw_app_meta_data, raw_user_meta_data)
values
  ('11111111-1111-4111-8111-111111111111', 'pgtap-a@example.test',
   'authenticated', 'authenticated', '{}',
   '{"firstname": "Alice", "lastname": "A", "phone": "+252610000001"}'),
  ('22222222-2222-4222-8222-222222222222', 'pgtap-b@example.test',
   'authenticated', 'authenticated', '{}',
   '{"firstname": "Bashir", "lastname": "B", "phone": "+252610000002"}');

insert into public.restaurants (id, name, is_open)
values ('aaaaaaaa-0000-4000-8000-000000000001', 'pgTAP Restaurant', true);

insert into public.menu_items (id, name, description, price, image_url, restaurant_id, is_available)
values ('aaaaaaaa-0000-4000-8000-000000000101', 'pgTAP Dish', 'test', 1000, 'https://example.test/dish.png',
        'aaaaaaaa-0000-4000-8000-000000000001', true);

insert into public.grocery_stores (id, name, area)
values ('pgtap-grocery', 'pgTAP Grocery', 'Test');

insert into public.grocery_products (id, store_id, name, unit_price, pricing_unit, quantity_step, available_quantity)
values ('pgtap-grocery-rice', 'pgtap-grocery', 'pgTAP Rice', 300, 'each', 1, 10);

insert into public.pharmacy_categories (id, name)
values ('pgtap-category', 'pgTAP Category');

insert into public.pharmacy_stores (id, name)
values ('pgtap-pharmacy', 'pgTAP Pharmacy');

insert into public.pharmacy_products (id, category_id, store_id, name, unit_price, stock_quantity)
values ('pgtap-pharmacy-para', 'pgtap-category', 'pgtap-pharmacy', 'pgTAP Paracetamol', 500, 10);

-- One order per vertical for each of A and B, each with one item.
insert into public.food_orders (id, profile_id, restaurant_id, restaurant_name, subtotal, delivery_fee, tax, total)
values
  ('f0000000-0000-4000-8000-00000000000a', '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-0000-4000-8000-000000000001', 'pgTAP Restaurant', 1000, 499, 100, 1599),
  ('f0000000-0000-4000-8000-00000000000b', '22222222-2222-4222-8222-222222222222',
   'aaaaaaaa-0000-4000-8000-000000000001', 'pgTAP Restaurant', 1000, 499, 100, 1599);

insert into public.food_order_items (order_id, menu_item_id, item_name, quantity, unit_price)
values
  ('f0000000-0000-4000-8000-00000000000a', 'aaaaaaaa-0000-4000-8000-000000000101', 'pgTAP Dish', 1, 1000),
  ('f0000000-0000-4000-8000-00000000000b', 'aaaaaaaa-0000-4000-8000-000000000101', 'pgTAP Dish', 1, 1000);

insert into public.grocery_orders (
  id, profile_id, store_id, store_name, delivery_slot_label,
  delivery_window_start, delivery_window_end, recipient_name, phone,
  street, district, city, substitution_preference, subtotal, delivery_fee, total
)
values
  ('e0000000-0000-4000-8000-00000000000a', '11111111-1111-4111-8111-111111111111',
   'pgtap-grocery', 'pgTAP Grocery', 'Tomorrow', now() + interval '1 day',
   now() + interval '1 day 2 hours', 'Alice A', '+252610000001', '', '', '',
   'best_match', 300, 250, 550),
  ('e0000000-0000-4000-8000-00000000000b', '22222222-2222-4222-8222-222222222222',
   'pgtap-grocery', 'pgTAP Grocery', 'Tomorrow', now() + interval '1 day',
   now() + interval '1 day 2 hours', 'Bashir B', '+252610000002', '', '', '',
   'best_match', 300, 250, 550);

insert into public.grocery_order_items (order_id, product_id, product_name, pricing_unit, quantity, unit_price)
values
  ('e0000000-0000-4000-8000-00000000000a', 'pgtap-grocery-rice', 'pgTAP Rice', 'each', 1, 300),
  ('e0000000-0000-4000-8000-00000000000b', 'pgtap-grocery-rice', 'pgTAP Rice', 'each', 1, 300);

insert into public.pharmacy_orders (id, profile_id, recipient_name, phone, city, district, street, subtotal, delivery_fee, total)
values
  ('d0000000-0000-4000-8000-00000000000a', '11111111-1111-4111-8111-111111111111',
   'Alice A', '+252610000001', '', '', '', 500, 250, 750),
  ('d0000000-0000-4000-8000-00000000000b', '22222222-2222-4222-8222-222222222222',
   'Bashir B', '+252610000002', '', '', '', 500, 250, 750);

insert into public.pharmacy_order_items (order_id, product_id, product_name, quantity, unit_price)
values
  ('d0000000-0000-4000-8000-00000000000a', 'pgtap-pharmacy-para', 'pgTAP Paracetamol', 1, 500),
  ('d0000000-0000-4000-8000-00000000000b', 'pgtap-pharmacy-para', 'pgTAP Paracetamol', 1, 500);

insert into public.delivery_addresses (id, profile_id, label, recipient_name, phone, street, district, city)
values
  ('c0000000-0000-4000-8000-00000000000a', '11111111-1111-4111-8111-111111111111',
   'Home', 'Alice A', '+252610000001', 'A Street', 'Hodan', 'Mogadishu'),
  ('c0000000-0000-4000-8000-00000000000b', '22222222-2222-4222-8222-222222222222',
   'Home', 'Bashir B', '+252610000002', 'B Street', 'Waberi', 'Mogadishu');

insert into public.wallet_transactions (id, profile_id, type, amount, description)
values
  ('b0000000-0000-4000-8000-00000000000a', '11111111-1111-4111-8111-111111111111', 'top_up', 5000, 'A top-up'),
  ('b0000000-0000-4000-8000-00000000000b', '22222222-2222-4222-8222-222222222222', 'top_up', 5000, 'B top-up');

-- ---------------------------------------------------------------------
-- Reads: user B sees exactly their own rows and none of A's.
-- ---------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "22222222-2222-4222-8222-222222222222", "role": "authenticated"}';

select results_eq(
  $$ select id from public.food_orders $$,
  $$ values ('f0000000-0000-4000-8000-00000000000b'::uuid) $$,
  'B sees only their own food order, not A''s'
);

select results_eq(
  $$ select order_id from public.food_order_items $$,
  $$ values ('f0000000-0000-4000-8000-00000000000b'::uuid) $$,
  'B sees only their own food order items, not A''s'
);

select results_eq(
  $$ select id from public.grocery_orders $$,
  $$ values ('e0000000-0000-4000-8000-00000000000b'::uuid) $$,
  'B sees only their own grocery order, not A''s'
);

select results_eq(
  $$ select order_id from public.grocery_order_items $$,
  $$ values ('e0000000-0000-4000-8000-00000000000b'::uuid) $$,
  'B sees only their own grocery order items, not A''s'
);

select results_eq(
  $$ select id from public.pharmacy_orders $$,
  $$ values ('d0000000-0000-4000-8000-00000000000b'::uuid) $$,
  'B sees only their own pharmacy order, not A''s'
);

select results_eq(
  $$ select order_id from public.pharmacy_order_items $$,
  $$ values ('d0000000-0000-4000-8000-00000000000b'::uuid) $$,
  'B sees only their own pharmacy order items, not A''s'
);

select results_eq(
  $$ select id from public.delivery_addresses $$,
  $$ values ('c0000000-0000-4000-8000-00000000000b'::uuid) $$,
  'B sees only their own delivery address, not A''s'
);

select results_eq(
  $$ select id from public.wallet_transactions $$,
  $$ values ('b0000000-0000-4000-8000-00000000000b'::uuid) $$,
  'B sees only their own wallet transaction, not A''s'
);

select results_eq(
  $$ select id from public.profiles $$,
  $$ values ('22222222-2222-4222-8222-222222222222'::uuid) $$,
  'B sees only their own profile, not A''s'
);

-- ---------------------------------------------------------------------
-- Writes on read-only tables: no client write path at all (42501).
-- ---------------------------------------------------------------------

select throws_ok(
  $$ update public.food_orders set status = 'delivered' where id = 'f0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot update A''s food order'
);
select throws_ok(
  $$ delete from public.food_orders where id = 'f0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot delete A''s food order'
);
select throws_ok(
  $$ update public.food_order_items set unit_price = 1 where order_id = 'f0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot update A''s food order items'
);
select throws_ok(
  $$ delete from public.food_order_items where order_id = 'f0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot delete A''s food order items'
);

select throws_ok(
  $$ update public.grocery_orders set status = 'delivered' where id = 'e0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot update A''s grocery order'
);
select throws_ok(
  $$ delete from public.grocery_orders where id = 'e0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot delete A''s grocery order'
);
select throws_ok(
  $$ update public.grocery_order_items set unit_price = 1 where order_id = 'e0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot update A''s grocery order items'
);
select throws_ok(
  $$ delete from public.grocery_order_items where order_id = 'e0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot delete A''s grocery order items'
);

select throws_ok(
  $$ update public.pharmacy_orders set status = 'delivered' where id = 'd0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot update A''s pharmacy order'
);
select throws_ok(
  $$ delete from public.pharmacy_orders where id = 'd0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot delete A''s pharmacy order'
);
select throws_ok(
  $$ update public.pharmacy_order_items set unit_price = 1 where order_id = 'd0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot update A''s pharmacy order items'
);
select throws_ok(
  $$ delete from public.pharmacy_order_items where order_id = 'd0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot delete A''s pharmacy order items'
);

select throws_ok(
  $$ update public.wallet_transactions set amount = 1 where id = 'b0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot update A''s wallet transaction'
);
select throws_ok(
  $$ delete from public.wallet_transactions where id = 'b0000000-0000-4000-8000-00000000000a' $$,
  '42501', null, 'B cannot delete A''s wallet transaction'
);

select throws_ok(
  $$ update public.profiles set firstname = 'Hacked' where id = '11111111-1111-4111-8111-111111111111' $$,
  '42501', null, 'B cannot update A''s profile'
);
select throws_ok(
  $$ delete from public.profiles where id = '11111111-1111-4111-8111-111111111111' $$,
  '42501', null, 'B cannot delete A''s profile'
);

-- Fabrication: no direct inserts of money-bearing rows, and no self-promotion.
select throws_ok(
  $$ insert into public.wallet_transactions (profile_id, type, amount, description)
     values ('22222222-2222-4222-8222-222222222222', 'top_up', 100000, 'free money') $$,
  '42501', null, 'B cannot credit their own wallet directly'
);
select throws_ok(
  $$ insert into public.food_orders (profile_id, restaurant_id, restaurant_name, subtotal, total)
     values ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-0000-4000-8000-000000000001', 'x', 1, 1) $$,
  '42501', null, 'B cannot insert a food order directly, bypassing place_food_order'
);
select throws_ok(
  $$ update public.profiles set role = 'admin' where id = '22222222-2222-4222-8222-222222222222' $$,
  '42501', null, 'B cannot promote their own profile to admin'
);

-- ---------------------------------------------------------------------
-- delivery_addresses: writable by its owner only (owner-scoped policies).
-- ---------------------------------------------------------------------

select throws_ok(
  $$ insert into public.delivery_addresses (profile_id, recipient_name, phone, street, district, city)
     values ('11111111-1111-4111-8111-111111111111', 'x', 'x', 'x', 'x', 'x') $$,
  '42501', null, 'B cannot create a delivery address owned by A'
);

-- Both of these silently match zero rows under RLS; verified below.
update public.delivery_addresses
set street = 'Hacked Street'
where id = 'c0000000-0000-4000-8000-00000000000a';

delete from public.delivery_addresses
where id = 'c0000000-0000-4000-8000-00000000000a';

update public.delivery_addresses
set street = 'B New Street'
where id = 'c0000000-0000-4000-8000-00000000000b';

reset role;

select is(
  (select street from public.delivery_addresses where id = 'c0000000-0000-4000-8000-00000000000a'),
  'A Street',
  'B''s update did not touch A''s delivery address'
);

select is(
  (select count(*)::integer from public.delivery_addresses where id = 'c0000000-0000-4000-8000-00000000000a'),
  1,
  'B''s delete did not remove A''s delivery address'
);

select is(
  (select street from public.delivery_addresses where id = 'c0000000-0000-4000-8000-00000000000b'),
  'B New Street',
  'B can update their own delivery address'
);

select * from finish();

rollback;
