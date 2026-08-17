-- Zivo local/dev seed data.
--
-- This is Supabase's standard seed-file convention: `supabase db reset` and
-- `supabase seed` run this file once, after every tracked migration in
-- `supabase/migrations/` has applied, and ONLY against a local or dev
-- database. It is never part of `supabase db push` / the normal
-- migration-apply path, so nothing in this file ever reaches production.
--
-- Moved here from the migration chain per issue #35: demo catalog rows and
-- demo order history were previously inserted by
-- `migrations/20260727152319_connect_super_app_services.sql` and
-- `migrations/20260727154405_seed_demo_customer_activity.sql`. Migrations
-- run on every environment including production, so that demo data was
-- reachable by a real deploy. Demo/seed data belongs here instead.
--
-- The demo *order history* below also fixes a second bug from #35: the old
-- migration attached fake "delivered" orders to
-- `select id from public.profiles order by id limit 1` -- i.e. whichever
-- real signed-up user happened to be first. This file instead creates its
-- own dedicated demo account (fixed id below) and only ever attaches demo
-- activity to that account, never to a real user's profile.
--
-- Cleaning/cleaner demo data (the former `cleaner-amina` catalog and its
-- demo booking) is intentionally NOT reproduced here: the cleaning vertical
-- was removed entirely in issue #50
-- (migrations/20260815153920_remove_cleaning_vertical.sql) and its tables no
-- longer exist.
--
-- This file assumes the base schema in `supabase/schema.sql` (profiles,
-- restaurants, menu_items, categories, ...) has already been applied to the
-- target database -- the same pre-existing assumption the migration this
-- data was moved from already made. Reconciling `schema.sql` into the
-- tracked migration chain is a separate, already-documented gap (see
-- AGENTS.md's "Supabase and security conventions" section) and is out of
-- scope for issue #35.

-- ---------------------------------------------------------------------
-- Demo grocery catalog. Fake Somalia/USD data; semantic ids keep this
-- deterministic and safe to re-run.
-- ---------------------------------------------------------------------

insert into public.grocery_stores (id, name, area)
values
  ('bakaal-fresh', 'Bakaal Fresh', 'Hodan, Mogadishu'),
  ('suuqa-hamar', 'Suuqa Hamar', 'Waberi, Mogadishu')
on conflict (id) do update
set name = excluded.name,
    area = excluded.area,
    is_active = true,
    updated_at = now();

insert into public.grocery_products (
  id,
  store_id,
  name,
  description,
  unit_price,
  pricing_unit,
  quantity_step,
  available_quantity,
  low_stock_threshold,
  icon
)
values
  (
    'bakaal-bananas',
    'bakaal-fresh',
    'Bananas',
    'Fresh bananas, sold by weight',
    1.80,
    'kilogram',
    0.5,
    12,
    3,
    '🍌'
  ),
  (
    'bakaal-rice',
    'bakaal-fresh',
    'Basmati rice',
    'One 5 kg bag',
    8.50,
    'each',
    1,
    24,
    5,
    '🍚'
  ),
  (
    'bakaal-milk',
    'bakaal-fresh',
    'Long-life milk',
    'One litre carton',
    1.25,
    'each',
    1,
    3,
    5,
    '🥛'
  ),
  (
    'bakaal-tomatoes',
    'bakaal-fresh',
    'Tomatoes',
    'Local tomatoes, sold by weight',
    2.20,
    'kilogram',
    0.5,
    0,
    3,
    '🍅'
  ),
  (
    'hamar-eggs',
    'suuqa-hamar',
    'Eggs',
    'Tray of 12 eggs',
    3.40,
    'each',
    1,
    4,
    5,
    '🥚'
  ),
  (
    'hamar-potatoes',
    'suuqa-hamar',
    'Potatoes',
    'Washed potatoes, sold by weight',
    1.60,
    'kilogram',
    0.5,
    18,
    5,
    '🥔'
  ),
  (
    'hamar-detergent',
    'suuqa-hamar',
    'Laundry detergent',
    'One 1 kg pack',
    4.75,
    'each',
    1,
    10,
    3,
    '🧺'
  )
on conflict (id) do update
set store_id = excluded.store_id,
    name = excluded.name,
    description = excluded.description,
    unit_price = excluded.unit_price,
    pricing_unit = excluded.pricing_unit,
    quantity_step = excluded.quantity_step,
    available_quantity = excluded.available_quantity,
    low_stock_threshold = excluded.low_stock_threshold,
    icon = excluded.icon,
    is_active = true,
    updated_at = now();

insert into public.grocery_delivery_slots (
  id,
  store_id,
  label,
  detail,
  day_offset,
  start_time,
  end_time,
  sort_order
)
values
  (
    'bakaal-today-afternoon',
    'bakaal-fresh',
    'Today',
    '2:00 PM – 4:00 PM',
    0,
    '14:00',
    '16:00',
    1
  ),
  (
    'bakaal-today-evening',
    'bakaal-fresh',
    'Today',
    '6:00 PM – 8:00 PM',
    0,
    '18:00',
    '20:00',
    2
  ),
  (
    'bakaal-tomorrow-morning',
    'bakaal-fresh',
    'Tomorrow',
    '9:00 AM – 11:00 AM',
    1,
    '09:00',
    '11:00',
    3
  ),
  (
    'hamar-today-afternoon',
    'suuqa-hamar',
    'Today',
    '2:00 PM – 4:00 PM',
    0,
    '14:00',
    '16:00',
    1
  ),
  (
    'hamar-today-evening',
    'suuqa-hamar',
    'Today',
    '6:00 PM – 8:00 PM',
    0,
    '18:00',
    '20:00',
    2
  ),
  (
    'hamar-tomorrow-morning',
    'suuqa-hamar',
    'Tomorrow',
    '9:00 AM – 11:00 AM',
    1,
    '09:00',
    '11:00',
    3
  )
on conflict (id) do update
set store_id = excluded.store_id,
    label = excluded.label,
    detail = excluded.detail,
    day_offset = excluded.day_offset,
    start_time = excluded.start_time,
    end_time = excluded.end_time,
    sort_order = excluded.sort_order,
    is_active = true;

-- ---------------------------------------------------------------------
-- Demo pharmacy catalog. Same fake-but-deterministic approach as grocery.
-- ---------------------------------------------------------------------

insert into public.pharmacy_categories (id, name)
values
  ('pain-relief', 'Pain relief'),
  ('cold-flu', 'Cold & flu'),
  ('first-aid', 'First aid'),
  ('vitamins', 'Vitamins'),
  ('allergy', 'Allergy')
on conflict (id) do update
set name = excluded.name,
    is_active = true;

insert into public.pharmacy_products (
  id,
  category_id,
  name,
  description,
  unit_price,
  stock_quantity,
  sale_type
)
values
  (
    'pain-paracetamol',
    'pain-relief',
    'Paracetamol',
    'Everyday relief for mild pain and fever.',
    2.75,
    24,
    'otc'
  ),
  (
    'cold-cough-syrup',
    'cold-flu',
    'Cough Syrup',
    'Soothing syrup for common cough symptoms.',
    5.50,
    4,
    'otc'
  ),
  (
    'first-aid-bandages',
    'first-aid',
    'Adhesive Bandages',
    'A pack of 30 sterile everyday bandages.',
    3.25,
    18,
    'otc'
  ),
  (
    'wellness-vitamin-c',
    'vitamins',
    'Vitamin C',
    'Thirty 500 mg vitamin C tablets.',
    6.00,
    10,
    'otc'
  ),
  (
    'allergy-antihistamine',
    'allergy',
    'Allergy Relief',
    'Non-drowsy tablets for common allergy symptoms.',
    4.80,
    0,
    'otc'
  )
on conflict (id) do update
set category_id = excluded.category_id,
    name = excluded.name,
    description = excluded.description,
    unit_price = excluded.unit_price,
    stock_quantity = excluded.stock_quantity,
    sale_type = excluded.sale_type,
    is_active = true,
    updated_at = now();

-- ---------------------------------------------------------------------
-- Dedicated demo account. Every seeded "customer activity" row below is
-- attached to this fixed id -- never to an arbitrary real profile.
--
-- No `auth.identities` row is created, so this account cannot actually sign
-- in through the app; it exists only so seeded order history has a valid
-- `profile_id` to point at for local Studio/browsing and dev-time UI checks.
-- ---------------------------------------------------------------------

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change
)
values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'demo.customer@zivo.local',
  crypt('zivo-local-demo-account', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now(),
  '',
  '',
  '',
  ''
)
on conflict (id) do nothing;

insert into public.profiles (id, full_name, phone, membership_tier)
values (
  '00000000-0000-0000-0000-000000000001',
  'Demo Customer',
  '+252 61 000 0000',
  'standard'
)
on conflict (id) do update
set full_name = excluded.full_name,
    phone = excluded.phone,
    membership_tier = excluded.membership_tier,
    updated_at = now();

-- ---------------------------------------------------------------------
-- Demo order history for the dedicated demo account above. Mirrors what
-- `20260727154405_seed_demo_customer_activity.sql` used to create, minus
-- the removed cleaning booking, and guarded so re-running `supabase seed`
-- does not pile up duplicate orders.
-- ---------------------------------------------------------------------

do $$
declare
  v_profile_id constant uuid := '00000000-0000-0000-0000-000000000001';

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
begin
  if not exists (
    select 1 from public.food_orders where profile_id = v_profile_id
  ) then
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
  end if;

  if not exists (
    select 1 from public.grocery_orders where profile_id = v_profile_id
  ) then
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
  end if;

  if not exists (
    select 1 from public.pharmacy_orders where profile_id = v_profile_id
  ) then
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
  end if;
end;
$$;
