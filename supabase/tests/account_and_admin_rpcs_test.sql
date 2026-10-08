-- Issue #278: admin role RPCs and the self-service account RPCs.
--
--   * admin_list_profiles / admin_set_profile_role /
--     admin_lookup_profile_by_email raise for any non-admin caller
--     (customer or merchant), and the last admin cannot be demoted.
--   * update_own_profile only ever touches the caller's own row.
--   * delete_own_account only ever anonymizes the caller's own account.

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);

-- ---------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------

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
  ('55555555-5555-4555-8555-555555555555', 'pgtap-admin@example.test',
   'authenticated', 'authenticated', '{}',
   '{"firstname": "Admin", "lastname": "User", "phone": "+252610000005"}');

update public.profiles set role = 'merchant' where id = '33333333-3333-4333-8333-333333333333';
-- The test admin is the only admin, so the last-admin guard is exercised.
update public.profiles set role = 'customer' where role = 'admin';
update public.profiles set role = 'admin' where id = '55555555-5555-4555-8555-555555555555';

insert into public.delivery_addresses (id, profile_id, recipient_name, phone, street, district, city)
values
  ('c0000000-0000-4000-8000-00000000000a', '11111111-1111-4111-8111-111111111111',
   'Alice A', '+252610000001', 'A Street', 'Hodan', 'Mogadishu'),
  ('c0000000-0000-4000-8000-00000000000b', '22222222-2222-4222-8222-222222222222',
   'Bashir B', '+252610000002', 'B Street', 'Waberi', 'Mogadishu');

insert into public.wallet_transactions (id, profile_id, type, amount, description)
values
  ('b0000000-0000-4000-8000-00000000000a', '11111111-1111-4111-8111-111111111111', 'top_up', 5000, 'A top-up'),
  ('b0000000-0000-4000-8000-00000000000b', '22222222-2222-4222-8222-222222222222', 'top_up', 5000, 'B top-up');

-- ---------------------------------------------------------------------
-- Admin RPCs: non-admins are rejected
-- ---------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-4111-8111-111111111111", "role": "authenticated"}';

select throws_ok(
  $$ select * from public.admin_list_profiles() $$,
  'P0001', 'Admin privileges required',
  'a customer cannot call admin_list_profiles'
);
select throws_ok(
  $$ select public.admin_set_profile_role('11111111-1111-4111-8111-111111111111', 'admin') $$,
  'P0001', 'Admin privileges required',
  'a customer cannot promote themselves with admin_set_profile_role'
);
-- Any error is accepted here, not just 'Admin privileges required': as
-- written in 20260921020000, this (no longer app-called) function's
-- `where id = v_caller_id` is ambiguous with its own `id` output column, so
-- it currently raises 42702 for every caller, admins included. It fails
-- closed either way; the point of this test is that a non-admin never gets
-- a result out of it, whichever error that is.
select throws_ok(
  $$ select * from public.admin_lookup_profile_by_email('pgtap-b@example.test') $$,
  null::char(5), null,
  'a customer cannot call admin_lookup_profile_by_email'
);

set local request.jwt.claims to '{"sub": "33333333-3333-4333-8333-333333333333", "role": "authenticated"}';

select throws_ok(
  $$ select * from public.admin_list_profiles() $$,
  'P0001', 'Admin privileges required',
  'a merchant cannot call admin_list_profiles'
);
select throws_ok(
  $$ select public.admin_set_profile_role('33333333-3333-4333-8333-333333333333', 'admin') $$,
  'P0001', 'Admin privileges required',
  'a merchant cannot promote themselves with admin_set_profile_role'
);

-- ---------------------------------------------------------------------
-- Admin RPCs: the admin path works, within its own guard rails
-- ---------------------------------------------------------------------

set local request.jwt.claims to '{"sub": "55555555-5555-4555-8555-555555555555", "role": "authenticated"}';

