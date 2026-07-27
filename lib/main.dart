import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_router.dart';
import 'config/theme.dart';
import 'features/cart/presentation/cart_controller.dart';
import 'platform/activity/data/activity_repository.dart';
import 'platform/activity/presentation/activity_controller.dart';
import 'platform/session/account_state_coordinator.dart';
import 'platform/system_ui/android_navigation_bar_controller.dart';
import 'widgets/zivo_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jzubookmbrtslocuzepe.supabase.co',
    publishableKey: 'sb_publishable_yLgLRnh00I5zjImD-Q7R6A_uOO-l0sT',
  );

  final cartController = CartController.instance;
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  await cartController.loadForOwner(currentUserId);
  ActivityController.instance.configureRepository(
    SupabaseActivityRepository(client: Supabase.instance.client),
  );
  if (currentUserId != null) {
    await ActivityController.instance.load();
  }

  runApp(ZivoApp(cartController: cartController));
}

class ZivoApp extends StatefulWidget {
  const ZivoApp({super.key, this.cartController});

  final CartController? cartController;

  @override
  State<ZivoApp> createState() => _ZivoAppState();
}

class _ZivoAppState extends State<ZivoApp> {
  final AndroidNavigationBarController _navigationBarController =
      AndroidNavigationBarController();
  late final CartController _cartController =
      widget.cartController ?? CartController.instance;
  late final AccountStateCoordinator _accountStateCoordinator =
      AccountStateCoordinator(initialOwnerId: _cartController.ownerId);
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _navigationBarController.start();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      final nextOwnerId = authState.session?.user.id;
      if (_accountStateCoordinator.handleOwnerChanged(nextOwnerId)) {
        unawaited(_cartController.loadForOwner(nextOwnerId));
        if (nextOwnerId != null) {
          unawaited(ActivityController.instance.load());
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _navigationBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: ZivoBrand.name,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: AppRouter.router,
    );
  }
}
