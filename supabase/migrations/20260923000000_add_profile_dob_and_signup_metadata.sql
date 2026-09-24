-- Registration now collects four required fields on RegisterScreen -- first
-- name, last name, phone and date of birth -- and passes them to
-- `auth.signUp(..., data: {...})` as user metadata (lib/features/auth/data/
-- auth_service.dart). Two things have to change server-side for those values
-- to actually land on the profile row:
--
--   1. `public.profiles` has no `dob` column at all (see the live snapshot in
--      supabase/schema.sql: id, firstname, lastname, phone, avatar_url, role,
--      deleted_at). Added here as a nullable `date` -- accounts created before
--      this migration predate the field and there is no real value to backfill
--      them with, so null means "never asked", not "invalid". firstname /
--      lastname / phone keep their existing NOT NULL constraints.
--
--   2. `public.handle_new_user()` (20260921010000) hardcoded empty-string
--      placeholders for firstname/lastname/phone, because at the time nothing
--      collected them at sign-up. It now reads `new.raw_user_meta_data`
--      instead, using the exact keys the client sends: 'firstname',
--      'lastname', 'phone', 'dob' (the last as a 'yyyy-MM-dd' string).
--
-- The reads stay defensive. An account created outside the app -- via the
-- Supabase dashboard, an admin API call, or an OAuth provider -- carries none
-- of this metadata, and the trigger must not fail in that case or the whole
-- `auth.users` insert rolls back and the sign-up errors out. So the three NOT
-- NULL text columns fall back to '' exactly as before, and `dob` falls back to
-- null (`nullif(..., '')` so that a present-but-blank string is treated as
-- absent rather than fed to a failing date cast).
--
-- The function keeps `security definer` and `set search_path = ''` for the
-- same reasons as the original: it writes `public.profiles`, which has only a
-- SELECT policy ("Customers read own profile") and no insert policy, so the
-- insert has to run with the definer's rights; and an empty search_path stops
-- a caller-controlled path from resolving `profiles` to some other schema.
-- `role` is still left unset so it picks up its own 'customer' default.
--
-- RLS on `public.profiles` is unchanged and needs no restatement: the existing
-- policy is row-level, not column-level, so it already covers `dob`. Nothing
-- grants the client a direct write path to the new column -- it is only ever
-- set by this trigger.
--
-- `create trigger` is re-issued below purely to match the structure of
-- 20260921010000; `create or replace function` swaps the body in place, so the
-- existing `on_auth_user_created` trigger would pick up the new definition
-- either way. No backfill: the metadata for existing users does not exist.

set search_path = '';

alter table public.profiles
  add column if not exists dob date;

comment on column public.profiles.dob is
  'Date of birth captured at registration. Nullable -- accounts created before the field was added, or outside the app (dashboard/admin API), have no value.';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, firstname, lastname, phone, dob)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'firstname', ''),
    coalesce(new.raw_user_meta_data->>'lastname', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    nullif(new.raw_user_meta_data->>'dob', '')::date
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
