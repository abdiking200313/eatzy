import 'package:chowflow/platform/error_reporting/crashlytics_error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashlyticsErrorReporter', () {
    late _FakeCrashlyticsClient client;
    late CrashlyticsErrorReporter reporter;

    setUp(() {
      client = _FakeCrashlyticsClient();
      reporter = CrashlyticsErrorReporter(client);
    });

    for (final context in CrashlyticsErrorReporter.globalHookContexts) {
      test('reports "$context" (a global error hook) as fatal', () async {
        final error = StateError('boom');
        final stack = StackTrace.current;

        reporter.reportError(error, stack, context: context);
        // recordError is fire-and-forget (see reportError's doc comment);
        // flush the microtask queue so the fake has recorded the call
        // before asserting on it.
        await Future<void>.value();

        expect(client.recorded, hasLength(1));
        expect(client.recorded.single.exception, error);
        expect(client.recorded.single.stack, stack);
        expect(client.recorded.single.fatal, isTrue);
        expect(client.recorded.single.reason, context);
      });
    }

    test(
      'reports a caught call site (not a global hook) as non-fatal',
      () async {
        final error = StateError('boom');
        final stack = StackTrace.current;

        reporter.reportError(
          error,
          stack,
          context: 'ProfileScreen._loadProfile',
        );
        await Future<void>.value();

        expect(client.recorded, hasLength(1));
        expect(client.recorded.single.fatal, isFalse);
        expect(client.recorded.single.reason, 'ProfileScreen._loadProfile');
      },
    );

    test('reports with no context as non-fatal', () async {
      reporter.reportError(StateError('boom'), StackTrace.current);
      await Future<void>.value();

      expect(client.recorded, hasLength(1));
      expect(client.recorded.single.fatal, isFalse);
      expect(client.recorded.single.reason, isNull);
    });

    test('setUserIdentifier forwards the user id, and clears it with an '
        'empty string when null (sign-out)', () async {
      await reporter.setUserIdentifier('user-123');
      expect(client.userIdentifiers, ['user-123']);

      await reporter.setUserIdentifier(null);
      expect(client.userIdentifiers, ['user-123', '']);
    });
  });
}

class _FakeCrashlyticsClient implements CrashlyticsClient {
  final List<
    ({Object exception, StackTrace? stack, bool fatal, String? reason})
  >
  recorded = [];
  final List<String> userIdentifiers = [];
  bool? collectionEnabled;

  @override
  Future<void> recordError(
    Object exception,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    recorded.add((
      exception: exception,
      stack: stack,
      fatal: fatal,
      reason: reason,
    ));
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    userIdentifiers.add(identifier);
  }

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }
}
