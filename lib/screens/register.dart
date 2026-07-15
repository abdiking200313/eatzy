import 'package:chowflow/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_router.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_widgets.dart';
import '../widgets/zivo_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // AuthService is our small wrapper around Supabase Auth, so the screen does
  // not need to know the low-level Supabase sign-up call details.
  final AuthService _authService = AuthService();

  // These controllers let us read the latest text that the user typed into
  // each field when they press the Create account button.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // This flag prevents double taps while Supabase is creating the account and
  // also lets the UI show a loading spinner inside the button area.
  bool _isLoading = false;

  @override
  void dispose() {
    // Controllers hold native resources, so Flutter expects us to dispose them
    // when the screen is removed from the widget tree.
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // Trim removes accidental spaces before/after the email, which is a common
    // source of confusing auth errors.
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Basic local validation gives the user fast feedback before we call
    // Supabase over the network.
    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill in every field.');
      return;
    }

    // Supabase supports stronger password rules in the dashboard too, but this
    // keeps the app from sending obviously weak passwords.
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }

    // A standard email validation regex
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );

    if (!emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    // The confirm field catches typos before creating the user account.
    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    // setState tells Flutter to rebuild so the loading indicator appears.
    setState(() => _isLoading = true);

    try {
      // This creates the account in Supabase Authentication using email and
      // password. If email confirmation is enabled in Supabase, the user may
      // need to verify their email before they can fully sign in.
      await _authService.signUpWithEmailPassword(email, password);

      if (!mounted) return;

      // Stop the loading spinner before navigation, because after context.go
      // this register screen may no longer be mounted.
      setState(() => _isLoading = false);

      _showMessage('Account created. You can log in now.');

      // Send the user back to the login screen after a successful registration.
      context.go(AppRoutes.login);
    } catch (error) {
      if (!mounted) return;

      // Stop the loading spinner so the user can fix the form and try again.
      setState(() => _isLoading = false);

      // Supabase throws an exception for duplicate emails, weak passwords,
      // network issues, and disabled auth providers. Showing the message keeps
      // the failure visible while you are still building the app.
      _showMessage('Registration failed: $error');
    }
  }

  void _showMessage(String message) {
    // SnackBar is the small message bar at the bottom of the app.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Register',
      showBackButton: true,
      resizeToAvoidBottomInset: true,
      body: Center(
        // SingleChildScrollView keeps the form usable when the keyboard opens
        // on smaller phone screens.
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
                // Page title shown inside the card, matching the login screen.
                Text('Create account', style: TwText.text2xl()),
                const SizedBox(height: TwSpacing.x1),

                // Short helper text explains what this form does.
                Text(
                  'Sign up to save your orders, addresses, and rewards.',
                  style: TwText.textSm(),
                ),
                const SizedBox(height: TwSpacing.x5),

                // Email field is sent to Supabase as the account identifier.
                AppTextField(
                  controller: _emailController,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: TwSpacing.x4),

                // Password field is hidden because it contains private text.
                AppTextField(
                  controller: _passwordController,
                  hint: 'Password',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: true,
                ),
                const SizedBox(height: TwSpacing.x4),

                // Confirm password is checked locally before calling Supabase.
                AppTextField(
                  controller: _confirmPasswordController,
                  hint: 'Confirm password',
                  prefixIcon: Icons.lock_reset_outlined,
                  obscureText: true,
                ),
                const SizedBox(height: TwSpacing.x8),

                // The button becomes a spinner during registration so users do
                // not wonder whether their tap worked.
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  GradientActionButton(
                    label: 'Create account',
                    onPressed: _register,
                  ),
                const SizedBox(height: TwSpacing.x5),

                // This gives users a clear path back if they already have an
                // account.
                Center(
                  child: TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: Text(
                      'Already have an account? Log in',
                      style: TwText.fontBoldSm().copyWith(
                        color: TwColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
