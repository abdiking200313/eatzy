-- Settings screen profile editing: users edit their first name, last name,
-- phone and date of birth one field at a time (bottom sheets). Before this
-- migration that feature was silently broken in production:
--
--   * RLS is enabled on public.profiles and the ONLY policy is
--     "Customers read own profile" (SELECT, auth.uid() = id). There is no
--     UPDATE policy, so the client's direct `.from('profiles').update(...)`
--     matches 0 rows and reports no error.
--
-- ---------------------------------------------------------------------
-- Why an RPC and not an owner UPDATE policy
-- ---------------------------------------------------------------------
--
-- The `authenticated` role currently holds column-level UPDATE grants on
-- every column of public.profiles, including `role`, `id` and `deleted_at`.
-- That is harmless today only because no UPDATE policy exists. Adding a
-- row-level "owner can update own row" policy would immediately let any
-- signed-in user set their own `role` to 'admin' (or un-delete themselves by
-- clearing `deleted_at`). So the write path is a `security definer` RPC that
-- only ever touches firstname / lastname / phone / dob, matching this repo's
-- convention for client writes (place_*_order, delete_own_account).
--
-- Tightening those broad column grants (revoke update on public.profiles
-- from authenticated, anon) is a separate hardening follow-up and is
-- deliberately NOT done here.
--
-- ---------------------------------------------------------------------
-- Semantics
-- ---------------------------------------------------------------------
--
--   * A NULL parameter means "leave this column unchanged", so a per-field
--     edit sends only that field, and legacy accounts with an empty phone /
--     null dob can still edit their name without supplying the rest.
--   * All four parameters NULL -> error ('nothing to update').
--   * Text values are trimmed. firstname / lastname must be non-empty after
--     trimming. phone must match ^\+?[0-9 -]{7,15}$ after trimming (the same
--     rule as RegisterScreen's client regex ^\+?[0-9\s-]{7,15}$). dob must
--     not be in the future. Validation failures raise SQLSTATE 22023
--     (invalid_parameter_value).
--   * Only the caller's own, non-deleted profile is updated
--     (id = auth.uid() and deleted_at is null); if no such row exists the
--     call errors rather than silently succeeding.
--   * Returns the updated row (id, firstname, lastname, phone, avatar_url,
--     dob) so the client can refresh its local state from the server's
--     normalized (trimmed) values.
--
-- ---------------------------------------------------------------------
-- Security
-- ---------------------------------------------------------------------
--
-- `security definer` + `set search_path = ''` + fully schema-qualified
-- identifiers, matching the other security-definer RPCs in this repo.
-- Never accepts a user-id parameter -- operates only on
-- `(select auth.uid())`. `#variable_conflict use_column` plus the `p` table
-- alias keep the `returns table` output names (id, firstname, ...) from
-- colliding with profiles' columns. Execute is revoked from public/anon and
-- granted only to authenticated.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- A human with access to the Supabase project must review and apply it.
-- ---------------------------------------------------------------------

set search_path = '';

create or replace function public.update_own_profile(
  p_firstname text default null,
  p_lastname  text default null,
  p_phone     text default null,
  p_dob       date default null
)
returns table (
  id uuid,
  firstname text,
  lastname text,
  phone text,
  avatar_url text,
  dob date
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_profile_id uuid := (select auth.uid());
  v_firstname text := btrim(p_firstname);
  v_lastname text := btrim(p_lastname);
  v_phone text := btrim(p_phone);
begin
  if v_profile_id is null then
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  if p_firstname is null
     and p_lastname is null
     and p_phone is null
     and p_dob is null then
    raise exception 'Nothing to update'
      using errcode = '22023';
  end if;

  if v_firstname is not null and v_firstname = '' then
    raise exception 'First name must not be empty'
      using errcode = '22023';
  end if;

  if v_lastname is not null and v_lastname = '' then
    raise exception 'Last name must not be empty'
      using errcode = '22023';
  end if;

  if v_phone is not null and v_phone !~ '^\+?[0-9 -]{7,15}$' then
    raise exception 'Phone number is invalid'
      using errcode = '22023';
  end if;

  if p_dob is not null and p_dob > current_date then
    raise exception 'Date of birth must not be in the future'
      using errcode = '22023';
  end if;

  return query
  update public.profiles as p
  set firstname = coalesce(v_firstname, p.firstname),
      lastname = coalesce(v_lastname, p.lastname),
      phone = coalesce(v_phone, p.phone),
      dob = coalesce(p_dob, p.dob)
  where p.id = v_profile_id
    and p.deleted_at is null
  returning p.id, p.firstname, p.lastname, p.phone, p.avatar_url, p.dob;

  if not found then
    raise exception 'Profile not found'
      using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.update_own_profile(text, text, text, date)
  from public, anon;
grant execute on function public.update_own_profile(text, text, text, date)
  to authenticated;
