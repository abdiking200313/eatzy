import 'package:chowflow/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env (issue #42)', () {
    test('supabaseUrl falls back to the live project URL when SUPABASE_URL is '
        'not passed via --dart-define', () {
      expect(Env.supabaseUrl, 'https://jzubookmbrtslocuzepe.supabase.co');
    });

    test('supabaseAnonKey falls back to the live project anon key when '
        'SUPABASE_ANON_KEY is not passed via --dart-define', () {
      expect(
        Env.supabaseAnonKey,
        'sb_publishable_yLgLRnh00I5zjImD-Q7R6A_uOO-l0sT',
      );
    });

    test('neither value is blank', () {
      expect(Env.supabaseUrl, isNotEmpty);
      expect(Env.supabaseAnonKey, isNotEmpty);
    });
  });
}
