import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // Deep link Supabase redirects the user to after tapping the
  // password-recovery email link. Must exactly match the custom URL scheme
  // registered in android/app/src/main/AndroidManifest.xml and
  // ios/Runner/Info.plist.
  static const String passwordRecoveryRedirectUrl = 'zivo://reset-callback';

  //sign in with email password
  Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  //sign up with email password
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password, {
    required String firstName,
    required String lastName,
    required String phone,
    required DateTime dob,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'firstname': firstName,
        'lastname': lastName,
        'phone': phone,
        'dob': dob
            .toIso8601String()
            .split('T')
            .first, // 'yyyy-MM-dd', matches a `date` column
      },
    );
  }

  //sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Sends a password-recovery email via Supabase. The link opens the app at
  // [passwordRecoveryRedirectUrl] and creates a short-lived recovery
  // session; finish the flow by calling [updatePassword] once the app is
  // back in the foreground with that session active.
  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: passwordRecoveryRedirectUrl,
    );
  }

  // Updates the password for the currently authenticated user. Works both
  // for a normal signed-in session (change password from Settings) and a
  // password-recovery session created by tapping the reset-email link.
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // Starts an email change for the currently authenticated user. Supabase
  // emails a confirmation link to the new address; the change only takes
  // effect (and `getCurrentUserEmail`/`profiles` reflect it) once that link
  // is tapped and confirmed -- this call succeeding does not mean the email
  // has changed yet.
  Future<UserResponse> updateEmail(String newEmail) async {
    return await _supabase.auth.updateUser(UserAttributes(email: newEmail));
  }

  //current user
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  String? getCurrentUserId() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.id;
  }
}
