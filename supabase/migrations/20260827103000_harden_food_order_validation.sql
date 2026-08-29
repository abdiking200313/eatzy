-- Issue #77: place_food_order skipped validation its grocery and pharmacy
-- siblings both have. Bring it up to the same standard:
--   * item availability: public.menu_items.is_available
--   * restaurant open-state: public.restaurants.is_open
--     (both columns already exist on the live schema, see supabase/schema.sql;
--     no new column is introduced by this migration)
--   * a per-item quantity ceiling of 99, matching the client-side cap in
--     lib/features/cart/presentation/cart_controller.dart
--     (CartController.maximumQuantity)
--   * a ceiling of 100 on jsonb_array_length(p_items). Neither
--     place_grocery_order nor place_pharmacy_order bounds the item-array
--     length today (issue #76 tracks their validation separately), so 100 is
--     a standalone, conservative default here rather than a value matched to
--     a sibling.
--
-- Only public.place_food_order is touched. place_grocery_order and
-- place_pharmacy_order are intentionally left untouched (issue #76).

create or replace function public.place_food_order(
  p_restaurant_id uuid,
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
    subtotal,
    delivery_fee,
    tax,
    total
  )
  values (
    v_profile_id,
    p_restaurant_id,
    v_restaurant_name,
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
