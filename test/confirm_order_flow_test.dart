import 'package:chowflow/services/shared/presentation/confirm_order_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmDemoOrder passes the thrown error and stack trace to '
      'onSaveFailed', () async {
    final thrown = Exception('boom');
    Object? capturedError;
    StackTrace? capturedStackTrace;

    final result = await confirmDemoOrder<String, bool, String>(
      validation: true,
      isValid: (validation) => validation,
      onInvalid: (_) => 'invalid',
      placeOrder: () async => throw thrown,
      fallbackOrder: () => 'fallback-order',
      onSaveFailed: (error, stackTrace) {
        capturedError = error;
        capturedStackTrace = stackTrace;
        return 'save-failed';
      },
      recordActivity: (_) {},
      clearCart: () {},
      onConfirmed: (_) => 'confirmed',
    );

    expect(result, 'save-failed');
    expect(capturedError, same(thrown));
    expect(capturedStackTrace, isNotNull);
  });

  test('confirmDemoOrder returns onConfirmed and records activity/clears the '
      'cart when placeOrder succeeds', () async {
    var activityRecorded = false;
    var cartCleared = false;

    final result = await confirmDemoOrder<String, bool, String>(
      validation: true,
      isValid: (validation) => validation,
      onInvalid: (_) => 'invalid',
      placeOrder: () async => 'order-1',
      fallbackOrder: () => 'fallback-order',
      onSaveFailed: (error, stackTrace) => 'save-failed',
      recordActivity: (order) {
        expect(order, 'order-1');
        activityRecorded = true;
      },
      clearCart: () {
        cartCleared = true;
      },
      onConfirmed: (order) => 'confirmed:$order',
    );

    expect(result, 'confirmed:order-1');
    expect(activityRecorded, isTrue);
    expect(cartCleared, isTrue);
  });

  test('confirmDemoOrder returns onInvalid without placing an order', () async {
    var placeOrderCalled = false;

    final result = await confirmDemoOrder<String, bool, String>(
      validation: false,
      isValid: (validation) => validation,
      onInvalid: (_) => 'invalid',
      placeOrder: () async {
        placeOrderCalled = true;
        return 'order-1';
      },
      fallbackOrder: () => 'fallback-order',
      onSaveFailed: (error, stackTrace) => 'save-failed',
      recordActivity: (_) {},
      clearCart: () {},
      onConfirmed: (_) => 'confirmed',
    );

    expect(result, 'invalid');
    expect(placeOrderCalled, isFalse);
  });
}
