/// The three service verticals a merchant store can belong to (ported from
/// `merchant_app`, originally issue #133, unified into the main app by issue
/// #232).
///
/// Table/column names below are verified against the actual migrations, not
/// guessed:
///   - `supabase/migrations/20260727152319_connect_super_app_services.sql`
///     (original `grocery_stores`/`grocery_products`/`pharmacy_products`
///     shapes; `restaurants`/`menu_items` are in `supabase/schema.sql`).
///   - `supabase/migrations/20260830120000_add_merchant_role_and_store_ownership.sql`
///     (`owner_id` on all three store tables, the new `pharmacy_stores`
///     table).
///   - `supabase/migrations/20260830130000_add_merchant_catalog_write_policies.sql`
///     (the merchant RLS predicates this feature's queries must stay inside).
///   - `supabase/migrations/20260903000000_convert_money_columns_to_cents.sql`
///     (`menu_items.price` / `grocery_products.unit_price` /
///     `pharmacy_products.unit_price` are integer cents).
///
/// The three store tables do not share one shape (`grocery_stores` has no
/// `description`/`image_url`, uses `area` instead of `address`, and
/// `is_active` instead of `is_open`; `pharmacy_stores` has no
/// `description`/`image_url` either). Rather than force a fictitious common
/// shape onto the client, each vertical's per-column behavior is captured
/// here and the UI adapts to what a vertical actually supports.
enum MerchantVertical { food, grocery, pharmacy }

extension MerchantVerticalConfig on MerchantVertical {
  String get displayName => switch (this) {
    MerchantVertical.food => 'Food',
    MerchantVertical.grocery => 'Grocery',
    MerchantVertical.pharmacy => 'Pharmacy',
  };

  /// The store table for this vertical.
  String get storeTable => switch (this) {
    MerchantVertical.food => 'restaurants',
    MerchantVertical.grocery => 'grocery_stores',
    MerchantVertical.pharmacy => 'pharmacy_stores',
  };

  /// The catalog-item table for this vertical.
  String get itemTable => switch (this) {
    MerchantVertical.food => 'menu_items',
    MerchantVertical.grocery => 'grocery_products',
    MerchantVertical.pharmacy => 'pharmacy_products',
  };

  /// The foreign-key column on [itemTable] that points at the store row --
  /// the join the merchant RLS write policies use to scope item writes
  /// (issue #130's "ownership is inherited from the parent store").
  String get itemStoreColumn => switch (this) {
    MerchantVertical.food => 'restaurant_id',
    MerchantVertical.grocery => 'store_id',
    MerchantVertical.pharmacy => 'store_id',
  };

  /// The open/closed boolean column on [storeTable].
  String get storeActiveColumn => switch (this) {
    MerchantVertical.food => 'is_open',
    MerchantVertical.grocery => 'is_active',
    MerchantVertical.pharmacy => 'is_active',
  };

  /// The free-text location column on [storeTable]. `grocery_stores` calls
  /// this `area` (and it is `not null`); the other two call it `address`.
  String get storeLocationColumn => switch (this) {
    MerchantVertical.food => 'address',
    MerchantVertical.grocery => 'area',
    MerchantVertical.pharmacy => 'address',
  };

  String get storeLocationLabel => switch (this) {
    MerchantVertical.food => 'Address',
    MerchantVertical.grocery => 'Area',
    MerchantVertical.pharmacy => 'Address',
  };

  /// Only `restaurants` has a `description` column.
  bool get storeSupportsDescription => this == MerchantVertical.food;

  /// Only `restaurants` has an image column, and on the live table it is
  /// `logo_url` (not `image_url`, which is what the stale `schema.sql` says
  /// and what `menu_items` uses). `logo_url` is also what the customer app
  /// reads for a restaurant's picture (`restaurant_repository.dart`), so a
  /// merchant's image shows up for customers.
  bool get storeSupportsImage => this == MerchantVertical.food;

  /// The image column on [storeTable]; only meaningful when
  /// [storeSupportsImage].
  String get storeImageColumn => 'logo_url';

  /// The store table's primary key: `restaurants.id` is a server-generated
  /// `uuid`; `grocery_stores.id` / `pharmacy_stores.id` are client-supplied
  /// `text` primary keys with no default.
  bool get storeIdIsServerGenerated => this == MerchantVertical.food;

  /// The price column on [itemTable] -- integer cents in every vertical
  /// since `20260903000000_convert_money_columns_to_cents.sql`.
  String get itemPriceColumn => switch (this) {
    MerchantVertical.food => 'price',
    MerchantVertical.grocery => 'unit_price',
    MerchantVertical.pharmacy => 'unit_price',
  };

  /// The availability boolean column on [itemTable].
  String get itemAvailableColumn => switch (this) {
    MerchantVertical.food => 'is_available',
    MerchantVertical.grocery => 'is_active',
    MerchantVertical.pharmacy => 'is_active',
  };

  /// Only `menu_items` has an `image_url` column.
  bool get itemSupportsImage => this == MerchantVertical.food;

  /// `menu_items.id` is a server-generated `uuid`; `grocery_products.id` /
  /// `pharmacy_products.id` are client-supplied `text` primary keys.
  bool get itemIdIsServerGenerated => this == MerchantVertical.food;
}
