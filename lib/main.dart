import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/welcome.dart';

void main() {
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
