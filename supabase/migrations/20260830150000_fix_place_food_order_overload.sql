-- Issue #136: food checkout is broken for every user because
-- public.place_food_order exists as TWO overloads at once.
--
-- ---------------------------------------------------------------------
-- How the schema drifted
-- ---------------------------------------------------------------------
--
--   1. 20260727152319_connect_super_app_services.sql created
--      place_food_order(p_restaurant_id uuid, p_items jsonb).
--   2. 20260826200000_add_food_order_delivery_address.sql (issue #2) dropped
--      that 2-arg function and created the 7-arg address-taking signature
--      (p_restaurant_id, p_recipient_name, p_phone, p_street, p_district,
--      p_city, p_items) instead. Correct at the time: only one overload.
--   3. 20260827103000_harden_food_order_validation.sql (issue #77) then ran
--      `create or replace function place_food_order(p_restaurant_id uuid,
--      p_items jsonb)`. Because that argument list no longer matched the
--      live function, Postgres did not replace anything -- it RESURRECTED the
--      old 2-arg overload alongside the 7-arg one, and put #77's validation
--      hardening only on the 2-arg version that the client never calls.
--
-- Since (3) the database holds both overloads. The Dart client
-- (lib/services/food/models/food_models.dart, FoodOrderRequest.toRpcParams)
-- posts all seven named parameters, and PostgREST cannot resolve that call
-- against a candidate set containing an unrelated 2-arg function, so every
-- checkout fails with lib/services/food/presentation/food_controller.dart's
-- "The food order could not be saved. Please try again."
--
-- The resurrected 2-arg overload is also a privilege problem, not only a
-- resolution problem. #77 created it fresh, so it never picked up the
-- revoke/grant pair from #2 and carries the default ACL (PUBLIC EXECUTE) on a
-- SECURITY DEFINER function -- confirmed on the replayed chain:
--   place_food_order(uuid,jsonb)  -> (default: PUBLIC EXECUTE)
--   place_food_order(uuid,...)    -> postgres=X | authenticated=X
-- Any signed-in caller could therefore invoke the 2-arg version directly and
-- write a food_orders row with blank recipient/phone/street/district/city,
-- skipping the address validation entirely. Dropping it closes that too.
--
-- ---------------------------------------------------------------------
-- What this migration does
-- ---------------------------------------------------------------------
--
--   * Drops the stray 2-arg overload resurrected by #77.
--   * Re-issues the single 7-arg signature the client actually calls, this
--     time carrying #77's validation forward (it was lost by accident, not by
--     decision):
--       - restaurant open-state (public.restaurants.is_open)
--       - item availability (public.menu_items.is_available)
--       - per-item quantity ceiling of 99, matching
--         CartController.maximumQuantity
--       - ceiling of 100 on jsonb_array_length(p_items)
--     plus the delivery-address collection and validation from #2.
--   * Re-states revoke/grant, since dropping and recreating a function
--     resets its ACL.
--
-- No behavior other than place_food_order changes. place_grocery_order and
-- place_pharmacy_order are untouched (issue #76 tracks their validation).
--
-- ---------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------
--
-- Replayed supabase/schema.sql plus the full migration chain (including this
-- file) against a throwaway local Postgres 16 database and confirmed:
--   * pg_proc reports exactly ONE public.place_food_order overload afterward,
--     with argument list
--     (uuid, text, text, text, text, text, jsonb), where before this
--     migration it reported two;
--   * a valid order (real address + items) as the `authenticated` role with
--     auth.uid() set inserts one public.food_orders row with the address
--     columns populated and the matching public.food_order_items rows, and
--     returns the new order id;
--   * an unavailable menu item, a closed restaurant, a quantity of 100, a
--     101-element item array, a blank address field, a duplicate menu item,
--     an item from another restaurant and an unauthenticated call are each
--     rejected and write no rows.
--
-- THIS MIGRATION HAS NOT BEEN APPLIED TO ANY LIVE OR PRODUCTION DATABASE.
-- Food checkout stays broken in production until a human with access to the
-- Supabase project runs `supabase db push`. That deploy is urgent.
-- ---------------------------------------------------------------------

set search_path = '';

-- The stray overload from 20260827103000. Nothing calls it.
drop function if exists public.place_food_order(uuid, jsonb);

create or replace function public.place_food_order(
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
  if jsonb_array_length(p_items) > 100 then
    raise exception 'A food order cannot contain more than 100 items';
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
  where id = p_restaurant_id
    and is_open;

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
   and menu.is_available
  where input.quantity > 0
    and input.quantity <= 99;

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
   and menu.is_available
  where input.quantity > 0
    and input.quantity <= 99;

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
