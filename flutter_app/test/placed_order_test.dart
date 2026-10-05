import 'package:chowflow/services/shared/data/rpc_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlacedOrder.fromRpcResponse', () {
    test('parses the single row a place_*_order RPC returns (issue #60)', () {
      final order = PlacedOrder.fromRpcResponse([
        {
          'order_id': 'order-123',
          'subtotal': 1000,
          'delivery_fee': 499,
          'tax': 100,
          'total': 1599,
        },
      ], 'food order');

      expect(order.orderId, 'order-123');
      expect(order.subtotal, 1000);
      expect(order.deliveryFee, 499);
      expect(order.tax, 100);
      expect(order.total, 1599);
    });

    test('rounds a numeric-typed cents field to the nearest integer', () {
      final order = PlacedOrder.fromRpcResponse([
        {
          'order_id': 'order-123',
          'subtotal': 1000.0,
          'delivery_fee': 250,
          'tax': 0,
          'total': 1250,
        },
      ], 'grocery order');

      expect(order.subtotal, 1000);
    });

    test('rejects a non-list response', () {
      expect(
        () => PlacedOrder.fromRpcResponse('order-123', 'food order'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an empty list response', () {
      expect(
        () => PlacedOrder.fromRpcResponse(<Object?>[], 'food order'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a row that is missing a required field', () {
      expect(
        () => PlacedOrder.fromRpcResponse([
          {
            'order_id': 'order-123',
            'subtotal': 1000,
            'delivery_fee': 499,
            // 'tax' missing
            'total': 1599,
          },
        ], 'food order'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a row with a blank order id', () {
      expect(
        () => PlacedOrder.fromRpcResponse([
          {
            'order_id': '   ',
            'subtotal': 1000,
            'delivery_fee': 499,
            'tax': 100,
            'total': 1599,
          },
        ], 'food order'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
