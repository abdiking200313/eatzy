-- No trigger or client-side call anywhere ever created a public.profiles row
-- on sign-up. Confirmed by reading every relevant file: no `handle_new_user`
-- trigger exists anywhere under supabase/ (already noted in passing by
-- 20260830140000_add_order_status_transition_rpcs.sql's header, which
-- treated it as a known, accepted limitation -- lib/features/profile/data/
-- profile_repository.dart reads the row with `maybeSingle()`, tolerating a
-- missing profile). lib/features/auth/data/auth_service.dart's
-- signUpWithEmailPassword only calls `_supabase.auth.signUp(...)`; register_
-- screen.dart does nothing further after a successful response. So a brand
-- new account has an auth.users row and nothing in public.profiles at all --
-- confirmed directly against the live database, where 2 of 4 existing
-- auth.users rows had no matching profiles row.
--
-- This is the standard Supabase pattern (see "Managing user data" in the
-- Supabase docs): a SECURITY DEFINER trigger function on auth.users that
-- inserts a placeholder public.profiles row for every new account.
-- firstname/lastname/phone are NOT NULL with no default (schema predates
-- this migration), so the trigger must supply values -- empty strings, the
-- same placeholder convention already used elsewhere in this schema (e.g.
-- grocery_products.description defaults to ''). The app's own profile-edit
-- screen (issue #13, lib/features/profile/presentation/edit_profile_screen
-- .dart) is where a user actually fills these in; nothing downstream treats
-- an empty firstname/lastname/phone as invalid.
--
-- `role` is left unset on insert so it picks up profiles.role's own default
-- ('customer', from 20260830120000_add_merchant_role_and_store_ownership
-- .sql) -- a promotion to merchant/admin stays a separate, deliberate step.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- Applied directly to the live/production database in the same session that
-- authored this file (2026-09-21), after confirming via direct query which
-- existing auth.users rows lacked a profiles row. The backfill below is
-- idempotent (`on conflict (id) do nothing`) and safe to re-run.

set search_path = '';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, firstname, lastname, phone)
  values (new.id, '', '', '')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Backfill any pre-existing auth.users row that predates this trigger and
-- never got a profiles row.
insert into public.profiles (id, firstname, lastname, phone)
select u.id, '', '', ''
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;
