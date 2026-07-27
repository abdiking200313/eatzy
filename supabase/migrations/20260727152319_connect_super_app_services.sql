-- Zivo customer MVP service data.
-- Deliberately excludes reusable addresses, payment methods, wallet, and coupons.
-- Existing live food tables are preserved and reused.

create extension if not exists pgcrypto;
create extension if not exists btree_gist with schema extensions;

create table public.grocery_stores (
  id text primary key,
  name text not null,
  area text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.grocery_products (
  id text primary key,
  store_id text not null references public.grocery_stores(id) on delete cascade,
  name text not null,
  description text not null default '',
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  pricing_unit text not null check (pricing_unit in ('each', 'kilogram')),
  quantity_step numeric(8, 2) not null check (quantity_step > 0),
  available_quantity numeric(12, 2) not null check (available_quantity >= 0),
  low_stock_threshold numeric(12, 2) not null default 5
    check (low_stock_threshold >= 0),
  icon text not null default '🛒',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (pricing_unit = 'each' and quantity_step = 1)
    or (pricing_unit = 'kilogram' and quantity_step = 0.5)
  )
);

create table public.grocery_delivery_slots (
  id text primary key,
  store_id text not null references public.grocery_stores(id) on delete cascade,
  label text not null,
  detail text not null,
  day_offset smallint not null check (day_offset between 0 and 7),
  start_time time not null,
  end_time time not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (start_time < end_time)
);

