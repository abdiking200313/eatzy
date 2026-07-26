import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_router.dart';
import 'config/theme.dart';
import 'features/cart/presentation/cart_controller.dart';
import 'widgets/zivo_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jzubookmbrtslocuzepe.supabase.co',
    publishableKey: 'sb_publishable_yLgLRnh00I5zjImD-Q7R6A_uOO-l0sT',
  );

  final cartController = CartController.instance;
  await cartController.loadForOwner(
    Supabase.instance.client.auth.currentUser?.id,
  );

  runApp(ZivoApp(cartController: cartController));
}

class ZivoApp extends StatefulWidget {
  const ZivoApp({super.key, this.cartController});

  final CartController? cartController;

  @override
  State<ZivoApp> createState() => _ZivoAppState();
}

class _ZivoAppState extends State<ZivoApp> {
  late final CartController _cartController =
      widget.cartController ?? CartController.instance;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      if (_cartController.ownerId != authState.session?.user.id) {
        unawaited(_cartController.loadForOwner(authState.session?.user.id));
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
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
