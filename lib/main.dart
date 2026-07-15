import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app_router.dart';
import 'config/theme.dart';
import 'widgets/zivo_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://atifebcufurziatglazv.supabase.co',
    anonKey: 'sb_publishable_yAtGwxHkT3zbplDDUUtINA_CSLboW2j',
  );

  runApp(const ZivoApp());
}

class ZivoApp extends StatelessWidget {
  const ZivoApp({super.key});

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ZivoApp();
  }
}
