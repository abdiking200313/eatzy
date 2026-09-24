-- Account deletion never worked from the app: the live delete_own_account()
-- set `profiles.phone = null`, but phone is NOT NULL, so every call raised
-- and rolled back. (The one live profile with `deleted_at` set still had its
-- real name and phone -- it was flagged some other way, not by this RPC.)
--
-- It also left personal data behind that this migration now clears, per the
-- owner's decision (2026-09-24, "anonymize fully + block login"):
--
--   * profiles: name -> 'Deleted User', phone -> '', dob/avatar -> null.
--     The row itself stays because orders reference it
--     (20260827103100_restrict_order_profile_deletes.sql).
--   * auth.users: signup copies firstname/lastname/phone/dob into
--     raw_user_meta_data (20260923000000), and the real email stays on the
--     login record. Both are wiped; the email becomes a unique placeholder,
--     which also frees the real address for a fresh sign-up.
--   * auth.identities: identity_data holds the email too; reduced to 'sub'.
--   * Login is blocked (banned_until) and every session/one-time token is
--     deleted, so neither the password nor an existing refresh token nor a
--     reset/confirmation link can get back in.
--
-- Order rows keep their delivery snapshot (recipient name/phone/address);
-- they are the store's transaction record and are out of scope here.
--
-- The work lives in private.anonymize_account(), a schema PostgREST does not
-- expose, so it cannot be called with an arbitrary user id. The public RPC
-- only ever passes auth.uid(). The backfill at the bottom runs it for any
-- profile already marked deleted.

set search_path = '';

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.anonymize_account(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.delivery_addresses where profile_id = p_profile_id;
  delete from public.payment_methods where profile_id = p_profile_id;
  delete from public.wallet_transactions where profile_id = p_profile_id;

  update public.profiles
  set firstname = 'Deleted',
      lastname = 'User',
      phone = '',
      dob = null,
      avatar_url = null,
      deleted_at = coalesce(deleted_at, now())
  where id = p_profile_id;

  update auth.users
  set email = 'deleted-' || p_profile_id::text || '@deleted.invalid',
      phone = null,
      raw_user_meta_data = '{}'::jsonb,
      email_change = '',
      email_change_token_new = '',
      email_change_token_current = '',
      phone_change = '',
      phone_change_token = '',
      confirmation_token = '',
      recovery_token = '',
      reauthentication_token = '',
      banned_until = now() + interval '100 years'
  where id = p_profile_id;

  update auth.identities
  set identity_data = jsonb_build_object('sub', provider_id)
  where user_id = p_profile_id;

  -- Cascades to auth.refresh_tokens and auth.mfa_amr_claims.
  delete from auth.sessions where user_id = p_profile_id;
  delete from auth.one_time_tokens where user_id = p_profile_id;
end;
$$;

revoke all on function private.anonymize_account(uuid)
  from public, anon, authenticated;

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
begin
  if v_profile_id is null then
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  if not exists (
    select 1 from public.profiles where id = v_profile_id
  ) then
    raise exception 'Profile not found'
      using errcode = 'P0002';
  end if;

  perform private.anonymize_account(v_profile_id);
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

-- Backfill: finish anonymizing accounts already marked deleted.
do $$
declare
  v_id uuid;
begin
  for v_id in
    select id from public.profiles where deleted_at is not null
  loop
    perform private.anonymize_account(v_id);
  end loop;
end;
$$;
