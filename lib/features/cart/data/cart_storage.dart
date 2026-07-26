import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';

abstract class CartStorage {
  Future<List<CartItem>> read(String ownerId);

  Future<void> write(String ownerId, List<CartItem> items);

  Future<void> clear(String ownerId);
}

class SharedPreferencesCartStorage implements CartStorage {
  static const _keyPrefix = 'zivo.cart.v1';

  String _keyFor(String ownerId) => '$_keyPrefix.$ownerId';

  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();

  @override
  Future<List<CartItem>> read(String ownerId) async {
    final key = _keyFor(ownerId);
    final rawCart = await _preferences.getString(key);
    if (rawCart == null || rawCart.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawCart);
      if (decoded is! List) {
        throw const FormatException('Cart data must be a list');
      }

      return decoded
          .map(
            (item) => CartItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on Object {
      // A broken local value should not make the cart screen unusable.
      await _preferences.remove(key);
      return const [];
    }
  }

  @override
  Future<void> write(String ownerId, List<CartItem> items) {
    return _preferences.setString(
      _keyFor(ownerId),
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  @override
  Future<void> clear(String ownerId) {
    return _preferences.remove(_keyFor(ownerId));
  }
}
