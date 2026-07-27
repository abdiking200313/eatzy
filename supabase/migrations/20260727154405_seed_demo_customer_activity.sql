-- Demo transaction history for the first existing customer profile.
-- This is skipped on fresh environments that do not yet have a profile.
-- Delivery fields are immutable fulfilment snapshots, not reusable addresses.

do $$
declare
  v_profile_id uuid;

  v_food_order_id uuid;
  v_restaurant_id uuid;
  v_restaurant_name text;
  v_menu_item_id uuid;
  v_menu_item_name text;
  v_menu_item_price numeric(12, 2);
  v_food_subtotal numeric(12, 2);
  v_food_tax numeric(12, 2);

  v_grocery_order_id uuid;
  v_store_name text;
  v_grocery_product_name text;
  v_grocery_pricing_unit text;
  v_grocery_price numeric(12, 2);
  v_grocery_slot_label text;

  v_pharmacy_order_id uuid;
  v_pharmacy_product_name text;
  v_pharmacy_price numeric(12, 2);

  v_cleaning_service_name text;
  v_cleaning_hourly_rate numeric(12, 2);
  v_cleaning_duration smallint;
  v_professional_id text;
  v_professional_name text;
  v_cleaning_start timestamptz;
begin
  select id
  into v_profile_id
  from public.profiles
  order by id
  limit 1;

  if v_profile_id is null then
    return;
  end if;

  select
    restaurant.id,
    restaurant.name,
    item.id,
    item.name,
    item.price
  into
    v_restaurant_id,
    v_restaurant_name,
    v_menu_item_id,
    v_menu_item_name,
    v_menu_item_price
  from public.restaurants restaurant
  join public.menu_items item on item.restaurant_id = restaurant.id
  order by restaurant.id, item.id
  limit 1;

  if v_menu_item_id is not null then
    v_food_subtotal := v_menu_item_price * 2;
    v_food_tax := round(v_food_subtotal * 0.10, 2);

    insert into public.food_orders (
      profile_id,
      restaurant_id,
      restaurant_name,
      status,
      subtotal,
      delivery_fee,
      tax,
      total,
      created_at,
      updated_at
    )
    values (
      v_profile_id,
      v_restaurant_id,
      v_restaurant_name,
      'delivered',
      v_food_subtotal,
      4.99,
      v_food_tax,
      v_food_subtotal + 4.99 + v_food_tax,
      now() - interval '4 days',
      now() - interval '4 days'
    )
    returning id into v_food_order_id;

    insert into public.food_order_items (
      order_id,
      menu_item_id,
      item_name,
      quantity,
      unit_price,
      created_at
    )
    values (
      v_food_order_id,
      v_menu_item_id,
      v_menu_item_name,
      2,
      v_menu_item_price,
      now() - interval '4 days'
    );
  end if;

  select
    store.name,
    product.name,
    product.pricing_unit,
    product.unit_price,
    slot.label || ', ' || slot.detail
  into
    v_store_name,
    v_grocery_product_name,
    v_grocery_pricing_unit,
    v_grocery_price,
    v_grocery_slot_label
  from public.grocery_stores store
  join public.grocery_products product on product.store_id = store.id
  join public.grocery_delivery_slots slot on slot.store_id = store.id
  where store.id = 'bakaal-fresh'
    and product.id = 'bakaal-rice'
    and slot.id = 'bakaal-today-afternoon';

  if v_grocery_product_name is not null then
    insert into public.grocery_orders (
      profile_id,
      store_id,
      store_name,
      delivery_slot_id,
      delivery_slot_label,
      delivery_window_start,
      delivery_window_end,
      recipient_name,
      phone,
      street,
      district,
      city,
      substitution_preference,
      status,
      subtotal,
      delivery_fee,
      total,
      created_at,
      updated_at
    )
    values (
      v_profile_id,
      'bakaal-fresh',
      v_store_name,
      'bakaal-today-afternoon',
      v_grocery_slot_label,
      now() - interval '3 days',
      now() - interval '3 days' + interval '2 hours',
      'Demo Customer',
      '+252 61 000 0000',
      'Demo fulfilment location',
      'Hodan',
      'Mogadishu',
      'best_match',
      'delivered',
      v_grocery_price,
      2.50,
      v_grocery_price + 2.50,
      now() - interval '4 days',
      now() - interval '3 days'
    )
    returning id into v_grocery_order_id;

    insert into public.grocery_order_items (
      order_id,
      product_id,
      product_name,
      pricing_unit,
      quantity,
      unit_price,
      created_at
    )
    values (
      v_grocery_order_id,
      'bakaal-rice',
      v_grocery_product_name,
      v_grocery_pricing_unit,
      1,
      v_grocery_price,
      now() - interval '4 days'
    );
  end if;

  select name, unit_price
  into v_pharmacy_product_name, v_pharmacy_price
  from public.pharmacy_products
  where id = 'pain-paracetamol'
    and sale_type = 'otc';

  if v_pharmacy_product_name is not null then
    insert into public.pharmacy_orders (
      profile_id,
      customer_name,
      phone_number,
      city,
      district,
      address_line,
      delivery_instructions,
      status,
      subtotal,
      delivery_fee,
      total,
      created_at,
      updated_at
    )
    values (
      v_profile_id,
      'Demo Customer',
      '+252 61 000 0000',
      'Mogadishu',
      'Hodan',
      'Demo fulfilment location',
      'Demo order only',
      'delivered',
      v_pharmacy_price,
      2.50,
      v_pharmacy_price + 2.50,
      now() - interval '3 days',
      now() - interval '2 days'
    )
    returning id into v_pharmacy_order_id;

    insert into public.pharmacy_order_items (
      order_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      created_at
    )
    values (
      v_pharmacy_order_id,
      'pain-paracetamol',
      v_pharmacy_product_name,
      1,
      v_pharmacy_price,
      now() - interval '3 days'
    );
  end if;

  select
    service.name,
    service.hourly_rate,
    duration.duration_hours,
    professional.id,
    professional.display_name
  into
    v_cleaning_service_name,
    v_cleaning_hourly_rate,
    v_cleaning_duration,
    v_professional_id,
    v_professional_name
  from public.cleaning_services service
  join public.cleaning_service_durations duration
    on duration.service_id = service.id
  join public.cleaning_professional_services skill
    on skill.service_id = service.id
  join public.cleaning_professionals professional
    on professional.id = skill.professional_id
  where service.id = 'standard-home'
    and professional.id = 'cleaner-amina'
  order by duration.duration_hours
  limit 1;

  if v_professional_id is not null then
    v_cleaning_start := (
      (
        (now() at time zone 'Africa/Mogadishu')::date
          - 1
          + time '10:00'
      ) at time zone 'Africa/Mogadishu'
    );

    insert into public.cleaning_bookings (
      profile_id,
      service_id,
      service_name,
      professional_id,
      professional_name,
      status,
      duration_hours,
      scheduled_at,
      scheduled_end,
      street_address,
      city,
      instructions,
      hourly_rate,
      subtotal,
      total,
      created_at,
      updated_at
    )
    values (
      v_profile_id,
      'standard-home',
      v_cleaning_service_name,
      v_professional_id,
      v_professional_name,
      'completed',
      v_cleaning_duration,
      v_cleaning_start,
      v_cleaning_start + make_interval(hours => v_cleaning_duration),
      'Demo fulfilment location',
      'Mogadishu',
      'Demo booking only',
      v_cleaning_hourly_rate,
      v_cleaning_hourly_rate * v_cleaning_duration,
      v_cleaning_hourly_rate * v_cleaning_duration,
      now() - interval '2 days',
      now() - interval '1 day'
    );
  end if;
end;
$$;
