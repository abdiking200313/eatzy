import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/merchant_session_gate.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_widgets.dart';
import '../../../widgets/zivo_logo.dart';
import '../../merchant/auth/data/merchant_role_service.dart';
import '../data/auth_error_message.dart';
import '../data/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService, this.merchantRoleService});

  /// Overrides the default [AuthService] used to submit sign-in requests.
  /// Only intended for tests — production code always uses the default,
  /// which lazily reads `Supabase.instance.client`.
  final AuthService? authService;

  /// Overrides the default [MerchantRoleService] used to decide whether a
  /// successful sign-in should land on the merchant dashboard instead of
  /// the customer home (issue #232). Only intended for tests.
  final MerchantRoleService? merchantRoleService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthService get _authService => widget.authService ?? AuthService();
  MerchantRoleService get _merchantRoleService =>
      widget.merchantRoleService ?? MerchantRoleService();
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

      // Issue #232: same sign-in form for every account -- a
      // `merchant`/`admin` `profiles.role` lands on the merchant dashboard
      // instead of the customer home, decided here right after a
      // successful sign-in (and again on session-restore at app start, see
      // `runStartupSequence`). A lookup failure fails closed into the
      // customer experience rather than blocking the login. The router's own
      // redirect (fired by the sign-in event) joins this same lookup, so it
      // never routes to the customer home while the role is still unknown.
      final userId = _authService.getCurrentUserId();
      if (userId != null) {
        await MerchantSessionGate.resolveFor(
          userId,
          roleService: _merchantRoleService,
        );
      }
      if (!mounted) return;
      context.go(
        MerchantSessionGate.isMerchantRole
            ? AppRoutes.merchantDashboard
            : AppRoutes.mainApp,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Login failed: ${describeAuthError(error, context: 'Login')}',
      );
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
                            // With nothing behind this screen (the app opened
                            // straight on login, or it replaced another route
                            // via `go`) reopen the onboarding slides instead
                            // of doing nothing.
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRoutes.welcomeRevisit);
                            }
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
                            Text('Welcome back', style: TwText.text3xl),
                            const SizedBox(height: TwSpacing.x2),
                            Text(
                              'Sign in to continue your orders.',
                              style: TwText.textSm,
                            ),
                            const SizedBox(height: TwSpacing.sectionGap),
                            AppTextField(
                              controller: _emailController,
                              label: 'Email address',
                              hint: 'you@example.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.mail_outline_rounded,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: TwSpacing.x3_5),
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
                            const SizedBox(height: TwSpacing.x2),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    context.push(AppRoutes.forgotPassword),
                                child: Text(
                                  'Forgot password?',
                                  style: TwText.link,
                                ),
                              ),
                            ),
                            const SizedBox(height: TwSpacing.x6),
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
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('New to Zivo?', style: TwText.textSm),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.register),
                            child: Text('Create account', style: TwText.link),
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