create table public.pharmacy_categories (
  id text primary key,
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.pharmacy_products (
  id text primary key,
  category_id text not null
    references public.pharmacy_categories(id) on delete restrict,
  name text not null,
  description text not null default '',
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  stock_quantity integer not null check (stock_quantity >= 0),
  sale_type text not null default 'otc' check (sale_type = 'otc'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.cleaning_services (
  id text primary key,
  name text not null,
  description text not null default '',
  hourly_rate numeric(12, 2) not null check (hourly_rate >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.cleaning_service_durations (
  service_id text not null
    references public.cleaning_services(id) on delete cascade,
  duration_hours smallint not null check (duration_hours > 0),
  primary key (service_id, duration_hours)
);

create table public.cleaning_professionals (
  id text primary key,
  display_name text not null,
  rating numeric(2, 1) not null default 0
    check (rating >= 0 and rating <= 5),
  available_from time not null,
  available_until time not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (available_from < available_until)
);

create table public.cleaning_professional_services (
  professional_id text not null
    references public.cleaning_professionals(id) on delete cascade,
  service_id text not null
    references public.cleaning_services(id) on delete cascade,
  primary key (professional_id, service_id)
);

create table public.food_orders (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references auth.users(id) on delete cascade,
  restaurant_id uuid not null
    references public.restaurants(id) on delete restrict,
  restaurant_name text not null,
  status text not null default 'confirmed'
    check (
      status in (
        'confirmed',
        'preparing',
        'out_for_delivery',
        'delivered',
        'cancelled'
      )
    ),
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  delivery_fee numeric(12, 2) not null default 4.99
    check (delivery_fee >= 0),
  tax numeric(12, 2) not null default 0 check (tax >= 0),
  total numeric(12, 2) not null check (total >= 0),
  currency text not null default 'USD' check (currency = 'USD'),
  country text not null default 'Somalia' check (country = 'Somalia'),
  is_demo boolean not null default true check (is_demo),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.food_order_items (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.food_orders(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id) on delete set null,
  item_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  created_at timestamptz not null default now()
);

create table public.grocery_orders (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references auth.users(id) on delete cascade,
  store_id text not null
    references public.grocery_stores(id) on delete restrict,
  store_name text not null,
  delivery_slot_id text references public.grocery_delivery_slots(id)
    on delete set null,
  delivery_slot_label text not null,
  delivery_window_start timestamptz not null,
  delivery_window_end timestamptz not null,
  recipient_name text not null,
  phone text not null,
  street text not null,
  district text not null,
  city text not null,
  substitution_preference text not null
    check (
      substitution_preference in (
        'best_match',
        'contact_me',
        'no_substitutions'
      )
    ),
  status text not null default 'confirmed'
    check (
      status in (
        'confirmed',
        'shopping',
        'out_for_delivery',
        'delivered',
        'cancelled'
      )
    ),
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  delivery_fee numeric(12, 2) not null default 2.50
    check (delivery_fee >= 0),
  total numeric(12, 2) not null check (total >= 0),
  currency text not null default 'USD' check (currency = 'USD'),
  country text not null default 'Somalia' check (country = 'Somalia'),
  is_demo boolean not null default true check (is_demo),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (delivery_window_start < delivery_window_end)
);

create table public.grocery_order_items (
  id bigint generated always as identity primary key,
  order_id uuid not null
    references public.grocery_orders(id) on delete cascade,
  product_id text references public.grocery_products(id) on delete set null,
  product_name text not null,
  pricing_unit text not null check (pricing_unit in ('each', 'kilogram')),
  quantity numeric(12, 2) not null check (quantity > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  created_at timestamptz not null default now()
);

create table public.pharmacy_orders (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references auth.users(id) on delete cascade,
  customer_name text not null,
  phone_number text not null,
  city text not null,
  district text not null,
  address_line text not null,
  delivery_instructions text not null default '',
  status text not null default 'confirmed'
    check (
      status in (
        'confirmed',
        'packing',
        'out_for_delivery',
        'delivered',
        'cancelled'
      )
    ),
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  delivery_fee numeric(12, 2) not null default 2.50
    check (delivery_fee >= 0),
  total numeric(12, 2) not null check (total >= 0),
  currency text not null default 'USD' check (currency = 'USD'),
  country text not null default 'Somalia' check (country = 'Somalia'),
  is_demo boolean not null default true check (is_demo),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.pharmacy_order_items (
  id bigint generated always as identity primary key,
  order_id uuid not null
    references public.pharmacy_orders(id) on delete cascade,
  product_id text references public.pharmacy_products(id) on delete set null,
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  created_at timestamptz not null default now()
);

create table public.cleaning_bookings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references auth.users(id) on delete cascade,
  service_id text not null
    references public.cleaning_services(id) on delete restrict,
  service_name text not null,
  professional_id text not null
    references public.cleaning_professionals(id) on delete restrict,
  professional_name text not null,
  status text not null default 'confirmed'
    check (
      status in (
        'confirmed',
        'assigned',
        'in_progress',
        'completed',
        'cancelled'
      )
    ),
  duration_hours smallint not null check (duration_hours > 0),
  scheduled_at timestamptz not null,
  scheduled_end timestamptz not null,
  street_address text not null,
  city text not null,
  instructions text not null default ''
    check (char_length(instructions) <= 300),
  hourly_rate numeric(12, 2) not null check (hourly_rate >= 0),
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  total numeric(12, 2) not null check (total >= 0),
  currency text not null default 'USD' check (currency = 'USD'),
  country text not null default 'Somalia' check (country = 'Somalia'),
  is_demo boolean not null default true check (is_demo),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (scheduled_at < scheduled_end)
);

alter table public.cleaning_bookings
  add constraint cleaning_bookings_no_professional_overlap
  exclude using gist (
    professional_id with =,
    tstzrange(scheduled_at, scheduled_end, '[)') with &&
  )
  where (status <> 'cancelled');

-- Foreign keys and common customer/catalog query paths.
create index grocery_products_store_active_name_idx
  on public.grocery_products(store_id, is_active, name);
create index grocery_delivery_slots_store_active_sort_idx
  on public.grocery_delivery_slots(store_id, is_active, sort_order);
create index pharmacy_products_category_active_name_idx
  on public.pharmacy_products(category_id, is_active, name);
create index cleaning_professional_services_service_idx
  on public.cleaning_professional_services(service_id, professional_id);
create index food_orders_profile_created_idx
  on public.food_orders(profile_id, created_at desc);
create index food_orders_restaurant_status_idx
  on public.food_orders(restaurant_id, status);
create index food_order_items_order_idx
  on public.food_order_items(order_id);
create index food_order_items_menu_item_idx
  on public.food_order_items(menu_item_id);
create index grocery_orders_profile_created_idx
  on public.grocery_orders(profile_id, created_at desc);
create index grocery_orders_store_status_idx
  on public.grocery_orders(store_id, status);
create index grocery_orders_delivery_slot_idx
  on public.grocery_orders(delivery_slot_id);
create index grocery_order_items_order_idx
  on public.grocery_order_items(order_id);
create index grocery_order_items_product_idx
  on public.grocery_order_items(product_id);
create index pharmacy_orders_profile_created_idx
  on public.pharmacy_orders(profile_id, created_at desc);
create index pharmacy_order_items_order_idx
  on public.pharmacy_order_items(order_id);
create index pharmacy_order_items_product_idx
  on public.pharmacy_order_items(product_id);
create index cleaning_bookings_profile_created_idx
  on public.cleaning_bookings(profile_id, created_at desc);
create index cleaning_bookings_professional_schedule_idx
  on public.cleaning_bookings(professional_id, scheduled_at)
  where status <> 'cancelled';
create index cleaning_bookings_service_idx
  on public.cleaning_bookings(service_id);

-- Fake Somalia/USD catalog data. Semantic IDs keep seeds deterministic.
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

insert into public.cleaning_services (
  id,
  name,
  description,
  hourly_rate
)
values
  (
    'standard-home',
    'Standard home clean',
    'Routine dusting, floors, kitchen, and bathroom cleaning.',
    12
  ),
  (
    'deep-clean',
    'Deep clean',
    'A thorough top-to-bottom clean for a refreshed home.',
    18
  ),
  (
    'move-clean',
    'Move-in or move-out',
    'Detailed cleaning for an empty home before or after a move.',
    20
  )
on conflict (id) do update
set name = excluded.name,
    description = excluded.description,
    hourly_rate = excluded.hourly_rate,
    is_active = true,
    updated_at = now();

insert into public.cleaning_service_durations (service_id, duration_hours)
values
  ('standard-home', 2),
  ('standard-home', 3),
  ('standard-home', 4),
  ('standard-home', 6),
  ('deep-clean', 3),
  ('deep-clean', 4),
  ('deep-clean', 6),
  ('move-clean', 4),
  ('move-clean', 6),
  ('move-clean', 8)
on conflict (service_id, duration_hours) do nothing;

insert into public.cleaning_professionals (
  id,
  display_name,
  rating,
  available_from,
  available_until
)
values
  ('cleaner-amina', 'Amina', 4.9, '07:00', '20:00'),
  ('cleaner-hodan', 'Hodan', 4.8, '08:00', '21:00'),
  ('cleaner-abdi', 'Abdi', 4.7, '06:00', '19:00')
on conflict (id) do update
set display_name = excluded.display_name,
    rating = excluded.rating,
    available_from = excluded.available_from,
    available_until = excluded.available_until,
    is_active = true,
    updated_at = now();

insert into public.cleaning_professional_services (
  professional_id,
  service_id
)
values
  ('cleaner-amina', 'standard-home'),
  ('cleaner-amina', 'deep-clean'),
  ('cleaner-amina', 'move-clean'),
  ('cleaner-hodan', 'standard-home'),
  ('cleaner-hodan', 'deep-clean'),
  ('cleaner-abdi', 'standard-home'),
  ('cleaner-abdi', 'move-clean')
on conflict (professional_id, service_id) do nothing;

-- RLS is mandatory for all public Data API objects.
alter table public.grocery_stores enable row level security;
alter table public.grocery_products enable row level security;
alter table public.grocery_delivery_slots enable row level security;
alter table public.pharmacy_categories enable row level security;
alter table public.pharmacy_products enable row level security;
alter table public.cleaning_services enable row level security;
alter table public.cleaning_service_durations enable row level security;
alter table public.cleaning_professionals enable row level security;
alter table public.cleaning_professional_services enable row level security;
alter table public.food_orders enable row level security;
alter table public.food_order_items enable row level security;
alter table public.grocery_orders enable row level security;
alter table public.grocery_order_items enable row level security;
alter table public.pharmacy_orders enable row level security;
alter table public.pharmacy_order_items enable row level security;
alter table public.cleaning_bookings enable row level security;

create policy "Public reads active grocery stores"
on public.grocery_stores for select
to anon, authenticated
using (is_active);

create policy "Public reads active grocery products"
on public.grocery_products for select
to anon, authenticated
using (
  is_active
  and exists (
    select 1
    from public.grocery_stores store
    where store.id = grocery_products.store_id
      and store.is_active
  )
);

create policy "Public reads active grocery slots"
on public.grocery_delivery_slots for select
to anon, authenticated
using (
  is_active
  and exists (
    select 1
    from public.grocery_stores store
    where store.id = grocery_delivery_slots.store_id
      and store.is_active
  )
);

create policy "Public reads active pharmacy categories"
on public.pharmacy_categories for select
to anon, authenticated
using (is_active);

create policy "Public reads active OTC pharmacy products"
on public.pharmacy_products for select
to anon, authenticated
using (
  is_active
  and sale_type = 'otc'
  and exists (
    select 1
    from public.pharmacy_categories category
    where category.id = pharmacy_products.category_id
      and category.is_active
  )
);

create policy "Public reads active cleaning services"
on public.cleaning_services for select
to anon, authenticated
using (is_active);

create policy "Public reads active cleaning durations"
on public.cleaning_service_durations for select
to anon, authenticated
using (
  exists (
    select 1
    from public.cleaning_services service
    where service.id = cleaning_service_durations.service_id
      and service.is_active
  )
);

create policy "Public reads active cleaning professionals"
on public.cleaning_professionals for select
to anon, authenticated
using (is_active);

create policy "Public reads active cleaning skills"
on public.cleaning_professional_services for select
to anon, authenticated
using (
  exists (
    select 1
    from public.cleaning_professionals professional
    where professional.id =
      cleaning_professional_services.professional_id
      and professional.is_active
  )
  and exists (
    select 1
    from public.cleaning_services service
    where service.id = cleaning_professional_services.service_id
      and service.is_active
  )
);

create policy "Customers read own food orders"
on public.food_orders for select
to authenticated
using ((select auth.uid()) = profile_id);

create policy "Customers read own food order items"
on public.food_order_items for select
to authenticated
using (
  exists (
    select 1
    from public.food_orders orders
    where orders.id = food_order_items.order_id
      and orders.profile_id = (select auth.uid())
  )
);

create policy "Customers read own grocery orders"
on public.grocery_orders for select
to authenticated
using ((select auth.uid()) = profile_id);

create policy "Customers read own grocery order items"
on public.grocery_order_items for select
to authenticated
using (
  exists (
    select 1
    from public.grocery_orders orders
    where orders.id = grocery_order_items.order_id
      and orders.profile_id = (select auth.uid())
  )
);

create policy "Customers read own pharmacy orders"
on public.pharmacy_orders for select
to authenticated
using ((select auth.uid()) = profile_id);

create policy "Customers read own pharmacy order items"
on public.pharmacy_order_items for select
to authenticated
using (
  exists (
    select 1
    from public.pharmacy_orders orders
    where orders.id = pharmacy_order_items.order_id
      and orders.profile_id = (select auth.uid())
  )
);

create policy "Customers read own cleaning bookings"
on public.cleaning_bookings for select
to authenticated
using ((select auth.uid()) = profile_id);

-- Existing tables needed by the connected frontend.
create policy "Customers read own profile"
on public.profiles for select
to authenticated
using ((select auth.uid()) = id);

create policy "Public reads restaurant locations"
on public.restaurant_locations for select
to anon, authenticated
using (true);

-- Explicit Data API grants. RLS remains the row-level boundary.
revoke all on
  public.grocery_stores,
  public.grocery_products,
  public.grocery_delivery_slots,
  public.pharmacy_categories,
  public.pharmacy_products,
  public.cleaning_services,
  public.cleaning_service_durations,
  public.cleaning_professionals,
  public.cleaning_professional_services,
  public.food_orders,
  public.food_order_items,
  public.grocery_orders,
  public.grocery_order_items,
  public.pharmacy_orders,
  public.pharmacy_order_items,
  public.cleaning_bookings
from anon, authenticated;

revoke all on sequence
  public.food_order_items_id_seq,
  public.grocery_order_items_id_seq,
  public.pharmacy_order_items_id_seq
from anon, authenticated;

grant select on
  public.grocery_stores,
  public.grocery_products,
  public.grocery_delivery_slots,
  public.pharmacy_categories,
  public.pharmacy_products,
  public.cleaning_services,
  public.cleaning_service_durations,
  public.cleaning_professionals,
  public.cleaning_professional_services
to anon, authenticated;

grant select on
  public.food_orders,
  public.food_order_items,
  public.grocery_orders,
  public.grocery_order_items,
  public.pharmacy_orders,
  public.pharmacy_order_items
to authenticated;

grant select on
  public.cleaning_bookings,
  public.profiles,
  public.restaurant_locations
to authenticated;

grant select on public.restaurant_locations to anon;

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
  where input.quantity > 0;

  return v_order_id;
end;
$$;

create or replace function public.place_grocery_order(
  p_store_id text,
  p_delivery_slot_id text,
  p_recipient_name text,
  p_phone text,
  p_street text,
  p_district text,
  p_city text,
  p_substitution_preference text,
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
  v_store_name text;
  v_slot_label text;
  v_delivery_window_start timestamptz;
  v_delivery_window_end timestamptz;
  v_input_count integer;
  v_valid_count integer;
  v_unique_count integer;
  v_subtotal numeric(12, 2);
  v_delivery_fee numeric(12, 2) := 2.50;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'A grocery order requires at least one item';
  end if;
  if coalesce(trim(p_recipient_name), '') = ''
     or coalesce(trim(p_phone), '') = ''
     or coalesce(trim(p_street), '') = ''
     or coalesce(trim(p_district), '') = ''
     or coalesce(trim(p_city), '') = '' then
    raise exception 'Complete grocery delivery details are required';
  end if;
  if p_substitution_preference not in (
    'best_match',
    'contact_me',
    'no_substitutions'
  ) then
    raise exception 'Invalid substitution preference';
  end if;

  select name
  into v_store_name
  from public.grocery_stores
  where id = p_store_id and is_active;

  if v_store_name is null then
    raise exception 'Grocery store not found';
  end if;

  select
    label || ', ' || detail,
    (
      (now() at time zone 'Africa/Mogadishu')::date
        + day_offset
        + start_time
    ) at time zone 'Africa/Mogadishu',
    (
      (now() at time zone 'Africa/Mogadishu')::date
        + day_offset
        + end_time
    ) at time zone 'Africa/Mogadishu'
  into
    v_slot_label,
    v_delivery_window_start,
    v_delivery_window_end
  from public.grocery_delivery_slots
  where id = p_delivery_slot_id
    and store_id = p_store_id
    and is_active;

  if v_slot_label is null then
    raise exception 'Delivery slot not found';
  end if;

  v_input_count := jsonb_array_length(p_items);

  perform 1
  from public.grocery_products product
  join jsonb_to_recordset(p_items)
    as input(product_id text, quantity numeric)
    on product.id = input.product_id
  where product.store_id = p_store_id
  for update of product;

  select
    count(*)::integer,
    count(distinct input.product_id)::integer,
    coalesce(sum(product.unit_price * input.quantity), 0)
  into v_valid_count, v_unique_count, v_subtotal
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity numeric)
  join public.grocery_products product
    on product.id = input.product_id
   and product.store_id = p_store_id
   and product.is_active
  where input.quantity > 0
    and input.quantity <= product.available_quantity
    and mod(input.quantity, product.quantity_step) = 0;

  if v_valid_count <> v_input_count
     or v_unique_count <> v_input_count
     or v_subtotal <= 0 then
    raise exception 'Grocery order contains invalid items';
  end if;

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
    subtotal,
    delivery_fee,
    total
  )
  values (
    v_profile_id,
    p_store_id,
    v_store_name,
    p_delivery_slot_id,
    v_slot_label,
    v_delivery_window_start,
    v_delivery_window_end,
    trim(p_recipient_name),
    trim(p_phone),
    trim(p_street),
    trim(p_district),
    trim(p_city),
    p_substitution_preference,
    v_subtotal,
    v_delivery_fee,
    v_subtotal + v_delivery_fee
  )
  returning id into v_order_id;

  insert into public.grocery_order_items (
    order_id,
    product_id,
    product_name,
    pricing_unit,
    quantity,
    unit_price
  )
  select
    v_order_id,
    product.id,
    product.name,
    product.pricing_unit,
    input.quantity,
    product.unit_price
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity numeric)
  join public.grocery_products product
    on product.id = input.product_id
   and product.store_id = p_store_id
   and product.is_active
  where input.quantity > 0
    and input.quantity <= product.available_quantity
    and mod(input.quantity, product.quantity_step) = 0;

  update public.grocery_products product
  set available_quantity = product.available_quantity - input.quantity,
      updated_at = now()
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity numeric)
  where product.id = input.product_id;

  return v_order_id;
end;
$$;

create or replace function public.place_pharmacy_order(
  p_customer_name text,
  p_phone_number text,
  p_city text,
  p_district text,
  p_address_line text,
  p_delivery_instructions text,
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
  v_input_count integer;
  v_valid_count integer;
  v_unique_count integer;
  v_subtotal numeric(12, 2);
  v_delivery_fee numeric(12, 2) := 2.50;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'A pharmacy order requires at least one item';
  end if;
  if coalesce(trim(p_customer_name), '') = ''
     or coalesce(trim(p_phone_number), '') = ''
     or coalesce(trim(p_city), '') = ''
     or coalesce(trim(p_district), '') = ''
     or coalesce(trim(p_address_line), '') = '' then
    raise exception 'Complete pharmacy delivery details are required';
  end if;

  v_input_count := jsonb_array_length(p_items);

  perform 1
  from public.pharmacy_products product
  join jsonb_to_recordset(p_items)
    as input(product_id text, quantity integer)
    on product.id = input.product_id
  for update of product;

  select
    count(*)::integer,
    count(distinct input.product_id)::integer,
    coalesce(sum(product.unit_price * input.quantity), 0)
  into v_valid_count, v_unique_count, v_subtotal
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity integer)
  join public.pharmacy_products product
    on product.id = input.product_id
   and product.is_active
   and product.sale_type = 'otc'
  where input.quantity > 0
    and input.quantity <= product.stock_quantity;

  if v_valid_count <> v_input_count
     or v_unique_count <> v_input_count
     or v_subtotal <= 0 then
    raise exception 'Pharmacy order contains invalid or non-OTC items';
  end if;

  insert into public.pharmacy_orders (
    profile_id,
    customer_name,
    phone_number,
    city,
    district,
    address_line,
    delivery_instructions,
    subtotal,
    delivery_fee,
    total
  )
  values (
    v_profile_id,
    trim(p_customer_name),
    trim(p_phone_number),
    trim(p_city),
    trim(p_district),
    trim(p_address_line),
    coalesce(trim(p_delivery_instructions), ''),
    v_subtotal,
    v_delivery_fee,
    v_subtotal + v_delivery_fee
  )
  returning id into v_order_id;

  insert into public.pharmacy_order_items (
    order_id,
    product_id,
    product_name,
    quantity,
    unit_price
  )
  select
    v_order_id,
    product.id,
    product.name,
    input.quantity,
    product.unit_price
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity integer)
  join public.pharmacy_products product
    on product.id = input.product_id
   and product.is_active
   and product.sale_type = 'otc'
  where input.quantity > 0
    and input.quantity <= product.stock_quantity;

  update public.pharmacy_products product
  set stock_quantity = product.stock_quantity - input.quantity,
      updated_at = now()
  from jsonb_to_recordset(p_items)
    as input(product_id text, quantity integer)
  where product.id = input.product_id;

  return v_order_id;
end;
$$;

create or replace function public.place_cleaning_booking(
  p_service_id text,
  p_duration_hours smallint,
  p_city text,
  p_street_address text,
  p_scheduled_at timestamptz,
  p_instructions text
)
returns table (
  booking_id uuid,
  professional_id text,
  professional_name text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_service_name text;
  v_hourly_rate numeric(12, 2);
  v_professional_id text;
  v_professional_name text;
  v_booking_id uuid;
  v_created_at timestamptz;
  v_local_start timestamp;
  v_local_end timestamp;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;
  if p_scheduled_at <= now() then
    raise exception 'Cleaning booking must be scheduled in the future';
  end if;
  if coalesce(trim(p_city), '') = ''
     or coalesce(trim(p_street_address), '') = '' then
    raise exception 'Complete cleaning location details are required';
  end if;
  if char_length(coalesce(p_instructions, '')) > 300 then
    raise exception 'Cleaning instructions are too long';
  end if;

  select service.name, service.hourly_rate
  into v_service_name, v_hourly_rate
  from public.cleaning_services service
  join public.cleaning_service_durations duration
    on duration.service_id = service.id
   and duration.duration_hours = p_duration_hours
  where service.id = p_service_id
    and service.is_active;

  if v_service_name is null then
    raise exception 'Cleaning service or duration not found';
  end if;

  v_local_start := p_scheduled_at at time zone 'Africa/Mogadishu';
  v_local_end := v_local_start + make_interval(hours => p_duration_hours);

  select professional.id, professional.display_name
  into v_professional_id, v_professional_name
  from public.cleaning_professionals professional
  join public.cleaning_professional_services skill
    on skill.professional_id = professional.id
   and skill.service_id = p_service_id
  where professional.is_active
    and v_local_start::time >= professional.available_from
    and v_local_end::time <= professional.available_until
    and v_local_start::date = v_local_end::date
    and not exists (
      select 1
      from public.cleaning_bookings existing
      where existing.professional_id = professional.id
        and existing.status <> 'cancelled'
        and tstzrange(
          existing.scheduled_at,
          existing.scheduled_at
            + make_interval(hours => existing.duration_hours),
          '[)'
        ) && tstzrange(
          p_scheduled_at,
          p_scheduled_at + make_interval(hours => p_duration_hours),
          '[)'
        )
    )
  order by professional.rating desc, professional.id
  for update of professional skip locked
  limit 1;

  if v_professional_id is null then
    raise exception 'No cleaning professional is available at that time';
  end if;

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
    total
  )
  values (
    v_profile_id,
    p_service_id,
    v_service_name,
    v_professional_id,
    v_professional_name,
    'confirmed',
    p_duration_hours,
    p_scheduled_at,
    p_scheduled_at + make_interval(hours => p_duration_hours),
    trim(p_street_address),
    trim(p_city),
    coalesce(trim(p_instructions), ''),
    v_hourly_rate,
    v_hourly_rate * p_duration_hours,
    v_hourly_rate * p_duration_hours
  )
  returning id, cleaning_bookings.created_at
  into v_booking_id, v_created_at;

  return query
  select
    v_booking_id,
    v_professional_id,
    v_professional_name,
    v_created_at;
end;
$$;

revoke all on function public.place_food_order(uuid, jsonb)
from public, anon;
revoke all on function public.place_grocery_order(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  jsonb
)
from public, anon;
revoke all on function public.place_pharmacy_order(
  text,
  text,
  text,
  text,
  text,
  text,
  jsonb
)
from public, anon;
revoke all on function public.place_cleaning_booking(
  text,
  smallint,
  text,
  text,
  timestamptz,
  text
)
from public, anon;

grant execute on function public.place_food_order(uuid, jsonb)
to authenticated;
grant execute on function public.place_grocery_order(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  jsonb
)
to authenticated;
grant execute on function public.place_pharmacy_order(
  text,
  text,
  text,
  text,
  text,
  text,
  jsonb
)
to authenticated;
grant execute on function public.place_cleaning_booking(
  text,
  smallint,
  text,
  text,
  timestamptz,
  text
)
to authenticated;

create view public.customer_activity
with (security_invoker = true)
as
select
  orders.id,
  orders.profile_id,
  'food'::text as service_id,
  orders.restaurant_name as title,
  'Food order • Somalia'::text as subtitle,
  orders.status,
  orders.created_at as occurred_at,
  orders.total as amount,
  '/food'::text as details_route
from public.food_orders orders
union all
select
  orders.id,
  orders.profile_id,
  'grocery'::text as service_id,
  orders.store_name as title,
  orders.delivery_slot_label as subtitle,
  orders.status,
  orders.created_at as occurred_at,
  orders.total as amount,
  '/grocery'::text as details_route
from public.grocery_orders orders
union all
select
  orders.id,
  orders.profile_id,
  'pharmacy'::text as service_id,
  'Pharmacy order'::text as title,
  orders.customer_name || ' • Somalia' as subtitle,
  orders.status,
  orders.created_at as occurred_at,
  orders.total as amount,
  '/pharmacy'::text as details_route
from public.pharmacy_orders orders
union all
select
  bookings.id,
  bookings.profile_id,
  'cleaning'::text as service_id,
  bookings.service_name as title,
  bookings.professional_name || ' • ' || bookings.city as subtitle,
  bookings.status,
  bookings.created_at as occurred_at,
  bookings.total as amount,
  '/cleaning'::text as details_route
from public.cleaning_bookings bookings;

revoke all on public.customer_activity from public, anon, authenticated;
grant select on public.customer_activity to authenticated, service_role;
