import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_widgets.dart';
import '../../../widgets/zivo_logo.dart';
import '../data/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _linkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter your email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() => _linkSent = true);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not send reset link: $error');
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
                          children: _linkSent
                              ? _buildSentContent()
                              : _buildFormContent(),
                        ),
                      ),
                      const SizedBox(height: TwSpacing.x6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Remembered it?', style: TwText.textSm()),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.login),
                            child: Text(
                              'Back to sign in',
                              style: TwText.link(),
                            ),
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

  List<Widget> _buildFormContent() {
    return [
      Text('Forgot password?', style: TwText.text3xl()),
      const SizedBox(height: TwSpacing.x2),
      Text(
        "Enter the email on your account and we'll send you a link to reset "
        'your password.',
        style: TwText.textSm(),
      ),
      const SizedBox(height: TwSpacing.x8),
      AppTextField(
        controller: _emailController,
        label: 'Email address',
        hint: 'you@example.com',
        keyboardType: TextInputType.emailAddress,
        prefixIcon: Icons.mail_outline_rounded,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        onSubmitted: (_) {
          if (!_isLoading) _sendResetLink();
        },
      ),
      const SizedBox(height: TwSpacing.x8),
      if (_isLoading)
        const Center(child: CircularProgressIndicator())
      else
        GradientActionButton(
          label: 'Send reset link',
          onPressed: _sendResetLink,
          icon: const Icon(
            Icons.arrow_forward_rounded,
            color: TwColors.onPrimary,
          ),
        ),
    ];
  }

  List<Widget> _buildSentContent() {
    return [
      const Icon(
        Icons.mark_email_read_outlined,
        color: TwColors.primary,
        size: 40,
      ),
      const SizedBox(height: TwSpacing.x4),
      Text('Check your email', style: TwText.text3xl()),
      const SizedBox(height: TwSpacing.x2),
      Text(
        'If an account exists for ${_emailController.text.trim()}, '
        "we've sent a link to reset your password. Open it on this device "
        'to continue.',
        style: TwText.textSm(),
      ),
      const SizedBox(height: TwSpacing.x8),
      GradientActionButton(
        label: 'Back to sign in',
        onPressed: () => context.go(AppRoutes.login),
        icon: const Icon(
          Icons.arrow_forward_rounded,
          color: TwColors.onPrimary,
        ),
      ),
    ];
  }
}
