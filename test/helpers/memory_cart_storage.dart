import 'package:chowflow/features/cart/data/cart_storage.dart';
import 'package:chowflow/features/cart/models/cart_item.dart';

class MemoryCartStorage implements CartStorage {
  final Map<String, List<CartItem>> _carts = {};

  @override
  Future<List<CartItem>> read(String ownerId) async {
    return List<CartItem>.from(_carts[ownerId] ?? const []);
  }

  @override
  Future<void> write(String ownerId, List<CartItem> items) async {
    _carts[ownerId] = List<CartItem>.from(items);
  }

  @override
  Future<void> clear(String ownerId) async {
    _carts.remove(ownerId);
  }
}
