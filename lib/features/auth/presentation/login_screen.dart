import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_widgets.dart';
import '../../../widgets/zivo_logo.dart';
import '../data/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmailPassword(email, password);
      if (!mounted) return;
      context.go(AppRoutes.mainApp);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Login failed: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthPageBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TwSpacing.x5),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AutofillGroup(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton.filled(
                          tooltip: 'Back',
                          onPressed: () {
                            if (context.canPop()) context.pop();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: TwColors.white,
                            foregroundColor: TwColors.text,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const SizedBox(height: TwSpacing.x6),
                      const ZivoLogo(height: 48),
                      const SizedBox(height: TwSpacing.x8),
                      AuthCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome back', style: TwText.text3xl()),
                            const SizedBox(height: TwSpacing.x2),
                            Text(
                              'Sign in to continue your orders, favorites, and rewards.',
                              style: TwText.textSm(),
                            ),
                            const SizedBox(height: TwSpacing.x8),
                            AppTextField(
                              controller: _emailController,
                              label: 'Email address',
                              hint: 'you@example.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.mail_outline_rounded,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: TwSpacing.x4),
                            AppTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Enter your password',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) {
                                if (!_isLoading) _login();
                              },
                            ),
                            const SizedBox(height: TwSpacing.x8),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else
                              GradientActionButton(
                                label: 'Sign in',
                                onPressed: _login,
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: TwColors.onPrimary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: TwSpacing.x6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('New to Zivo?', style: TwText.textSm()),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.register),
                            child: Text('Create account', style: TwText.link()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
