import 'dart:math';

/// Generates a client-side `text` primary key for a table whose `id` column
/// has no server-side default (issue #133): `grocery_stores`,
/// `pharmacy_stores`, `grocery_products`, and `pharmacy_products` all
/// declare `id text primary key` with nothing else, unlike `restaurants` /
/// `menu_items`'s server-generated `uuid`
/// (`supabase/migrations/20260727152319_connect_super_app_services.sql`,
/// `supabase/migrations/20260830120000_add_merchant_role_and_store_ownership.sql`).
///
/// Produces a readable slug from [seed] (e.g. a store/item name) plus a
/// short random suffix so two merchants naming a store/item the same thing
/// don't collide -- the same shape as this app's existing seeded ids (e.g.
/// `'bakaal-fresh'`).
String generateSlugId(String seed) {
  final base = seed
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = Random().nextInt(0xFFFFFF).toRadixString(36);
  final prefix = base.isEmpty ? 'item' : base;
  return '$prefix-$suffix';
}
