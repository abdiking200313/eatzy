-- Add the professional-first, long-stay cleaning marketplace while preserving
-- the existing hourly demo contract and historical bookings.

alter table public.cleaning_professionals
  add column headline text not null default '',
  add column bio text not null default ''
    check (char_length(bio) <= 1000),
  add column city text not null default 'Mogadishu',
  add column years_experience smallint not null default 0
    check (years_experience between 0 and 60),
  add column languages text[] not null default '{}',
  add column profile_image_url text,
  add column review_count integer not null default 0
    check (review_count >= 0);

create table public.cleaning_specialties (
  id text primary key,
  name text not null unique,
  description text not null default '',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.cleaning_professional_specialties (
  professional_id text not null
    references public.cleaning_professionals(id) on delete cascade,
  specialty_id text not null
    references public.cleaning_specialties(id) on delete cascade,
  primary key (professional_id, specialty_id)
);

create index cleaning_professional_specialties_specialty_idx
  on public.cleaning_professional_specialties(
    specialty_id,
    professional_id
  );

create table public.cleaning_professional_stay_plans (
  professional_id text not null
    references public.cleaning_professionals(id) on delete cascade,
  duration_weeks smallint not null
    check (duration_weeks in (1, 2, 4)),
  weekly_rate numeric(12, 2) not null check (weekly_rate > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (professional_id, duration_weeks)
);

alter table public.cleaning_bookings
  add column booking_type text not null default 'hourly'
    check (booking_type in ('hourly', 'long_stay')),
  add column specialty_id text
    references public.cleaning_specialties(id) on delete restrict,
  add column specialty_name text,
  add column duration_weeks smallint,
  add column weekly_rate numeric(12, 2),
  alter column service_id drop not null,
  alter column duration_hours drop not null,
  alter column hourly_rate drop not null,
  add constraint cleaning_bookings_contract_check check (
    (
      booking_type = 'hourly'
      and service_id is not null
      and duration_hours is not null
      and hourly_rate is not null
      and specialty_id is null
      and specialty_name is null
      and duration_weeks is null
      and weekly_rate is null
    )
    or
    (
      booking_type = 'long_stay'
      and service_id is null
      and duration_hours is null
      and hourly_rate is null
      and specialty_id is not null
      and nullif(trim(specialty_name), '') is not null
      and duration_weeks in (1, 2, 4)
      and weekly_rate > 0
    )
  );

insert into public.cleaning_specialties (
  id,
  name,
  description,
  sort_order
)
values
  (
    'everyday-care',
    'Everyday home care',
    'Daily tidying, floors, kitchens, and bathrooms.',
    1
  ),
  (
    'deep-cleaning',
    'Deep cleaning',
    'Detailed kitchen, bathroom, and full-home cleaning.',
    2
  ),
  (
    'laundry-organization',
    'Laundry & organization',
    'Laundry, wardrobes, and keeping the home organized.',
    3
  ),
  (
    'kitchen-care',
    'Kitchen care',
    'Meal-area hygiene, dishes, and kitchen organization.',
    4
  )
on conflict (id) do update
set
  name = excluded.name,
  description = excluded.description,
  sort_order = excluded.sort_order,
  is_active = true;

update public.cleaning_professionals
set
  display_name = 'Amina Hassan',
  headline = 'Experienced family-home cleaner',
  bio = 'Reliable household support with a careful eye for kitchens, laundry, and family homes.',
  city = 'Mogadishu',
  years_experience = 8,
  languages = array['Somali', 'English'],
  review_count = 38,
  updated_at = now()
where id = 'cleaner-amina';

update public.cleaning_professionals
set
  display_name = 'Hodan Ali',
  headline = 'Consistent care for busy households',
  bio = 'Warm, consistent cleaner specializing in regular home care and detailed kitchen cleaning.',
  city = 'Hargeisa',
  years_experience = 6,
  languages = array['Somali', 'Arabic'],
  review_count = 27,
  updated_at = now()
where id = 'cleaner-hodan';

update public.cleaning_professionals
set
  display_name = 'Abdi Nur',
  headline = 'Home organization and laundry specialist',
  bio = 'Organized long-stay home helper experienced with laundry, shopping support, and larger households.',
  city = 'Bosaso',
  years_experience = 5,
  languages = array['Somali', 'English'],
  review_count = 19,
  updated_at = now()
where id = 'cleaner-abdi';

insert into public.cleaning_professional_specialties (
  professional_id,
  specialty_id
)
values
  ('cleaner-amina', 'everyday-care'),
  ('cleaner-amina', 'deep-cleaning'),
  ('cleaner-amina', 'laundry-organization'),
  ('cleaner-hodan', 'everyday-care'),
  ('cleaner-hodan', 'deep-cleaning'),
  ('cleaner-hodan', 'kitchen-care'),
  ('cleaner-abdi', 'everyday-care'),
  ('cleaner-abdi', 'laundry-organization')
on conflict do nothing;

insert into public.cleaning_professional_stay_plans (
  professional_id,
  duration_weeks,
  weekly_rate
)
values
  ('cleaner-amina', 1, 165),
  ('cleaner-amina', 2, 155),
  ('cleaner-amina', 4, 145),
  ('cleaner-hodan', 1, 145),
  ('cleaner-hodan', 2, 138),
  ('cleaner-hodan', 4, 130),
  ('cleaner-abdi', 1, 135),
  ('cleaner-abdi', 2, 128),
  ('cleaner-abdi', 4, 120)
on conflict (professional_id, duration_weeks) do update
set
  weekly_rate = excluded.weekly_rate,
  is_active = true,
  updated_at = now();

alter table public.cleaning_specialties enable row level security;
alter table public.cleaning_professional_specialties enable row level security;
alter table public.cleaning_professional_stay_plans enable row level security;

create policy "Public reads active cleaning specialties"
on public.cleaning_specialties for select
to anon, authenticated
using (is_active);

create policy "Public reads active cleaner specialties"
on public.cleaning_professional_specialties for select
to anon, authenticated
using (
  exists (
    select 1
    from public.cleaning_professionals professional
    where professional.id = professional_id
      and professional.is_active
  )
  and exists (
    select 1
    from public.cleaning_specialties specialty
    where specialty.id = specialty_id
      and specialty.is_active
  )
);

create policy "Public reads active cleaner stay plans"
on public.cleaning_professional_stay_plans for select
to anon, authenticated
using (
  is_active
  and exists (
    select 1
    from public.cleaning_professionals professional
    where professional.id = professional_id
      and professional.is_active
  )
);

revoke all on
  public.cleaning_specialties,
  public.cleaning_professional_specialties,
  public.cleaning_professional_stay_plans
from public, anon, authenticated;

grant select on
  public.cleaning_specialties,
  public.cleaning_professional_specialties,
  public.cleaning_professional_stay_plans
to anon, authenticated;

create or replace function public.place_long_stay_cleaning_booking(
  p_professional_id text,
  p_specialty_id text,
  p_duration_weeks smallint,
  p_city text,
  p_street_address text,
  p_starts_at timestamptz,
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
  v_professional_name text;
  v_specialty_name text;
  v_weekly_rate numeric(12, 2);
  v_ends_at timestamptz;
  v_booking_id uuid;
  v_created_at timestamptz;
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;
  if p_starts_at <= now() then
    raise exception 'Cleaning arrangement must start in the future';
  end if;
  if p_duration_weeks not in (1, 2, 4) then
    raise exception 'Cleaning arrangement must be 1, 2, or 4 weeks';
  end if;
  if coalesce(trim(p_city), '') = ''
     or coalesce(trim(p_street_address), '') = '' then
    raise exception 'Complete cleaning location details are required';
  end if;
  if char_length(coalesce(p_instructions, '')) > 300 then
    raise exception 'Cleaning instructions are too long';
  end if;

  select
    professional.display_name,
    specialty.name,
    plan.weekly_rate
  into
    v_professional_name,
    v_specialty_name,
    v_weekly_rate
  from public.cleaning_professionals professional
  join public.cleaning_professional_stay_plans plan
    on plan.professional_id = professional.id
   and plan.duration_weeks = p_duration_weeks
   and plan.is_active
  join public.cleaning_professional_specialties mapping
    on mapping.professional_id = professional.id
   and mapping.specialty_id = p_specialty_id
  join public.cleaning_specialties specialty
    on specialty.id = mapping.specialty_id
   and specialty.is_active
  where professional.id = p_professional_id
    and professional.is_active
  for update of professional;

  if v_professional_name is null then
    raise exception 'Cleaner, specialty, or stay plan not found';
  end if;

  v_ends_at := p_starts_at + make_interval(days => p_duration_weeks * 7);

  if exists (
    select 1
    from public.cleaning_bookings existing
    where existing.professional_id = p_professional_id
      and existing.status <> 'cancelled'
      and tstzrange(
        existing.scheduled_at,
        existing.scheduled_end,
        '[)'
      ) && tstzrange(p_starts_at, v_ends_at, '[)')
  ) then
    raise exception 'Selected cleaner is unavailable for those dates';
  end if;

  begin
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
      booking_type,
      specialty_id,
      specialty_name,
      duration_weeks,
      weekly_rate
    )
    values (
      v_profile_id,
      null,
      v_specialty_name,
      p_professional_id,
      v_professional_name,
      'confirmed',
      null,
      p_starts_at,
      v_ends_at,
      trim(p_street_address),
      trim(p_city),
      coalesce(trim(p_instructions), ''),
      null,
      v_weekly_rate * p_duration_weeks,
      v_weekly_rate * p_duration_weeks,
      'long_stay',
      p_specialty_id,
      v_specialty_name,
      p_duration_weeks,
      v_weekly_rate
    )
    returning id, cleaning_bookings.created_at
    into v_booking_id, v_created_at;
  exception
    when exclusion_violation then
      raise exception 'Selected cleaner is unavailable for those dates';
  end;

  return query
  select
    v_booking_id,
    p_professional_id,
    v_professional_name,
    v_created_at;
end;
$$;

revoke all on function public.place_long_stay_cleaning_booking(
  text,
  text,
  smallint,
  text,
  text,
  timestamptz,
  text
)
from public, anon;

grant execute on function public.place_long_stay_cleaning_booking(
  text,
  text,
  smallint,
  text,
  text,
  timestamptz,
  text
)
to authenticated;
