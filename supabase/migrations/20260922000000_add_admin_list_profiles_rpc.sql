-- Requested directly by the app owner, 2026-09-18: the admin's "Accounts"
-- screen should be a paginated, searchable list of every account (name,
-- email, role) with a role dropdown per row, instead of the earlier
-- one-account-at-a-time email lookup.
--
-- ---------------------------------------------------------------------
-- What this does
-- ---------------------------------------------------------------------
--
--   1. Adds `public.admin_list_profiles(search_text, page_limit,
--      page_offset)`: returns a page of profiles joined with their sign-up
--      email (only stored on `auth.users`), newest sign-up first. Optional
--      `search_text` matches, case-insensitively, anywhere in the email or
--      in "firstname lastname". Soft-deleted accounts (`deleted_at is not
--      null`, see `20260919000000_add_delete_own_account_rpc.sql`) are
--      excluded. `page_limit` is clamped to 1..100.
--   2. Fixes `public.admin_set_profile_role`, which
--      `20260921020000_add_admin_role_management_rpcs.sql` defined with
--      `set role = new_role, updated_at = now()`. The live
--      `public.profiles` table has no `updated_at` column, so every call
--      failed with `column "updated_at" of relation "profiles" does not
--      exist` and no role could ever be changed from the app. Where a table
--      does have `updated_at`, `set_updated_at()` (see
--      `20260827100000_add_updated_at_triggers.sql`) stamps it via a trigger
--      anyway, so dropping the explicit assignment is correct either way.
--
-- Like the other admin RPCs: `security definer`, `set search_path = ''`,
-- fully schema-qualified identifiers, and an in-function check that the
-- *caller* has `profiles.role = 'admin'`. Execute is revoked from
-- `public`/`anon` and granted only to `authenticated`.
--
-- `admin_lookup_profile_by_email` (from the earlier migration) is left in
-- place; the app no longer calls it.

set search_path = '';

create or replace function public.admin_list_profiles(
  search_text text default null,
  page_limit integer default 25,
  page_offset integer default 0
)
returns table (
  id uuid,
  firstname text,
  lastname text,
  email text,
  role text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid := (select auth.uid());
  v_search text := nullif(btrim(coalesce(search_text, '')), '');
  v_limit integer := least(greatest(coalesce(page_limit, 25), 1), 100);
  v_offset integer := greatest(coalesce(page_offset, 0), 0);
begin
  if v_caller_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = v_caller_id and pr.role = 'admin'
  ) then
    raise exception 'Admin privileges required';
  end if;

  return query
  select p.id, p.firstname, p.lastname, u.email::text, p.role
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.deleted_at is null
    and (
      v_search is null
      or strpos(lower(u.email::text), lower(v_search)) > 0
      or strpos(
        lower(btrim(coalesce(p.firstname, '') || ' ' || coalesce(p.lastname, ''))),
        lower(v_search)
      ) > 0
    )
  order by u.created_at desc, p.id
  limit v_limit offset v_offset;
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
  set role = new_role
  where id = target_profile_id;
end;
$$;

revoke all on function public.admin_list_profiles(text, integer, integer)
  from public, anon;
grant execute on function public.admin_list_profiles(text, integer, integer)
  to authenticated;

revoke all on function public.admin_set_profile_role(uuid, text)
  from public, anon;
grant execute on function public.admin_set_profile_role(uuid, text)
  to authenticated;
