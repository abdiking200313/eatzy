-- Merchants upload store and catalog-item photos from their device instead
-- of pasting a hosted image URL.
--
-- 1. Item photo columns for grocery and pharmacy products.
--    `menu_items.image_url` already exists; `grocery_products` and
--    `pharmacy_products` had no image column at all. Additive and nullable,
--    so existing rows and queries are unaffected. RLS is row-level on both
--    tables (public reads of active rows, merchant writes scoped through the
--    parent store's `owner_id` -- 20260830130000) and the grants in
--    20260924020000 are table-level, so both already cover the new column.
--
-- 2. A `merchant_media` storage bucket.
--    The live project has hand-made public buckets (`product_images`,
--    `product_icons`, `restaurants_logo`) but `storage.objects` has no
--    policies, so every upload from the app is rejected. Rather than
--    retrofit write access onto buckets whose contents aren't tracked in
--    migrations, this adds one migration-owned bucket.
--
--    Layout: `merchant_media/<auth.uid()>/<store|items>/<timestamp>.<ext>`.
--    Every write policy keys on the first path segment being the caller's
--    own user id, so a merchant can only create, replace or delete files in
--    their own folder. The bucket is public, so customers load photos via the
--    plain public URL stored in the image columns with no select policy; the
--    select policy below exists only so a merchant's own delete can see the
--    rows it targets. Uploads additionally require
--    `profiles.role in ('merchant', 'admin')`, the same trust check as the
--    store insert policies in 20260830130000.

alter table public.grocery_products
  add column if not exists image_url text;

comment on column public.grocery_products.image_url is
  'Optional product photo URL (usually a merchant_media storage object). Null means no photo.';

alter table public.pharmacy_products
  add column if not exists image_url text;

comment on column public.pharmacy_products.image_url is
  'Optional product photo URL (usually a merchant_media storage object). Null means no photo.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'merchant_media',
  'merchant_media',
  true,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Merchants read own media" on storage.objects;
create policy "Merchants read own media"
on storage.objects for select
to authenticated
using (
  bucket_id = 'merchant_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Merchants upload own media" on storage.objects;
create policy "Merchants upload own media"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'merchant_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1
    from public.profiles profile
    where profile.id = (select auth.uid())
      and profile.role in ('merchant', 'admin')
  )
);

drop policy if exists "Merchants delete own media" on storage.objects;
create policy "Merchants delete own media"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'merchant_media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
