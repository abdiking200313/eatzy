create index cleaning_bookings_specialty_created_idx
on public.cleaning_bookings(specialty_id, created_at desc)
where specialty_id is not null;
