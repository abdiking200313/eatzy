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
          padding: const EdgeInsets.all(TwSpacing.x5),
          child: OutlinedCard(
            backgroundColor: Colors.white,
            borderRadius: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Registration is coming soon', style: TwText.text2xl()),
                const SizedBox(height: TwSpacing.x2),
                Text(
                  'The account creation flow still needs to be connected.',
                  textAlign: TextAlign.center,
                  style: TwText.textSm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
