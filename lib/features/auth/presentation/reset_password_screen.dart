import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_widgets.dart';
import '../../../widgets/zivo_logo.dart';
import '../data/auth_service.dart';

/// Lets the current user set a new password. Reached either from Settings
/// (an already-authenticated session) or after tapping a password-recovery
/// email link (a temporary recovery session) — both cases already have a
/// valid Supabase session by the time this screen is shown, so no
/// current-password field is required; see `AuthService.updatePassword`.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill in both fields.');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.updatePassword(password);
      if (!mounted) return;
      _showMessage('Password updated.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.mainApp);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not update password: $error');
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
                      if (context.canPop())
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton.filled(
                            tooltip: 'Back',
                            onPressed: () => context.pop(),
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
                            Text('Set a new password', style: TwText.text3xl()),
                            const SizedBox(height: TwSpacing.x2),
                            Text(
                              'Choose a new password for your account.',
                              style: TwText.textSm(),
                            ),
                            const SizedBox(height: TwSpacing.x8),
                            AppTextField(
                              controller: _passwordController,
                              label: 'New password',
                              hint: 'At least 6 characters',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: TwSpacing.x4),
                            AppTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm new password',
                              hint: 'Enter the password again',
                              prefixIcon: Icons.verified_user_outlined,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onSubmitted: (_) {
                                if (!_isLoading) _updatePassword();
                              },
                            ),
                            const SizedBox(height: TwSpacing.x8),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else
                              GradientActionButton(
                                label: 'Update password',
                                onPressed: _updatePassword,
                                icon: const Icon(
                                  Icons.check_rounded,
                                  color: TwColors.onPrimary,
                                ),
                              ),
                          ],
                        ),
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
