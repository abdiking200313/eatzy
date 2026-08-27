import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_widgets.dart';
import '../../../widgets/zivo_logo.dart';
import '../data/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.authService});

  /// Overrides the default [AuthService] used to submit sign-up requests.
  /// Only intended for tests — production code always uses the default,
  /// which lazily reads `Supabase.instance.client`.
  final AuthService? authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // AuthService keeps the screen separate from the low-level Supabase calls.
  AuthService get _authService => widget.authService ?? AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill in every field.');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }

    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.signUpWithEmailPassword(
        email,
        password,
      );
      if (!mounted) return;

      if (response.session != null) {
        context.go(AppRoutes.mainApp);
        return;
      }

      await _showEmailConfirmationDialog(email);
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Registration failed: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEmailConfirmationDialog(String email) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.mark_email_read_outlined,
            color: TwColors.primary,
          ),
          title: const Text('Confirm your email'),
          content: Text(
            'We sent a confirmation link to $email. '
            'Open the link to activate your account, then sign in.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Go to sign in'),
            ),
          ],
        );
      },
    );
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
                      const SizedBox(height: TwSpacing.x4),
                      const ZivoLogo(height: 44),
                      const SizedBox(height: TwSpacing.x6),
                      AuthCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create your account', style: TwText.text3xl),
                            const SizedBox(height: TwSpacing.rhythmTight),
                            Text(
                              'Join Zivo and make every food order faster and more rewarding.',
                              style: TwText.textSm,
                            ),
                            const SizedBox(height: TwSpacing.rhythmSection),
                            AppTextField(
                              controller: _emailController,
                              label: 'Email address',
                              hint: 'you@example.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.mail_outline_rounded,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: TwSpacing.rhythmDefault),
                            AppTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'At least 6 characters',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: TwSpacing.rhythmDefault),
                            AppTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm password',
                              hint: 'Enter the password again',
                              prefixIcon: Icons.verified_user_outlined,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (!_isLoading) _register();
                              },
                            ),
                            const SizedBox(height: TwSpacing.rhythmDefault),
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: TwColors.primary,
                                ),
                                const SizedBox(width: TwSpacing.x2),
                                Expanded(
                                  child: Text(
                                    'Your account is protected by Supabase authentication.',
                                    style: TwText.textXs.copyWith(
                                      color: TwColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: TwSpacing.rhythmSection),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else
                              GradientActionButton(
                                label: 'Create account',
                                onPressed: _register,
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: TwColors.onPrimary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: TwSpacing.x5),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: TwText.textSm,
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.login),
                            child: Text('Sign in', style: TwText.link),
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
