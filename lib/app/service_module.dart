import 'package:flutter/material.dart';

import 'app_routes.dart';

enum ServiceId { food, grocery, pharmacy }

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

  static ServiceDescriptor byId(ServiceId id) =>
      modules.firstWhere((module) => module.id == id);
}
