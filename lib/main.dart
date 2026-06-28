import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme.dart';
import 'screens/welcome.dart';

void main() async{
  //supabase setup
  await Supabase.initialize(
    url: 'https://atifebcufurziatglazv.supabase.co',
    anonKey: 'sb_publishable_yAtGwxHkT3zbplDDUUtINA_CSLboW2j',
  );

  runApp(const ChowFlowApp());
}

class ChowFlowApp extends StatelessWidget {
  const ChowFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChowFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.surface,
        primaryColor: AppColors.primary,
        useMaterial3: false,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChowFlowApp();
  }
}
