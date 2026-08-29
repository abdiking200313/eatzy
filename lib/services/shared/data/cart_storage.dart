import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A per-module, per-owner keyed store for a list of cart-like items of
/// type [T].
///
/// Implementations are expected to scope reads/writes by both the storage
/// module (the food cart, the grocery cart, the pharmacy cart, ...) and the
/// signed-in owner, so switching accounts — or being signed out — never
/// mixes carts between owners or leaks one vertical's cart into another's.
abstract class CartStorage<T> {
  Future<List<T>> read(String ownerId);

  Future<void> write(String ownerId, List<T> items);

  Future<void> clear(String ownerId);
}

/// A [CartStorage] backed by [SharedPreferencesAsync], serialized as JSON
/// under the key `$keyPrefix.$ownerId`.
///
/// [keyPrefix] must be unique per module (e.g. one value for the food cart,
/// another for the grocery cart, another for the pharmacy cart) so the same
/// owner's carts across verticals never collide or overwrite one another.
class SharedPreferencesCartStorage<T> implements CartStorage<T> {
  SharedPreferencesCartStorage({
    required String keyPrefix,
    required Map<String, dynamic> Function(T item) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
  }) : _keyPrefix = keyPrefix,
       _toJson = toJson,
       _fromJson = fromJson;

  final String _keyPrefix;
  final Map<String, dynamic> Function(T item) _toJson;
  final T Function(Map<String, dynamic> json) _fromJson;

  String _keyFor(String ownerId) => '$_keyPrefix.$ownerId';

  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();

  @override
  Future<List<T>> read(String ownerId) async {
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
          .map((item) => _fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
    } on Object {
      // A broken local value should not make the cart screen unusable.
      await _preferences.remove(key);
      return const [];
    }
  }

  @override
  Future<void> write(String ownerId, List<T> items) {
    return _preferences.setString(
      _keyFor(ownerId),
      jsonEncode(items.map(_toJson).toList(growable: false)),
    );
  }

  @override
  Future<void> clear(String ownerId) {
    return _preferences.remove(_keyFor(ownerId));
  }
}
