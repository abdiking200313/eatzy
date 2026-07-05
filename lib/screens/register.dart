import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Register',
      showBackButton: true,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: OutlinedCard(
            backgroundColor: Colors.white,
            borderRadius: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Registration is coming soon', style: AppTextStyles.h3()),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'The account creation flow still needs to be connected.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
