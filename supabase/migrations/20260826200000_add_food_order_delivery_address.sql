-- Food checkout never collected a real delivery address (issue #2).
-- `food_orders` had no recipient/address columns at all, unlike
-- `grocery_orders` (recipient_name, phone, street, district, city) and
-- `pharmacy_orders` (customer_name, phone_number, city, district,
-- address_line). This migration brings food orders in line with that
-- existing pattern.
--
-- NOTE: this migration is new and has not been applied to any live/
-- production database. Applying it is a manual follow-up for a human with
-- access to the Supabase project (see PR description).

alter table public.food_orders
  add column recipient_name text not null default '',
  add column phone text not null default '',
  add column street text not null default '',
  add column district text not null default '',
  add column city text not null default '';

-- `place_food_order`'s signature changes (new required parameters), so the
-- old function must be dropped before being recreated; `create or replace`
-- cannot change a function's parameter list.
drop function if exists public.place_food_order(uuid, jsonb);

create function public.place_food_order(
  p_restaurant_id uuid,
  p_recipient_name text,
  p_phone text,
  p_street text,
  p_district text,
  p_city text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_order_id uuid;
  v_restaurant_name text;
  v_input_count integer;
  v_valid_count integer;
  v_unique_count integer;
  v_subtotal numeric(12, 2);
  v_delivery_fee numeric(12, 2) := 4.99;
  v_tax numeric(12, 2);
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'A food order requires at least one item';
  end if;
  if coalesce(trim(p_recipient_name), '') = ''
     or coalesce(trim(p_phone), '') = ''
     or coalesce(trim(p_street), '') = ''
     or coalesce(trim(p_district), '') = ''
     or coalesce(trim(p_city), '') = '' then
    raise exception 'Complete food delivery details are required';
  end if;

  select name
  into v_restaurant_name
  from public.restaurants
  where id = p_restaurant_id;

  if v_restaurant_name is null then
    raise exception 'Restaurant not found';
  end if;

  v_input_count := jsonb_array_length(p_items);

  select
    count(*)::integer,
    count(distinct input.menu_item_id)::integer,
    coalesce(sum(menu.price * input.quantity), 0)
  into v_valid_count, v_unique_count, v_subtotal
  from jsonb_to_recordset(p_items)
    as input(menu_item_id uuid, quantity integer)
  join public.menu_items menu
    on menu.id = input.menu_item_id
   and menu.restaurant_id = p_restaurant_id
  where input.quantity > 0;

  if v_valid_count <> v_input_count
     or v_unique_count <> v_input_count
     or v_subtotal <= 0 then
    raise exception 'Food order contains invalid items';
  end if;

  v_tax := round(v_subtotal * 0.10, 2);

  insert into public.food_orders (
    profile_id,
    restaurant_id,
    restaurant_name,
    recipient_name,
    phone,
    street,
    district,
    city,
    subtotal,
    delivery_fee,
    tax,
    total
  )
  values (
    v_profile_id,
    p_restaurant_id,
    v_restaurant_name,
    trim(p_recipient_name),
    trim(p_phone),
    trim(p_street),
    trim(p_district),
    trim(p_city),
    v_subtotal,
    v_delivery_fee,
    v_tax,
    v_subtotal + v_delivery_fee + v_tax
  )
  returning id into v_order_id;

  insert into public.food_order_items (
    order_id,
    menu_item_id,
    item_name,
    quantity,
    unit_price
  )
  select
    v_order_id,
    menu.id,
    menu.name,
    input.quantity,
    menu.price
  from jsonb_to_recordset(p_items)
    as input(menu_item_id uuid, quantity integer)
  join public.menu_items menu
    on menu.id = input.menu_item_id
   and menu.restaurant_id = p_restaurant_id
  where input.quantity > 0;

  return v_order_id;
end;
$$;

revoke all on function public.place_food_order(
  uuid,
  text,
  text,
  text,
  text,
  text,
  jsonb
)
from public, anon;

grant execute on function public.place_food_order(
  uuid,
  text,
  text,
  text,
  text,
  text,
  jsonb
)
to authenticated;
