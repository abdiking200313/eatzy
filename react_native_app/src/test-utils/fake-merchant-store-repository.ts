/**
 * Ports `flutter_app/test/helpers/fake_merchant_repositories.dart`'s
 * `FakeMerchantStoreRepository` (issue #407 / P9-02): an in-memory
 * `MerchantStoreRepository` for controller/screen tests.
 */
import type { MerchantStore } from '@/features/merchant/store/api/merchant-store';
import type {
  CreateMerchantStoreInput,
  MerchantStoreRepository,
  UpdateMerchantStoreInput,
} from '@/features/merchant/store/api/merchant-store-repository';
import { MERCHANT_VERTICAL_CONFIG } from '@/features/merchant/store/api/merchant-vertical';

export class FakeMerchantStoreRepository implements MerchantStoreRepository {
  private store: MerchantStore | null;

  /** When set, every method throws this instead of succeeding, to exercise error states. */
  failureToThrow: unknown = null;

  constructor({ initialStore = null }: { initialStore?: MerchantStore | null } = {}) {
    this.store = initialStore;
  }

  async fetchOwnStore(_ownerId: string): Promise<MerchantStore | null> {
    this.throwIfFailing();
    return this.store;
  }

  async createStore({ vertical, name, location, description, imageUrl }: CreateMerchantStoreInput): Promise<MerchantStore> {
    this.throwIfFailing();
    const created: MerchantStore = {
      id: 'new-store-1',
      vertical,
      name: name.trim(),
      location: location.trim(),
      isOpen: true,
      description: MERCHANT_VERTICAL_CONFIG[vertical].storeSupportsDescription ? (description?.trim() ?? null) : null,
      imageUrl: imageUrl ?? null,
    };
    this.store = created;
    return created;
  }

  async updateStore(store: MerchantStore, { name, location, isOpen, description, imageUrl }: UpdateMerchantStoreInput): Promise<MerchantStore> {
    this.throwIfFailing();
    // Mirrors the Dart `copyWith`: a null/undefined description/imageUrl keeps the old value.
    const updated: MerchantStore = {
      ...store,
      name: name.trim(),
      location: location.trim(),
      isOpen,
      description: description?.trim() ?? store.description,
      imageUrl: imageUrl?.trim() ?? store.imageUrl,
    };
    this.store = updated;
    return updated;
  }

  private throwIfFailing(): void {
    if (this.failureToThrow != null) throw this.failureToThrow;
  }
}
