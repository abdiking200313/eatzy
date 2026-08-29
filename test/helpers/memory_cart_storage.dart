import 'package:chowflow/services/shared/data/cart_storage.dart';

/// An in-memory [CartStorage] used across cart/grocery/pharmacy controller
/// tests so persistence can be exercised without a real SharedPreferences
/// platform channel.
class MemoryCartStorage<T> implements CartStorage<T> {
  final Map<String, List<T>> _carts = {};

  @override
  Future<List<T>> read(String ownerId) async {
    return List<T>.from(_carts[ownerId] ?? const []);
  }

  @override
  Future<void> write(String ownerId, List<T> items) async {
    _carts[ownerId] = List<T>.from(items);
  }

  @override
  Future<void> clear(String ownerId) async {
    _carts.remove(ownerId);
  }
}
