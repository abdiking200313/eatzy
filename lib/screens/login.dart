import 'package:chowflow/auth/auth_service.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_widgets.dart';
import '../widgets/zivo_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    try {
      await _authService.signInWithEmailPassword(
        _emailController.text,
        _passwordController.text,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Login',
      showBackButton: true,
      resizeToAvoidBottomInset: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TwSpacing.x5),
          child: OutlinedCard(
            backgroundColor: Colors.white,
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: ZivoLogo(height: 48)),
                const SizedBox(height: TwSpacing.x6),
                Text('Welcome back', style: TwText.text2xl()),
                const SizedBox(height: TwSpacing.x1),
                Text(
                  'Sign in to continue your orders and rewards.',
                  style: TwText.textSm(),
                ),
                const SizedBox(height: TwSpacing.x5),
                AppTextField(
                  controller: _emailController,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: TwSpacing.x4),
                AppTextField(
                  controller: _passwordController,
                  hint: 'Password',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: true,
                ),
                const SizedBox(height: TwSpacing.x8),
                GradientActionButton(label: 'Login', onPressed: _login),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
