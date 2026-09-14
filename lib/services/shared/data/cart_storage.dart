import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    } on Object catch (error, stackTrace) {
      // A broken local value should not make the cart screen unusable, but
      // it must not silently present as "no saved cart" either (issue
      // #180) -- a saved value existed here and failed to parse, which is
      // a materially different situation from there being nothing to load.
      debugPrint(
        'SharedPreferencesCartStorage.read: the saved cart for "$key" could '
        'not be read and will be discarded: $error\n$stackTrace',
      );
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

/// Reads [ownerId]'s cart from [storage], logging (rather than silently
/// discarding) any exception [CartStorage.read] itself lets through and
/// substituting an empty cart so callers can keep treating "no cart" and
/// "cart failed to load" the same way at the UI layer, per issue #180.
///
/// [SharedPreferencesCartStorage.read] already recovers from a corrupted
/// stored value on its own (logging as it does so) and only ever returns
/// normally, so this mainly guards against the storage layer itself
/// throwing (e.g. the underlying platform channel failing). Either way, the
/// resulting log line is explicitly distinguishable from "there was no
/// saved cart for this owner" -- that case returns an empty list without
/// going through this catch at all, so it is never logged as a failure.
///
/// [label] identifies the calling controller/vertical (e.g.
/// `'GroceryController'`) so a failure can be traced back to which cart it
/// came from.
Future<List<T>> readCartLogged<T>(
  CartStorage<T> storage,
  String ownerId, {
  required String label,
}) async {
  try {
    return await storage.read(ownerId);
  } on Object catch (error, stackTrace) {
    debugPrint(
      '$label.loadForOwner: reading the cart for owner "$ownerId" failed '
      'and will be treated as empty: $error\n$stackTrace',
    );
    return const [];
  }
}

/// Serializes cart persistence writes for one controller so overlapping
/// cart mutations don't race each other, while guaranteeing a failed write
/// is neither an unhandled asynchronous error nor silently invisible
/// (issue #180).
///
/// Previously this queuing logic was duplicated verbatim across the food,
/// grocery, and pharmacy cart controllers, each guarding only the *previous*
/// queued write and leaving the write it was actually enqueuing unguarded --
/// grocery/pharmacy then called it fire-and-forget via `unawaited()`, so a
/// failed write became a silently dropped unhandled Future error, while food
/// (which did await it) let the failure bubble into UI call sites instead.
/// Lifting it here fixes all three at once instead of patching three
/// separate copies.
class CartWriteQueue {
  CartWriteQueue({required this.label});

  /// Identifies the owning controller/vertical (e.g. `'CartController'`,
  /// `'GroceryController'`, `'PharmacyController'`) in failure logs.
  final String label;

  Future<void> _pendingWrite = Future<void>.value();

  /// The in-flight (or, once settled, most recently finished) queued write.
  /// Exposed primarily so tests can await outstanding cart persistence
  /// before asserting on stored state.
  Future<void> get pending => _pendingWrite;

  /// Queues [write] behind whatever write is currently pending. A later
  /// write always gets its turn -- an earlier write failing does not block
  /// it -- and a failure from [write] itself is logged rather than left to
  /// become an unhandled asynchronous error or propagate to the caller.
  Future<void> enqueue(Future<void> Function() write) {
    final previousWrite = _pendingWrite;
    final operation = () async {
      try {
        await previousWrite;
      } on Object {
        // A later cart change should still get a chance to persist.
      }
      try {
        await write();
      } on Object catch (error, stackTrace) {
        debugPrint(
          '$label: a cart write failed and was dropped: $error\n$stackTrace',
        );
      }
    }();
    _pendingWrite = operation;
    return operation;
  }
}
