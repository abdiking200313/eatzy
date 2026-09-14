-- Issue #36 ("[Blocking] No account-deletion capability anywhere in the
-- app") -- App Store Review Guideline 5.1.1(v) requires in-app account
-- deletion for any app that supports account creation (this app does, via
-- public.profiles + Supabase auth sign-up); Google Play requires an
-- equivalent path. Nothing in lib/ or supabase/ offered one before this.
--
-- ---------------------------------------------------------------------
-- Approach chosen: anonymize public.profiles + delete the user's other
-- owned PII-bearing rows. NOT a hard delete of auth.users.
-- ---------------------------------------------------------------------
--
-- The issue's own "What's needed" section explicitly allows either "removes
-- or anonymizes" the profile row -- anonymize is the one that actually works
-- from a client-callable RPC here, for two independent reasons:
--
--   1. auth.users deletion is normally done through Supabase's Auth Admin
--      API (`auth.admin.deleteUser`), which requires the service-role key.
--      A `security definer` Postgres function never has that key -- it can
--      only run SQL as its owning role. Even a raw
--      `delete from auth.users where id = ...` from inside such a function
--      would bypass Auth's own bookkeeping (identities, refresh tokens,
--      sessions) instead of going through the supported deletion path, so
--      it is not a safe substitute for the Admin API even where it would be
--      technically permitted.
--   2. Even if that were acceptable, it would not work uniformly: issue #80
--      (20260827103100_restrict_order_profile_deletes.sql) deliberately
--      changed food_orders/grocery_orders/pharmacy_orders' profile_id
--      foreign key from `on delete cascade` to `on delete restrict`
--      specifically so deleting an auth.users row is rejected while that
--      user still has order rows, instead of silently destroying their
--      order history. Any user with order history would make a hard
--      `auth.users` delete fail outright, so a real account-deletion
--      feature cannot rely on that path unconditionally.
--
-- So this RPC anonymizes public.profiles in place (clears the PII columns,
-- stamps `deleted_at`) and deletes the user's other owned, PII-bearing rows
-- that carry no historical/financial-record reason to be kept:
-- public.delivery_addresses, public.addresses, public.payment_methods,
-- public.wallet_transactions. All four are already scoped to
-- profile_id = auth.uid() by RLS (see supabase/schema.sql and
-- 20260917000000_add_shared_delivery_addresses.sql) -- this RPC deletes
-- through the same ownership column, just as security definer so a single
-- statement can do it without needing four separate authenticated calls.
--
-- public.food_orders / grocery_orders / pharmacy_orders are deliberately
-- LEFT UNTOUCHED: they are the order-history data issue #80 just finished
-- protecting from cascade deletion, or of a size/scope where in this app.
-- Their delivery_address_id foreign key is `on delete set null`, so deleting
-- the user's delivery_addresses rows above already detaches any that
-- referenced them without breaking the order rows. Scrubbing PII
-- (recipient_name/phone/street) out of historical order rows too is a
-- reasonable future hardening step but is out of scope for this issue --
-- flagged in the PR description as a fast-follow, not silently skipped.
--
-- auth.users itself is intentionally left in place. This means the login
-- credentials technically still exist after "deletion" -- a known
-- limitation of not having service-role access from this RPC -- but every
-- piece of personal data this RPC can reach (name, phone, avatar, saved
-- addresses, saved payment methods, wallet transaction descriptions) is
-- gone, and the Dart client signs the session out immediately after this
-- call succeeds (see ProfileRepository.deleteAccount's doc comment), so
-- there is no live session left pointed at the wiped profile. A true
-- `auth.users` removal needs a service-role edge function or an admin-side
-- job and is noted as a manual/product follow-up in the PR description.
--
-- ---------------------------------------------------------------------
-- Idempotency
-- ---------------------------------------------------------------------
--
-- Calling this twice for the same user is a safe no-op the second time:
-- once `deleted_at` is set, the function returns immediately without
-- re-running the deletes (which would be no-ops anyway, since the first
-- call already removed those rows) or re-stamping `updated_at`.
--
-- ---------------------------------------------------------------------
-- Security
-- ---------------------------------------------------------------------
--
-- `security definer` + `set search_path = ''` + fully schema-qualified
-- identifiers, matching every other security-definer RPC in this repo
-- (place_food_order/place_grocery_order/place_pharmacy_order). Operates
-- only on `(select auth.uid())` -- never accepts a user-id parameter, so
-- there is no way for one caller to delete another's account. Execute is
-- revoked from `public`/`anon` and granted only to `authenticated`, the
-- same ACL-restatement pattern the place_*_order migrations use.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Per this repo's migration convention, a human with access to the Supabase
-- project must run `supabase db push` (or apply this file directly) after
-- reviewing it -- this sandbox has no way to run migrations against a real
-- or local Postgres, so verify it against a real/staging database first.
-- ---------------------------------------------------------------------

set search_path = '';

alter table public.profiles
  add column if not exists deleted_at timestamptz;

create function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.profiles where id = v_profile_id
  ) then
    raise exception 'Profile not found';
  end if;

  -- Idempotent: a repeat call after the account is already anonymized is a
  -- silent no-op rather than an error or a redundant re-delete.
  if exists (
    select 1
    from public.profiles
    where id = v_profile_id and deleted_at is not null
  ) then
    return;
  end if;

  delete from public.delivery_addresses where profile_id = v_profile_id;
  delete from public.addresses where profile_id = v_profile_id;
  delete from public.payment_methods where profile_id = v_profile_id;
  delete from public.wallet_transactions where profile_id = v_profile_id;

  update public.profiles
  set firstname = 'Deleted',
      lastname = 'User',
      phone = null,
      avatar_url = null,
      deleted_at = now(),
      updated_at = now()
  where id = v_profile_id;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
