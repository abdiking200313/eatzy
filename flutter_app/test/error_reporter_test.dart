import 'package:chowflow/platform/error_reporting/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorReporting', () {
    late ErrorReporter original;

    setUp(() {
      original = ErrorReporting.instance;
    });

    tearDown(() {
      // Every global error hook and call site reads `ErrorReporting.instance`
      // fresh each time (see main.dart / profile_screen.dart), so restoring
      // it after each test keeps this suite from leaking a fake reporter
      // into unrelated tests.
      ErrorReporting.instance = original;
    });

    test('defaults to a LoggingErrorReporter', () {
      expect(ErrorReporting.instance, isA<LoggingErrorReporter>());
    });

    test(
      'instance is swappable, so a real SDK can replace it in one place',
      () {
        final fake = _FakeErrorReporter();
        ErrorReporting.instance = fake;

        final error = StateError('boom');
        final stack = StackTrace.current;
        ErrorReporting.instance.reportError(error, stack, context: 'test');

        expect(fake.reported, hasLength(1));
        expect(fake.reported.single.error, error);
        expect(fake.reported.single.stack, stack);
        expect(fake.reported.single.context, 'test');
      },
    );

    test('LoggingErrorReporter.reportError does not throw', () {
      // dart:developer's log() call itself is the behavior under test here;
      // asserting it runs without throwing (with and without a context)
      // catches an accidental signature/argument regression without
      // depending on how a test runner happens to surface log output.
      const reporter = LoggingErrorReporter();
      expect(
        () => reporter.reportError(StateError('boom'), StackTrace.current),
        returnsNormally,
      );
      expect(
        () => reporter.reportError(
          StateError('boom'),
          StackTrace.current,
          context: 'unit-test',
        ),
        returnsNormally,
      );
    });
  });
}

class _FakeErrorReporter implements ErrorReporter {
  final List<({Object error, StackTrace stack, String? context})> reported = [];

  @override
  void reportError(Object error, StackTrace stack, {String? context}) {
    reported.add((error: error, stack: stack, context: context));
  }
}