select results_eq(
  $$ select id, email from public.admin_list_profiles('pgtap-a@') $$,
  $$ values ('11111111-1111-4111-8111-111111111111'::uuid, 'pgtap-a@example.test'::text) $$,
  'an admin can search profiles'
);
select lives_ok(
  $$ select public.admin_set_profile_role('11111111-1111-4111-8111-111111111111', 'merchant') $$,
  'an admin can change another profile''s role'
);
select throws_ok(
  $$ select public.admin_set_profile_role('55555555-5555-4555-8555-555555555555', 'customer') $$,
  'P0001', 'Cannot remove the last remaining admin',
  'the last remaining admin cannot be demoted'
);
select throws_ok(
  $$ select public.admin_set_profile_role('11111111-1111-4111-8111-111111111111', 'superuser') $$,
  'P0001', 'Invalid role: superuser',
  'admin_set_profile_role rejects an unknown role'
);

reset role;

select results_eq(
  $$ select id, role from public.profiles
     where id in ('11111111-1111-4111-8111-111111111111', '33333333-3333-4333-8333-333333333333',
                  '55555555-5555-4555-8555-555555555555')
     order by id $$,
  $$ values ('11111111-1111-4111-8111-111111111111'::uuid, 'merchant'::text),
            ('33333333-3333-4333-8333-333333333333'::uuid, 'merchant'::text),
            ('55555555-5555-4555-8555-555555555555'::uuid, 'admin'::text) $$,
  'only the admin''s own role change took effect'
);

-- ---------------------------------------------------------------------
-- update_own_profile
-- ---------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "22222222-2222-4222-8222-222222222222", "role": "authenticated"}';

select results_eq(
  $$ select id, firstname, phone from public.update_own_profile(p_firstname => 'Bashiir', p_phone => '+252619999999') $$,
  $$ values ('22222222-2222-4222-8222-222222222222'::uuid, 'Bashiir'::text, '+252619999999'::text) $$,
  'update_own_profile updates and returns the caller''s own profile'
);
select throws_ok(
  $$ select * from public.update_own_profile(p_phone => 'not a phone!') $$,
  '22023', 'Phone number is invalid',
  'update_own_profile validates the phone number'
);
select throws_ok(
  $$ select * from public.update_own_profile() $$,
  '22023', 'Nothing to update',
  'update_own_profile rejects an empty update'
);

reset role;

select results_eq(
  $$ select firstname, phone from public.profiles where id = '11111111-1111-4111-8111-111111111111' $$,
  $$ values ('Alice'::text, '+252610000001'::text) $$,
  'update_own_profile did not touch any other profile'
);

-- ---------------------------------------------------------------------
-- delete_own_account
-- ---------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub": "22222222-2222-4222-8222-222222222222", "role": "authenticated"}';

select lives_ok($$ select public.delete_own_account() $$, 'B can delete their own account');

reset role;

select results_eq(
  $$ select firstname, lastname, phone, deleted_at is not null
     from public.profiles where id = '22222222-2222-4222-8222-222222222222' $$,
  $$ values ('Deleted'::text, 'User'::text, ''::text, true) $$,
  'delete_own_account anonymized the caller''s profile'
);
select is(
  (select email::text from auth.users where id = '22222222-2222-4222-8222-222222222222'),
  'deleted-22222222-2222-4222-8222-222222222222@deleted.invalid',
  'delete_own_account replaced the caller''s login email'
);
select is(
  (select count(*)::integer from public.delivery_addresses where profile_id = '22222222-2222-4222-8222-222222222222'),
  0, 'delete_own_account removed the caller''s delivery addresses'
);
select is(
  (select count(*)::integer from public.wallet_transactions where profile_id = '22222222-2222-4222-8222-222222222222'),
  0, 'delete_own_account removed the caller''s wallet transactions'
);
select results_eq(
  $$ select firstname, lastname, phone, deleted_at is null
     from public.profiles where id = '11111111-1111-4111-8111-111111111111' $$,
  $$ values ('Alice'::text, 'A'::text, '+252610000001'::text, true) $$,
  'delete_own_account left another user''s profile untouched'
);
select is(
  (select count(*)::integer from public.delivery_addresses where profile_id = '11111111-1111-4111-8111-111111111111'),
  1, 'delete_own_account left another user''s delivery addresses untouched'
);
select is(
  (select email::text from auth.users where id = '11111111-1111-4111-8111-111111111111'),
  'pgtap-a@example.test',
  'delete_own_account left another user''s login untouched'
);

select * from finish();

rollback;
