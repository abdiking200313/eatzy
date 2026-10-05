import 'package:chowflow/platform/error_reporting/error_reporter.dart';
import 'package:chowflow/services/shared/data/cart_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  group('CartWriteQueue (issue #180)', () {
    late ErrorReporter originalReporter;
    late _FakeErrorReporter fakeReporter;

    setUp(() {
      originalReporter = ErrorReporting.instance;
      fakeReporter = _FakeErrorReporter();
      ErrorReporting.instance = fakeReporter;
    });

    tearDown(() {
      ErrorReporting.instance = originalReporter;
    });

    test(
      'a failed write is reported rather than becoming an unhandled error',
      () async {
        final queue = CartWriteQueue(label: 'TestController');

        // The returned future must complete normally (not throw) even
        // though the write itself fails -- otherwise a fire-and-forget
        // caller (unawaited(...)) would produce an unhandled async error.
        await queue.enqueue(() async {
          throw StateError('disk full');
        });

        expect(fakeReporter.reported, hasLength(1));
        expect(fakeReporter.reported.single.context, 'TestController.enqueue');
        expect(fakeReporter.reported.single.error, isA<StateError>());
        expect(
          fakeReporter.reported.single.error.toString(),
          contains('disk full'),
        );
      },
    );

    test('a later write still gets a chance to persist after an earlier one '
        'fails', () async {
      final queue = CartWriteQueue(label: 'TestController');
      final persisted = <int>[];

      await queue.enqueue(() async {
        throw StateError('boom');
      });
      await queue.enqueue(() async {
        persisted.add(1);
      });

      expect(persisted, [1]);
      expect(fakeReporter.reported, hasLength(1));
    });

    test('a successful write reports nothing', () async {
      final queue = CartWriteQueue(label: 'TestController');
      await queue.enqueue(() async {});
      expect(fakeReporter.reported, isEmpty);
    });

    test('pending resolves once the queued write settles', () async {
      final queue = CartWriteQueue(label: 'TestController');
      var completed = false;
      final operation = queue.enqueue(() async {
        completed = true;
      });

      expect(identical(queue.pending, operation), isTrue);
      await queue.pending;
      expect(completed, isTrue);
    });
  });

  group('SharedPreferencesCartStorage.read (issue #180)', () {
    late ErrorReporter originalReporter;
    late _FakeErrorReporter fakeReporter;

    setUp(() {
      originalReporter = ErrorReporting.instance;
      fakeReporter = _FakeErrorReporter();
      ErrorReporting.instance = fakeReporter;
    });

    tearDown(() {
      ErrorReporting.instance = originalReporter;
    });

    test('no saved cart at all returns empty and reports nothing', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final storage = SharedPreferencesCartStorage<_Item>(
        keyPrefix: 'test.cart',
        toJson: (item) => {'id': item.id},
        fromJson: (json) => _Item(json['id'] as String),
      );

      final result = await storage.read('owner-1');

      expect(result, isEmpty);
      expect(fakeReporter.reported, isEmpty);
    });

    test('a corrupted saved cart is reported distinctly from "no saved '
        'cart", and is discarded rather than crashing the read', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'test.cart.owner-1': 'not valid json cart data',
          });
      final storage = SharedPreferencesCartStorage<_Item>(
        keyPrefix: 'test.cart',
        toJson: (item) => {'id': item.id},
        fromJson: (json) => _Item(json['id'] as String),
      );

      final result = await storage.read('owner-1');

      expect(result, isEmpty);
      expect(fakeReporter.reported, hasLength(1));
      expect(
        fakeReporter.reported.single.context,
        'SharedPreferencesCartStorage.read',
      );
    });
  });

  group('readCartLogged (issue #180)', () {
    late ErrorReporter originalReporter;
    late _FakeErrorReporter fakeReporter;

    setUp(() {
      originalReporter = ErrorReporting.instance;
      fakeReporter = _FakeErrorReporter();
      ErrorReporting.instance = fakeReporter;
    });

    tearDown(() {
      ErrorReporting.instance = originalReporter;
    });

    test(
      'a missing cart is not reported as a failure -- it is genuinely empty',
      () async {
        final storage = MemoryCartStorage<String>();
        final result = await readCartLogged(
          storage,
          'owner-1',
          label: 'TestController',
        );

        expect(result, isEmpty);
        expect(fakeReporter.reported, isEmpty);
      },
    );

    test('a read that throws is reported distinctly from a missing cart, '
        'and still resolves to an empty cart', () async {
      final storage = _ThrowingCartStorage<String>();
      final result = await readCartLogged(
        storage,
        'owner-1',
        label: 'TestController',
      );

      expect(result, isEmpty);
      expect(fakeReporter.reported, hasLength(1));
      expect(
        fakeReporter.reported.single.context,
        'TestController.loadForOwner',
      );
    });
  });
}

class _Item {
  _Item(this.id);
  final String id;
}

class _ThrowingCartStorage<T> implements CartStorage<T> {
  @override
  Future<List<T>> read(String ownerId) async {
    throw StateError('storage unavailable');
  }

  @override
  Future<void> write(String ownerId, List<T> items) async {}

  @override
  Future<void> clear(String ownerId) async {}
}

class _FakeErrorReporter implements ErrorReporter {
  final List<({Object error, StackTrace stack, String? context})> reported = [];

  @override
  void reportError(Object error, StackTrace stack, {String? context}) {
    reported.add((error: error, stack: stack, context: context));
  }
}
