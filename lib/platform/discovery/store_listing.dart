import '../../app/service_module.dart';

/// A single row in the cross-vertical "Popular Stores" listing — the shared
/// shape `StoreListingRepository` maps `Restaurant`/`GroceryStore`/
/// `PharmacyStore` into, so the home-screen section and the Explore tab can
/// render all three verticals through one widget.
class StoreListing {
  const StoreListing({
    required this.id,
    required this.serviceId,
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    required this.route,
  });

  final String id;
  final ServiceId serviceId; // food, grocery, or pharmacy — never unknown
  final String name;
  final String subtitle;

  /// Null or empty means "no photo" — the UI shows a "No picture available"
  /// placeholder in that case, never a generic icon substitute.
  final String? imageUrl;

  /// go_router route string to open when this store is tapped.
  final String route;
}
