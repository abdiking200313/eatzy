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

  group('Env.isUsingProductionDefault (issue #277)', () {
    test(
      'is true when neither SUPABASE_URL nor SUPABASE_ANON_KEY was passed '
      'via --dart-define, i.e. the test run (like an unconfigured '
      'flutter run/build) is falling back to the live production project',
      () {
        expect(Env.isUsingProductionDefault, isTrue);
      },
    );

    test('is defined purely from bool.hasEnvironment, not by comparing against '
        'the literal fallback string values, so it would correctly flip to '
        'false under --dart-define=SUPABASE_URL=...'
        '--dart-define=SUPABASE_ANON_KEY=... even if a caller passed back the '
        'exact same values as the fallback', () {
      const definedUrl = bool.hasEnvironment('SUPABASE_URL');
      const definedKey = bool.hasEnvironment('SUPABASE_ANON_KEY');
      expect(Env.isUsingProductionDefault, !definedUrl || !definedKey);
    });
  });
}
