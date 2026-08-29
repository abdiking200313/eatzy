import 'package:flutter/material.dart';

import 'app_routes.dart';

/// `unknown` is not a purchasable service module — it exists only as a
/// fallback for activity/history rows whose `service_id` no longer matches
/// a real module (e.g. a legacy or removed service, see issue #62). It is
/// intentionally excluded from [ServiceRegistry.modules].
enum ServiceId { food, grocery, pharmacy, unknown }

class ServiceDescriptor {
  const ServiceDescriptor({
    required this.id,
    required this.title,
    required this.description,
    required this.entryRoute,
    required this.icon,
  });

  final ServiceId id;
  final String title;
  final String description;
  final String entryRoute;
  final IconData icon;
}

abstract final class ServiceRegistry {
  static const modules = <ServiceDescriptor>[
    ServiceDescriptor(
      id: ServiceId.food,
      title: 'Food',
      description: 'Meals from nearby restaurants',
      entryRoute: AppRoutes.food,
      icon: Icons.restaurant_outlined,
    ),
    ServiceDescriptor(
      id: ServiceId.grocery,
      title: 'Grocery',
      description: 'Everyday essentials delivered',
      entryRoute: AppRoutes.grocery,
      icon: Icons.local_grocery_store_outlined,
    ),
    ServiceDescriptor(
      id: ServiceId.pharmacy,
      title: 'Pharmacy',
      description: 'Over-the-counter health essentials',
      entryRoute: AppRoutes.pharmacy,
      icon: Icons.local_pharmacy_outlined,
    ),
  ];

  /// Generic descriptor for [ServiceId.unknown] and any other id that has no
  /// entry in [modules] (defensive fallback rather than a thrown error).
  static const unknownModule = ServiceDescriptor(
    id: ServiceId.unknown,
    title: 'Other',
    description: 'Activity from a service that is no longer available',
    entryRoute: '',
    icon: Icons.receipt_long_outlined,
  );

  static ServiceDescriptor byId(ServiceId id) => modules.firstWhere(
    (module) => module.id == id,
    orElse: () => unknownModule,
  );
}
