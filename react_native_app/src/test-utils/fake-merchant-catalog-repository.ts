/**
 * Ports `flutter_app/test/helpers/fake_merchant_repositories.dart`'s
 * `FakeMerchantCatalogRepository` (issue #410 / P9-05): an in-memory
 * `MerchantCatalogRepository` for controller/screen tests.
 */
import type { MerchantCatalogItem, PharmacyCategory } from '@/features/merchant/catalog/api/merchant-catalog-item';
import type { MerchantCatalogRepository } from '@/features/merchant/catalog/api/merchant-catalog-repository';

export class FakeMerchantCatalogRepository implements MerchantCatalogRepository {
  private items: MerchantCatalogItem[];
  private readonly categories: PharmacyCategory[];
  private nextId = 1;

  /** When set, every method throws this instead of succeeding. */
  failureToThrow: unknown = null;

  constructor({
    initialItems = [],
    categories = [],
  }: { initialItems?: MerchantCatalogItem[]; categories?: PharmacyCategory[] } = {}) {
    this.items = [...initialItems];
    this.categories = [...categories];
  }

  async fetchItems(): Promise<MerchantCatalogItem[]> {
    this.throwIfFailing();
    return [...this.items];
  }

  async createItem(draft: MerchantCatalogItem): Promise<MerchantCatalogItem> {
    this.throwIfFailing();
    const created: MerchantCatalogItem = { ...draft, id: `fake-item-${this.nextId++}`, name: draft.name.trim() };
    this.items.push(created);
    return created;
  }

  async updateItem(item: MerchantCatalogItem): Promise<MerchantCatalogItem> {
    this.throwIfFailing();
    const index = this.items.findIndex((existing) => existing.id === item.id);
    if (index === -1) throw new Error(`Item not found: ${item.id}`);
    this.items[index] = item;
    return item;
  }

  async deleteItem(item: MerchantCatalogItem): Promise<void> {
    this.throwIfFailing();
    this.items = this.items.filter((existing) => existing.id !== item.id);
  }

  async setAvailability({ item, isAvailable }: { item: MerchantCatalogItem; isAvailable: boolean }): Promise<MerchantCatalogItem> {
    this.throwIfFailing();
    const index = this.items.findIndex((existing) => existing.id === item.id);
    if (index === -1) throw new Error(`Item not found: ${item.id}`);
    const updated = { ...item, isAvailable };
    this.items[index] = updated;
    return updated;
  }

  async fetchPharmacyCategories(): Promise<PharmacyCategory[]> {
    this.throwIfFailing();
    return [...this.categories];
  }

  private throwIfFailing(): void {
    if (this.failureToThrow != null) throw this.failureToThrow;
  }
}
