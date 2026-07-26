import 'package:chowflow/features/auth/data/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('AuthService accepts an injected Supabase client', () {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
    );
    final service = AuthService(client: client);

    expect(service.getCurrentUserId(), isNull);
    expect(service.getCurrentUserEmail(), isNull);
  });
}
