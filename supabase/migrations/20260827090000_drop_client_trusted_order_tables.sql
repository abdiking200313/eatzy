-- Issue #75: remove the client-trusting legacy order-insert path defined by
-- `supabase/schema.sql`, and tighten two over-broad policies it also defines.
--
-- ---------------------------------------------------------------------
-- Investigation (2026-08-27) — why removal rather than a new RPC
-- ---------------------------------------------------------------------
--
--   * `supabase/schema.sql` is a standalone provisioning script ("Run this in
--     the Supabase SQL editor after creating the project"), not a generated
--     dump of this migration chain. The tables it defines are disjoint from
--     everything under `supabase/migrations/`: no migration in this repo
--     references public.orders, public.order_items, public.carts,
--     public.cart_items, public.order_events, public.payment_methods or
--     public.delivery_partners.
--
--   * A grep of `lib/` and `test/` finds zero Dart references to `orders`,
--     `order_items`, `carts`, `cart_items` or `order_events` — no
--     `.from('<table>')`, no `.rpc()` touching them, no interpolated table
--     name. The live app places orders exclusively through the SECURITY
--     DEFINER RPCs place_food_order / place_grocery_order /
--     place_pharmacy_order, and reads the per-vertical public.food_orders /
--     public.grocery_orders / public.pharmacy_orders tables plus the
--     public.customer_activity view. `supabase/seed.sql` likewise only seeds
--     the per-vertical tables. The generic order/cart model is dead code.
--
--   * schema.sql's `"Customers create their own orders"` (orders) and
--     `"Customers insert items for own orders"` (order_items) insert policies
--     check ownership (auth.uid() = profile_id) and nothing else, so anyone
--     holding the public anon key could POST /rest/v1/orders with
--     subtotal/delivery_fee/tax/total of their choosing and matching
--     order_items rows at any unit_price/quantity. Because the tables have no
--     readers, the correct fix is deletion, not another SECURITY DEFINER RPC
--     duplicating place_food_order.
--
-- ---------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE by
-- the change that adds this file. It is a reviewable artifact only; applying
-- it is a deliberate manual follow-up.
--
-- It is destructive by design (it drops tables). Every statement is guarded
-- and idempotent, because these objects exist only where schema.sql was run
-- out-of-band — they are not created by any migration here. Take a backup
-- before applying to any database that might hold real rows in these tables:
-- the investigation above establishes that no *client* writes them, not that
-- no historical rows exist.

-- ---------------------------------------------------------------------
-- 1. Detach public.wallet_transactions from public.orders.
--
-- wallet_transactions.order_id is the only foreign key into public.orders
-- from a table that is NOT being dropped (it is read by the wallet feature).
-- Keep the column and its data, drop only the constraint: the per-vertical
-- order tables mean an order id can now live in food_orders, grocery_orders
-- or pharmacy_orders, so a single-target FK is no longer the right model.
-- Looked up by catalog rather than by assumed name so this works regardless
-- of what the constraint ended up called.
-- ---------------------------------------------------------------------

do $$
declare
  fk_name text;
begin
  if to_regclass('public.wallet_transactions') is null then
    return;
  end if;

  for fk_name in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'wallet_transactions'
      and con.contype = 'f'
      and con.confrelid = to_regclass('public.orders')
  loop
    execute format(
      'alter table public.wallet_transactions drop constraint %I',
      fk_name
    );
  end loop;
end
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'wallet_transactions'
      and column_name = 'order_id'
  ) then
    execute $comment$
      comment on column public.wallet_transactions.order_id is
        'Unconstrained order reference. The referenced row lives in one of public.food_orders, public.grocery_orders or public.pharmacy_orders; the public.orders table this used to reference was dropped as dead code in issue #75.'
    $comment$;
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- 2. Drop the dead client-trusted order/cart model.
--
-- Dropping each table also drops its RLS policies, including the two
-- price-blind insert policies this issue is about. Order matters: children
-- before parents, so no `cascade` is needed and nothing unexpected can be
-- silently taken down with them.
-- ---------------------------------------------------------------------

