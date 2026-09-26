// Throwaway preview entry point for visual checks. Do not commit.
import 'package:flutter/material.dart';

import 'app/service_module.dart';
import 'config/theme.dart';
import 'features/super_app/presentation/super_app_home_screen.dart';
import 'platform/activity/presentation/activity_controller.dart';
import 'platform/discovery/store_listing.dart';

Future<List<StoreListing>> _stores() async => const [
  StoreListing(
    id: '1',
    serviceId: ServiceId.food,
    name: 'Bakaara Grill',
    subtitle: 'Food · 25 min',
    imageUrl:
        'https://jzubookmbrtslocuzepe.supabase.co/storage/v1/object/public/product_icons/service-food.jpg',
    route: '/food',
  ),
  StoreListing(
    id: '2',
    serviceId: ServiceId.grocery,
    name: 'Hodan Market',
    subtitle: 'Grocery · 30 min',
    imageUrl:
        'https://jzubookmbrtslocuzepe.supabase.co/storage/v1/object/public/product_icons/service-grocery.png',
    route: '/grocery',
  ),
];

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: SuperAppHomeScreen(
        activityController: ActivityController(),
        storeListingLoader: _stores,
      ),
    ),
  );
}
