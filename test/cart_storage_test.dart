import 'package:chowflow/services/shared/data/cart_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  group('CartWriteQueue (issue #180)', () {
    late List<String> logs;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      logs = [];
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logs.add(message);
        }
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test(
      'a failed write is logged rather than becoming an unhandled error',
      () async {
        final queue = CartWriteQueue(label: 'TestController');

        // The returned future must complete normally (not throw) even
        // though the write itself fails -- otherwise a fire-and-forget
        // caller (unawaited(...)) would produce an unhandled async error.
        await queue.enqueue(() async {
          throw StateError('disk full');
        });

        expect(
          logs,
          contains(
            contains('TestController: a cart write failed and was dropped'),
          ),
        );
        expect(logs.single, contains('disk full'));
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
      expect(
        logs.where((line) => line.contains('cart write failed')),
        hasLength(1),
      );
    });

    test('a successful write logs nothing', () async {
      final queue = CartWriteQueue(label: 'TestController');
      await queue.enqueue(() async {});
      expect(logs, isEmpty);
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
    late List<String> logs;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      logs = [];
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logs.add(message);
        }
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test('no saved cart at all returns empty and logs nothing', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final storage = SharedPreferencesCartStorage<_Item>(
        keyPrefix: 'test.cart',
        toJson: (item) => {'id': item.id},
        fromJson: (json) => _Item(json['id'] as String),
      );

      final result = await storage.read('owner-1');

      expect(result, isEmpty);
      expect(logs, isEmpty);
    });

    test('a corrupted saved cart is distinguished in the log from "no saved '
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
      expect(
        logs,
        contains(
          contains(
            'SharedPreferencesCartStorage.read: the saved cart for '
            '"test.cart.owner-1" could not be read',
          ),
        ),
      );
    });
  });

  group('readCartLogged (issue #180)', () {
    late List<String> logs;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      logs = [];
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logs.add(message);
        }
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test(
      'a missing cart is not logged as a failure -- it is genuinely empty',
      () async {
        final storage = MemoryCartStorage<String>();
        final result = await readCartLogged(
          storage,
          'owner-1',
          label: 'TestController',
        );

        expect(result, isEmpty);
        expect(logs, isEmpty);
      },
    );

    test('a read that throws is logged distinctly from a missing cart, and '
        'still resolves to an empty cart', () async {
      final storage = _ThrowingCartStorage<String>();
      final result = await readCartLogged(
        storage,
        'owner-1',
        label: 'TestController',
      );

      expect(result, isEmpty);
      expect(
        logs,
        contains(
          contains(
            'TestController.loadForOwner: reading the cart for owner '
            '"owner-1" failed',
          ),
        ),
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
