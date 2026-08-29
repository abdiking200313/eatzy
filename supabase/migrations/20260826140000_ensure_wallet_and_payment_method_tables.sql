-- Backfills two tables that are documented in supabase/schema.sql but were
-- never actually created by any migration in this chain:
-- `wallet_transactions` and `payment_methods`. Issue #1 ("Wallet screen is
-- entirely fake/static") wires the wallet UI to a real WalletRepository
-- reading from both — this migration is what guarantees they actually exist
-- with the schema/RLS the repository assumes, instead of relying on the
-- stale doc file having been applied out-of-band at some point.
--
-- Every statement is idempotent (guarded with IF NOT EXISTS / a pg_type
-- check / DROP POLICY IF EXISTS) so it is safe to run whether or not the
-- tables already exist live.
--
-- Deliberately read-only for both tables: only SELECT policies are added,
-- matching supabase/schema.sql exactly. Neither table has a secure
-- SECURITY DEFINER write path (unlike order placement's
-- place_food_order/place_grocery_order/place_pharmacy_order RPCs), so no
-- INSERT/UPDATE/DELETE policy is granted here. Adding one would let a
-- client fabricate arbitrary wallet credits or payment-method rows directly
-- — that is out of scope for this issue and is called out as a follow-up in
-- the PR description instead of being guessed at here.

do $$
begin
  if not exists (
    select 1 from pg_type where typname = 'wallet_transaction_type'
  ) then
    create type public.wallet_transaction_type as enum (
      'top_up',
      'order_payment',
      'refund',
      'adjustment'
    );
  end if;
end
$$;

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  type public.wallet_transaction_type not null,
  amount integer not null,
  description text not null,
  created_at timestamptz not null default now()
);

create index if not exists wallet_transactions_profile_id_idx
  on public.wallet_transactions(profile_id);

alter table public.wallet_transactions enable row level security;

drop policy if exists "Wallet transactions belong to owner"
  on public.wallet_transactions;

create policy "Wallet transactions belong to owner"
on public.wallet_transactions for select
using (auth.uid() = profile_id);

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null,
  brand text not null,
  last_four text not null check (char_length(last_four) = 4),
  provider_payment_method_id text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists payment_methods_profile_id_idx
  on public.payment_methods(profile_id);

alter table public.payment_methods enable row level security;

drop policy if exists "Payment methods belong to owner"
  on public.payment_methods;

create policy "Payment methods belong to owner"
on public.payment_methods for select
using (auth.uid() = profile_id);
