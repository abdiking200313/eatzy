-- Issue #80: order tables cascade-delete from auth.users — deleting a user
-- silently erases their entire order history.
--
-- ---------------------------------------------------------------------
-- Investigation (2026-08-27) — why 3 tables, not the 4 the issue names
-- ---------------------------------------------------------------------
--
--   * `20260727152319_connect_super_app_services.sql` originally created 4
--     tables with `profile_id uuid not null references auth.users(id) on
--     delete cascade`: food_orders, grocery_orders, pharmacy_orders, and
--     cleaning_bookings.
--   * `20260815153920_remove_cleaning_vertical.sql` (issue #50) dropped
--     `public.cleaning_bookings` entirely, along with the rest of the
--     cleaning vertical. It no longer exists in the current schema.
--   * No later migration re-adds a cleaning table or otherwise changes the
--     `profile_id` column/constraint on any order table.
--   * Verified against a fresh local Postgres 16 database with
--     `supabase/schema.sql` plus the full migration chain (through
--     `20260827090000_drop_client_trusted_order_tables.sql`) applied in
--     order: querying `pg_constraint`/`pg_class` for foreign keys into
--     `auth.users` on `public` tables returns exactly 4 rows —
--     `food_orders_profile_id_fkey`, `grocery_orders_profile_id_fkey`,
--     `pharmacy_orders_profile_id_fkey` (all `on delete cascade`, all in
--     scope here) and `profiles_id_fkey` (`public.profiles.id`, the intended
--     "delete the profile row when the auth user is deleted" relationship —
--     not an order-history table, out of scope for this issue).
--   * So today exactly 3 order tables carry the regression this issue
--     describes: food_orders, grocery_orders, pharmacy_orders.
--
--   * Checked `wallet_transactions`, `payment_methods`, and `addresses` too:
--     all three have `profile_id ... references public.profiles(id) on
--     delete cascade`, not a direct `auth.users` reference, so they are a
--     different (and, for a profile-scoped table, expected) relationship —
--     left untouched per the issue's explicit instruction not to assume.
--   * Order *item* tables (`food_order_items`, `grocery_order_items`,
--     `pharmacy_order_items`) cascade from their parent order row, not from
--     `auth.users` directly — also untouched, per the issue's instruction.
--
-- ---------------------------------------------------------------------
-- Fix
-- ---------------------------------------------------------------------
--
-- Change `profile_id`'s foreign key on each of the 3 tables from
-- `on delete cascade` to `on delete restrict`, so deleting an `auth.users`
-- row (fraud, support, a future account-deletion feature — issue #36) is
-- rejected with a foreign-key-violation while that user still has order
-- rows, instead of silently destroying their order history. This matches
-- `supabase/schema.sql`'s existing `on delete restrict` convention for
-- order-history data.
--
-- Constraints are looked up by catalog (`pg_constraint`/`pg_class`) rather
-- than assumed by name, since the column was declared as an inline,
-- unnamed foreign key and Postgres's auto-generated name
-- (`<table>_profile_id_fkey`) is an implementation detail, not a guarantee.
-- Verified directly against the fixture database described above: the
-- generated names are exactly `food_orders_profile_id_fkey`,
-- `grocery_orders_profile_id_fkey`, and `pharmacy_orders_profile_id_fkey`,
-- but this migration does not rely on that holding true everywhere.
--
-- Safety: this migration only changes a delete rule; it does not drop or
-- alter any data. It has NOT been applied to any live/production database —
-- applying it there is a deliberate manual follow-up, per this repo's
-- migration convention.
-- ---------------------------------------------------------------------

do $$
declare
  fk_name text;
  target_table text;
begin
  foreach target_table in array array[
    'food_orders',
    'grocery_orders',
    'pharmacy_orders'
  ]
  loop
    if to_regclass('public.' || target_table) is null then
      raise notice 'Skipping %: table does not exist', target_table;
      continue;
    end if;

    select con.conname
    into fk_name
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = target_table
      and con.contype = 'f'
      and con.confrelid = 'auth.users'::regclass
      and con.conkey = array[
        (
          select attnum
          from pg_attribute
          where attrelid = rel.oid and attname = 'profile_id'
        )
      ];

    if fk_name is null then
      raise exception
        'Expected a profile_id -> auth.users foreign key on public.%, none found',
        target_table;
    end if;

    execute format(
      'alter table public.%I drop constraint %I',
      target_table,
      fk_name
    );
    execute format(
      'alter table public.%I '
        || 'add constraint %I '
        || 'foreign key (profile_id) references auth.users(id) '
        || 'on delete restrict',
      target_table,
      fk_name
    );
  end loop;
end
$$;