drop table if exists public.order_items;
drop table if exists public.order_events;
drop table if exists public.orders;
drop table if exists public.cart_items;
drop table if exists public.carts;

-- These enum types existed only to type columns on the tables above.
drop type if exists public.order_status;
drop type if exists public.cart_status;

-- ---------------------------------------------------------------------
-- 3. public.payment_methods — replace the `for all` policy with read-only,
--    owner-scoped access, and stop exposing the provider token.
--
-- This table is NOT dead: the wallet feature reads it (brand / last_four /
-- is_default). But schema.sql's `"Payment methods belong to owner"` policy is
-- `for all`, so ownership-scoping alone let a client insert or rewrite its
-- own rows — including `provider_payment_method_id`, a payment-provider
-- token that should only ever be written server-side after a real provider
-- handshake.
--
-- Reads stay; writes are removed entirely. There is no secure write path for
-- payment methods yet (unlike order placement's SECURITY DEFINER RPCs), and
-- the wallet UI already treats "add a payment method" as not-yet-built, so
-- granting no write is the honest state rather than a regression. Adding a
-- payment method needs a SECURITY DEFINER RPC that performs the provider
-- handshake and writes the token itself — tracked as follow-up, deliberately
-- not guessed at here.
--
-- Column-level grants back the row-level policy up: `provider_payment_method_id`
-- is not selectable by `authenticated` at all. Postgres ignores column
-- privileges while a table-wide grant is present, so the table-wide grant is
-- revoked first and the safe columns re-granted individually. service_role
-- and the table owner are untouched.
-- ---------------------------------------------------------------------

do $$
begin
  if to_regclass('public.payment_methods') is null then
    return;
  end if;

  execute 'alter table public.payment_methods enable row level security';

  -- Both the schema.sql name and the name used by the wallet migration.
  execute 'drop policy if exists "Payment methods belong to owner" on public.payment_methods';
  execute 'drop policy if exists "Owners read own payment methods" on public.payment_methods';

  execute $policy$
    create policy "Owners read own payment methods"
    on public.payment_methods for select
    to authenticated
    using ((select auth.uid()) = profile_id)
  $policy$;

  execute 'revoke all on public.payment_methods from public, anon, authenticated';
  execute
    'grant select (id, profile_id, provider, brand, last_four, is_default, created_at) '
    || 'on public.payment_methods to authenticated';
end
$$;

-- ---------------------------------------------------------------------
-- 4. public.delivery_partners — stop publishing every courier's name and
--    phone number to every signed-in user.
--
-- schema.sql's `"Delivery partners are visible for tracking"` policy is
-- `for select to authenticated using (is_active = true)`, i.e. any signed-in
-- account can read the full_name and phone of every active partner. The
-- intended scoping is "only the partner(s) attached to the requesting user's
-- own active orders" — but the only column that ever linked a profile to a
-- partner was public.orders.delivery_partner_id, and public.orders is dropped
-- above as dead. None of food_orders / grocery_orders / pharmacy_orders has a
-- delivery-partner column, so today that scoped set is provably empty for
-- every user.
--
-- Deny-by-default (RLS enabled, no policy, no grants to anon/authenticated)
-- is therefore the exact implementation of that scoping against the schema as
-- it actually exists. The table and its rows are kept, not dropped, so a real
-- courier-assignment feature can add an assignment column/table and a policy
-- scoped through it rather than re-inventing the table.
-- ---------------------------------------------------------------------

do $$
begin
  if to_regclass('public.delivery_partners') is null then
    return;
  end if;

  execute 'alter table public.delivery_partners enable row level security';
  execute
    'drop policy if exists "Delivery partners are visible for tracking" '
    || 'on public.delivery_partners';
  execute 'revoke all on public.delivery_partners from public, anon, authenticated';
end
$$;
