-- Fresh Meat and Electronics run on the grocery engine.
--
-- Rather than two new verticals (own tables, order RPCs, merchant flows),
-- a grocery store now carries a store_type. The customer app opens one
-- store list per type (Grocery / Fresh Meat / Electronics); cart, checkout,
-- place_grocery_order and the merchant tools are unchanged and shared.
--
-- Existing stores default to 'grocery'. To move a store into another
-- category:
--   update public.grocery_stores set store_type = 'fresh_meat' where id = '...';

set search_path = '';

alter table public.grocery_stores
  add column if not exists store_type text not null default 'grocery';

alter table public.grocery_stores
  drop constraint if exists grocery_stores_store_type_check;
alter table public.grocery_stores
  add constraint grocery_stores_store_type_check
  check (store_type in ('grocery', 'fresh_meat', 'electronics'));

create index if not exists grocery_stores_store_type_idx
  on public.grocery_stores (store_type)
  where is_active;

comment on column public.grocery_stores.store_type is
  'Which customer category lists this store: grocery, fresh_meat or electronics.';
