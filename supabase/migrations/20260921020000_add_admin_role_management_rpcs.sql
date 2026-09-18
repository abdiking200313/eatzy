-- Requested directly by the app owner, 2026-09-18: the only way to make an
-- account merchant/admin was hand-editing `public.profiles.role` in the
-- Supabase SQL editor / table editor. `20260830120000_add_merchant_role_
-- and_store_ownership.sql` even says outright "a promotion to merchant/admin
-- stays a separate, deliberate step" -- but never actually built that step.
-- This migration builds it as two admin-only RPCs, so promoting an account
-- going forward never needs direct database access again.
--
-- ---------------------------------------------------------------------
-- What this adds
-- ---------------------------------------------------------------------
--
--   1. `public.admin_lookup_profile_by_email(target_email text)` -- looks up
--      a profile by the account's sign-up email (only stored on
--      `auth.users`, not `public.profiles`), returning its id, name, and
--      current role. Lets the admin UI confirm it found the right account
--      before changing anything.
--   2. `public.admin_set_profile_role(target_profile_id uuid, new_role
--      text)` -- sets `public.profiles.role` for the target profile.
--
-- Both are `security definer` and both independently re-check that the
-- *caller* already has `role = 'admin'` -- neither is reachable by a plain
-- customer or merchant account, so this cannot be used for self-service
-- privilege escalation. Any signed-in admin may call these, per the app
-- owner's own answer (2026-09-18: "any admin", not a single hardcoded
-- account) -- there is no separate super-admin tier.
--
-- ---------------------------------------------------------------------
-- Deliberately NOT in this migration
-- ---------------------------------------------------------------------
--
--   * Store creation/assignment. Promoting an account to merchant only
--     changes `profiles.role` -- the newly-promoted merchant still creates
--     their own store afterward through the existing "My Store" empty-state
--     flow (`MerchantStoreController.createStore`), exactly like any other
--     merchant. The app owner explicitly asked to keep this to just the
--     role change (2026-09-18).
--   * A bootstrap path for the very first admin. `admin_set_profile_role`
--     always requires an existing admin caller, including for promoting the
--     first one -- there is no client-reachable way to create the first
--     admin account, by design (a self-service "promote myself to admin"
--     path reachable by any signed-up customer would be a real privilege-
--     escalation hole). The very first admin is set once, directly, by
--     whoever already has direct database access:
--
--       update public.profiles set role = 'admin' where id =
--         (select id from auth.users where email = 'the-owner-email');
--
--     After that one-time step, every further promotion (merchant or
--     admin) goes through these RPCs from inside the app instead.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- Guards against locking the app out of its own admin tooling: demoting the
-- last remaining admin away from 'admin' is rejected outright, so
-- `admin_set_profile_role` itself can never be used to reach a state with
-- zero admins (which would recreate exactly the "back to raw SQL" problem
-- this migration exists to close).
--
-- `security definer` + `set search_path = ''` + fully schema-qualified
-- identifiers, matching every other security-definer RPC in this repo
-- (`delete_own_account`, `place_*_order`, `advance_*_order_status`). Execute
-- is revoked from `public`/`anon` and granted only to `authenticated` --
-- matching the pattern those RPCs use -- since the in-function admin check
-- is what actually gates access, not the grant alone.
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Per this repo's migration convention, a human with access to the Supabase
-- project must run `supabase db push` (or apply this file directly) after
-- reviewing it.
-- ---------------------------------------------------------------------

set search_path = '';

create or replace function public.admin_lookup_profile_by_email(
  target_email text
)
returns table (
  id uuid,
  firstname text,
  lastname text,
  role text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid := (select auth.uid());
begin
  if v_caller_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_caller_id and role = 'admin'
  ) then
    raise exception 'Admin privileges required';
  end if;

  return query
  select p.id, p.firstname, p.lastname, p.role
  from public.profiles p
  join auth.users u on u.id = p.id
  where lower(u.email) = lower(target_email)
  limit 1;
end;
$$;

create or replace function public.admin_set_profile_role(
  target_profile_id uuid,
  new_role text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid := (select auth.uid());
  v_current_role text;
begin
  if v_caller_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_caller_id and role = 'admin'
  ) then
    raise exception 'Admin privileges required';
  end if;

  if new_role not in ('customer', 'merchant', 'admin') then
    raise exception 'Invalid role: %', new_role;
  end if;

  select role into v_current_role
  from public.profiles
  where id = target_profile_id;

  if v_current_role is null then
    raise exception 'Profile not found';
  end if;

  if v_current_role = 'admin' and new_role <> 'admin' and (
    select count(*) from public.profiles where role = 'admin'
  ) <= 1 then
    raise exception 'Cannot remove the last remaining admin';
  end if;

  update public.profiles
  set role = new_role, updated_at = now()
  where id = target_profile_id;
end;
$$;

revoke all on function public.admin_lookup_profile_by_email(text)
  from public, anon;
grant execute on function public.admin_lookup_profile_by_email(text)
  to authenticated;

revoke all on function public.admin_set_profile_role(uuid, text)
  from public, anon;
grant execute on function public.admin_set_profile_role(uuid, text)
  to authenticated;
