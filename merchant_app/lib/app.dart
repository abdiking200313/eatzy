import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/merchant_auth_service.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/shell/presentation/merchant_shell.dart';

/// Root widget (issue #132): a tiny state machine between the sign-in
/// screen and the post-sign-in nav shell.
///
/// On startup it re-validates any session `supabase_flutter` already
/// restored from local storage against `profiles.role` (see
/// [MerchantAuthService.restoreSessionIfAuthorized]) rather than trusting a
/// persisted session outright -- a customer-role account (or one demoted
/// after signing in previously) must not reach the shell just because a
/// session file exists on disk.
class MerchantApp extends StatefulWidget {
  const MerchantApp({super.key, this.authService});

  /// Overridable for tests; defaults to a real [MerchantAuthService].
  final MerchantAuthService? authService;

  @override
  State<MerchantApp> createState() => _MerchantAppState();
}

enum _SessionStatus { checking, signedOut, signedIn }

class _MerchantAppState extends State<MerchantApp> {
  MerchantAuthService get _authService =>
      widget.authService ?? MerchantAuthService();

  _SessionStatus _status = _SessionStatus.checking;
  User? _user;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await _authService.restoreSessionIfAuthorized();
    if (!mounted) return;
    setState(() {
      _user = user;
      _status = user != null
          ? _SessionStatus.signedIn
          : _SessionStatus.signedOut;
    });
  }

  void _handleSignedIn(User user) {
    setState(() {
      _user = user;
      _status = _SessionStatus.signedIn;
    });
  }

  void _handleSignedOut() {
    setState(() {
      _user = null;
      _status = _SessionStatus.signedOut;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zivo Merchant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: switch (_status) {
        _SessionStatus.checking => const _CheckingSessionView(),
        _SessionStatus.signedOut => SignInScreen(
          onSignedIn: _handleSignedIn,
          authService: widget.authService,
        ),
        _SessionStatus.signedIn => MerchantShell(
          user: _user!,
          onSignedOut: _handleSignedOut,
          authService: widget.authService,
        ),
      },
    );
  }
}

class _CheckingSessionView extends StatelessWidget {
  const _CheckingSessionView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
