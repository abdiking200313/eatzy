/// Ports `flutter_app/test/helpers/memory_cart_storage.dart`: an in-memory
/// `CartStorage<T>` shared across the food/grocery/pharmacy cart store tests
/// (issue #376) so cart persistence/restore/account-switch behavior can be
/// exercised without touching real `AsyncStorage`.
import type { CartStorage } from '@/stores/cart-storage';

export class MemoryCartStorage<T> implements CartStorage<T> {
  private readonly carts = new Map<string, T[]>();

  async read(ownerId: string): Promise<T[]> {
    return [...(this.carts.get(ownerId) ?? [])];
  }

  async write(ownerId: string, items: T[]): Promise<void> {
    this.carts.set(ownerId, [...items]);
  }

  async clear(ownerId: string): Promise<void> {
    this.carts.delete(ownerId);
  }
}
