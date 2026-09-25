import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/orders/presentation/track_order_screen.dart';
import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:chowflow/features/profile/presentation/profile_screen.dart';
import 'package:chowflow/features/settings/presentation/settings_screen.dart';
import 'package:chowflow/features/support/presentation/support_screen.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/activity/presentation/activity_screen.dart';
import 'package:chowflow/screens/addresses.dart';
import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:chowflow/services/food/presentation/checkout_screen.dart';
import 'package:chowflow/services/food/presentation/food_cart_screen.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_cart_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_checkout_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/grocery/presentation/grocery_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_store_screen.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_store.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_cart_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_catalog_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_checkout_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_store_list_screen.dart';
import 'package:chowflow/widgets/add_to_cart_button.dart';
import 'package:chowflow/widgets/app_misc.dart';
import 'package:chowflow/widgets/zivo_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/controllers.dart';
import 'helpers/memory_cart_storage.dart';

/// Cross-screen layout guarantees:
/// - every redesigned screen stays overflow-free at 320x640 with 1.4x text
///   (the #21 per-screen DoD template), and renders its title;
/// - long lists are virtualized (issue #61/#177);
/// - shared design-system widgets (logo, service theme, add-to-cart).
///
/// Screens whose own test file already owns a narrow-screen case (food home,
/// explore, login, ...) keep it there, next to that screen's fakes.
void main() {
  group('320x640 @1.4x text-scale stays overflow-free', () {
    Future<void> pumpNarrow(
      WidgetTester tester,
      Widget screen, {
      ServiceId? serviceId,
      bool settle = true,
    }) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: serviceId == null
                ? screen
                : ZivoServiceTheme(serviceId: serviceId, child: screen),
          ),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) =>
        tester.scrollUntilVisible(
          finder,
          400,
          scrollable: find.byType(Scrollable).first,
        );

    Future<CartController> foodCart() async {
      final controller = CartController(storage: MemoryCartStorage());
      await controller.loadForOwner('user-1');
      await controller.addItem(
        const CartItem(
          menuItemId: 'burger-1',
          restaurantId: 'restaurant-1',
          restaurantName: 'Test Kitchen',
          name: 'Deluxe Double Cheese Smoked Beef Burger Combo',
          unitPrice: 10,
          imageUrl: '',
        ),
      );
      return controller;
    }

    group('food', () {
      testWidgets('cart', (tester) async {
        await pumpNarrow(tester, CartScreen(cartController: await foodCart()));

        expect(
          find.text('Deluxe Double Cheese Smoked Beef Burger Combo'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('checkout', (tester) async {
        await pumpNarrow(
          tester,
          CheckoutScreen(cartController: await foodCart()),
        );

        expect(find.text('Checkout'), findsOneWidget);
        expect(find.text('Order Summary'), findsOneWidget);
        // Cash-on-delivery is the only payment method at launch (issue #30);
        // it must be visible in the summary, not silently implicit.
        expect(find.text('Cash on delivery'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('grocery', () {
      testWidgets('store list', (tester) async {
        await pumpNarrow(
          tester,
          GroceryScreen(controller: buildGroceryController()),
          serviceId: ServiceId.grocery,
        );

        expect(find.text('Somali stores near you'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('store catalog uses the shared cart action', (tester) async {
        await pumpNarrow(
          tester,
          GroceryStoreScreen(
            storeId: 'bakaal-fresh',
            controller: buildGroceryController(),
          ),
          serviceId: ServiceId.grocery,
        );

        expect(find.text('Bananas'), findsOneWidget);
        expect(find.byType(AddToCartButton), findsWidgets);
        expect(find.byIcon(Icons.add_shopping_cart_rounded), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cart', (tester) async {
        final controller = await buildLoadedGroceryController();
        for (final product
            in controller.stores
                .expand((store) => store.products)
                .where((product) => product.isAvailable)
                .take(2)) {
          controller.addProduct(product);
        }

        await pumpNarrow(
          tester,
          GroceryCartScreen(controller: controller),
          serviceId: ServiceId.grocery,
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('checkout', (tester) async {
        final controller = await buildLoadedGroceryController();
        controller.addProduct(
          controller.stores
              .expand((store) => store.products)
              .firstWhere((product) => product.isAvailable),
        );

        await pumpNarrow(
          tester,
          GroceryCheckoutScreen(controller: controller),
          serviceId: ServiceId.grocery,
        );

        await scrollTo(tester, find.text('Delivery slot'));
        await scrollTo(tester, find.text('Total (USD)'));
        // Cash-on-delivery is the only payment method at launch (issue #30).
        await scrollTo(tester, find.text('Cash on delivery'));
        expect(tester.takeException(), isNull);
      });
    });

    group('pharmacy', () {
      testWidgets('catalog uses the shared cart action', (tester) async {
        await pumpNarrow(
          tester,
          PharmacyCatalogScreen(
            storeId: SeededPharmacyRepository.defaultStoreId,
            controller: buildPharmacyController(),
          ),
          serviceId: ServiceId.pharmacy,
        );

        expect(find.text('Over-the-counter (OTC) only'), findsOneWidget);
        // The store search field pushes the OTC notice/heading tall enough
        // at this text scale that no product card is on screen without
        // scrolling; pinned to the catalog list since the search field's own
        // `TextField` adds a second `Scrollable` to the default finder.
        await tester.scrollUntilVisible(
          find.byType(AddToCartButton),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byIcon(Icons.add_shopping_cart_rounded), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cart', (tester) async {
        final controller = await buildLoadedPharmacyController();
        for (final product in controller.products.take(2)) {
          controller.addProduct(product);
        }

        await pumpNarrow(
          tester,
          PharmacyCartScreen(controller: controller),
          serviceId: ServiceId.pharmacy,
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('checkout', (tester) async {
        final controller = await buildLoadedPharmacyController();
        controller.addProduct(controller.products.first);

        await pumpNarrow(
          tester,
          PharmacyCheckoutScreen(controller: controller),
          serviceId: ServiceId.pharmacy,
        );

        await scrollTo(tester, find.text('Order summary'));
        // Cash-on-delivery is the only payment method at launch (issue #30).
        await scrollTo(tester, find.text('Cash on delivery'));
        expect(tester.takeException(), isNull);
      });
    });

    group('orders, activity and account', () {
      testWidgets('Activity tab renders status pills, not bare text', (
        tester,
      ) async {
        final activity = ActivityController()
          ..record(
            ActivityItem(
              id: 'food-1',
              serviceId: ServiceId.food,
              title: 'Jollof Feast Order',
              subtitle: 'Order #45782',
              status: 'On the way',
              occurredAt: DateTime.utc(2026, 8, 1),
              amount: 1850,
              detailsRoute: '',
            ),
          )
          ..record(
            ActivityItem(
              id: 'grocery-1',
              serviceId: ServiceId.grocery,
              title: 'Bakaara groceries',
              status: 'Delivered',
              occurredAt: DateTime.utc(2026, 7, 27),
              amount: 24,
              detailsRoute: '',
            ),
          );

        await pumpNarrow(
          tester,
          ActivityScreen(controller: activity),
          settle: false,
        );

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byType(StatusPill),
            matching: find.text('On the way'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('Track order', (tester) async {
        await pumpNarrow(
          tester,
          const TrackOrderScreen(),
          serviceId: ServiceId.food,
          settle: false,
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('Addresses', (tester) async {
        await pumpNarrow(tester, const AddressesScreen(), settle: false);

        expect(tester.takeException(), isNull);
        expect(find.byType(StatusPill), findsWidgets);
      });

      testWidgets('Profile', (tester) async {
        await pumpNarrow(
          tester,
          ProfileScreen(
            profileRepository: const _FakeProfileRepository(
              CustomerProfile(
                id: 'customer-1',
                firstName: 'Amina',
                lastName: 'Noor',
                phone: '+252 61 234 5678',
              ),
            ),
          ),
        );

        expect(find.text('Profile'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Settings', (tester) async {
        await pumpNarrow(tester, const SettingsScreen(), settle: false);

        expect(find.text('Settings'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Support', (tester) async {
        await pumpNarrow(tester, const SupportScreen(), settle: false);

        expect(find.text('Help & Support'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });

  /// Pins issue #61's list-virtualization fix (reverted by the store-scoping
  /// refactor in PR #163, restored by issue #177): a long list must not
  /// build far-offscreen rows just because they exist in the data.
  ///
  /// Each screen is fed 300 rows; the first must be built (sanity check that
  /// the list rendered) and the last must NOT be. `find.text` only matches
  /// elements that exist in the tree. `pumpAndSettle` is intentionally
  /// avoided: a single `pump()` mirrors what the first frame actually builds.
  group('long lists do not build rows far outside the viewport', () {
    Future<void> pumpFirstFrames(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('GroceryScreen (store list)', (tester) async {
      await pumpFirstFrames(
        tester,
        GroceryScreen(
          controller: GroceryController(
            repository: const _ManyGroceryStoresRepository(count: 300),
            storage: MemoryCartStorage<GroceryCartLine>(),
          ),
        ),
      );

      expect(find.text('Store 0'), findsOneWidget);
      expect(find.text('Store 299'), findsNothing);
    });

    testWidgets("GroceryStoreScreen (one store's products)", (tester) async {
      const storeId = 'big-store';
      await pumpFirstFrames(
        tester,
        GroceryStoreScreen(
          storeId: storeId,
          controller: GroceryController(
            repository: const _OneBigGroceryStoreRepository(
              storeId: storeId,
              productCount: 300,
            ),
            storage: MemoryCartStorage<GroceryCartLine>(),
          ),
        ),
      );

      expect(find.text('Product 0'), findsOneWidget);
      expect(find.text('Product 299'), findsNothing);
    });

    testWidgets('PharmacyStoreListScreen', (tester) async {
      final stores = [
        for (var i = 0; i < 300; i++)
          PharmacyStore(id: 'pharmacy-$i', name: 'Pharmacy $i', address: ''),
      ];
      await pumpFirstFrames(
        tester,
        PharmacyStoreListScreen(
          storeLoader: () async => stores,
          controller: buildPharmacyController(
            repository: const _EmptyPharmacyRepository(),
          ),
        ),
      );

      expect(find.text('Pharmacy 0'), findsOneWidget);
      expect(find.text('Pharmacy 299'), findsNothing);
    });
  });

  group('design system', () {
    testWidgets('Zivo logo stacks the mark above the wordmark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: Center(child: ZivoLogo(height: 34))),
        ),
      );

      final mark = find.descendant(
        of: find.byType(ZivoLogo),
        matching: find.byType(CustomPaint),
      );
      final wordmark = find.text('zivo');

      expect(mark, findsOneWidget);
      expect(wordmark, findsOneWidget);
      expect(
        tester.getBottomLeft(mark).dy,
        lessThan(tester.getTopLeft(wordmark).dy),
      );
      expect(find.bySemanticsLabel('Zivo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('service theme applies the service palette throughout a '
        'route', (tester) async {
      late ThemeData resolvedTheme;
      late ZivoServiceColors resolvedColors;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ZivoServiceTheme(
            serviceId: ServiceId.grocery,
            child: Builder(
              builder: (context) {
                resolvedTheme = Theme.of(context);
                resolvedColors = context.serviceColors;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );

      expect(resolvedColors, ServiceThemes.grocery);
      expect(resolvedTheme.colorScheme.primary, ServiceThemes.grocery.accent);
      expect(
        resolvedTheme.scaffoldBackgroundColor,
        ServiceThemes.grocery.background,
      );
    });

    testWidgets('shared add-to-cart control has one trailing cart glyph', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ZivoServiceTheme(
            serviceId: ServiceId.pharmacy,
            child: Scaffold(
              body: Align(
                alignment: Alignment.centerRight,
                child: AddToCartButton(
                  tooltip: 'Add medicine to cart',
                  onPressed: () => taps++,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add_shopping_cart_rounded), findsOneWidget);
      expect(find.byTooltip('Add medicine to cart'), findsOneWidget);

      await tester.tap(find.byType(AddToCartButton));
      expect(taps, 1);
    });
  });
}

class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository(this.profile);

  final CustomerProfile? profile;

  @override
  Future<CustomerProfile?> fetchCurrentProfile() async => profile;

  @override
  Future<CustomerProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dob,
  }) async => throw UnimplementedError('not exercised by this test');

  @override
  Future<void> deleteAccount() async =>
      throw UnimplementedError('not exercised by this test');
}

class _ManyGroceryStoresRepository implements GroceryRepository {
  const _ManyGroceryStoresRepository({required this.count});

  final int count;

  @override
  Future<List<GroceryStore>> fetchStores() async => [
    for (var i = 0; i < count; i++)
      GroceryStore(
        id: 'store-$i',
        name: 'Store $i',
        area: 'Area $i',
        products: const [],
      ),
  ];
}

class _OneBigGroceryStoreRepository implements GroceryRepository {
  const _OneBigGroceryStoreRepository({
    required this.storeId,
    required this.productCount,
  });

  final String storeId;
  final int productCount;

  @override
  Future<List<GroceryStore>> fetchStores() async => [
    GroceryStore(
      id: storeId,
      name: 'Big Store',
      area: 'Downtown',
      products: [
        for (var i = 0; i < productCount; i++)
          GroceryProduct(
            id: 'product-$i',
            storeId: storeId,
            name: 'Product $i',
            description: 'A product',
            unitPrice: 100,
            pricingUnit: GroceryPricingUnit.each,
            stockState: GroceryStockState.inStock,
            availableQuantity: 5,
            icon: '🛒',
          ),
      ],
    ),
  ];
}

/// `PharmacyStoreListScreen` only needs a `PharmacyController` for the cart
/// badge in the app bar; the store list itself comes from `storeLoader`.
class _EmptyPharmacyRepository implements PharmacyRepository {
  const _EmptyPharmacyRepository();

  @override
  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  }) async => const [];
}
