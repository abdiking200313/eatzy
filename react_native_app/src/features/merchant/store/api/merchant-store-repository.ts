/**
 * Ports `flutter_app/lib/features/merchant/store/data/merchant_store_repository.dart`
 * (issue #407 / P9-02): data access for the signed-in merchant's own store.
 *
 * Every method is scoped by `owner_id`, both because RLS makes any other row
 * unreachable (`owner_id = auth.uid()` on select/update/delete, plus a role
 * check on insert -- see
 * `supabase/migrations/20260830130000_add_merchant_catalog_write_policies.sql`)
 * and because the client itself should never attempt to query or mutate a
 * store it does not own.
 */
import { supabase } from '@/platform/supabase/client';

import { generateMerchantSlugId } from '../../shared/merchant-slug-id';
import { merchantStoreFromRow, type MerchantStore } from './merchant-store';
import { MERCHANT_VERTICALS, MERCHANT_VERTICAL_CONFIG, type MerchantVertical } from './merchant-vertical';

type Row = Record<string, unknown>;
type SupabaseResult<T> = { data: T | null; error: unknown };

interface StoreFilterChain {
  eq(column: string, value: unknown): StoreFilterChain;
  select(columns: string): StoreFilterChain;
  single(): PromiseLike<SupabaseResult<Row>>;
  maybeSingle(): PromiseLike<SupabaseResult<Row>>;
}

/**
 * The slice of `supabase` {@link SupabaseMerchantStoreRepository} depends
 * on, narrowed like `profile-repository.ts`'s `ProfileSource` so a test can
 * inject `src/test-utils/fake-supabase-client.ts` instead of the real client.
 */
export interface MerchantStoreSource {
  from(table: string): {
    select(columns: string): StoreFilterChain;
    insert(values: Row): StoreFilterChain;
    update(values: Row): StoreFilterChain;
  };
}

/** Mirrors the Dart `FormatException('A store name is required.')`. */
export class MerchantStoreValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MerchantStoreValidationError';
  }
}

export interface CreateMerchantStoreInput {
  vertical: MerchantVertical;
  ownerId: string;
  name: string;
  location: string;
  description?: string | null;
  imageUrl?: string | null;
}

export interface UpdateMerchantStoreInput {
  ownerId: string;
  name: string;
  location: string;
  isOpen: boolean;
  description?: string | null;
  imageUrl?: string | null;
}

export interface MerchantStoreRepository {
  /**
   * Looks for a store owned by `ownerId` across all three verticals (food,
   * then grocery, then pharmacy) and returns the first match, or `null` if
   * the merchant has no store yet in any vertical.
   */
  fetchOwnStore(ownerId: string): Promise<MerchantStore | null>;

  /** Creates a new store for `ownerId` in `vertical`. The insert RLS policy re-checks the merchant role server-side. */
  createStore(input: CreateMerchantStoreInput): Promise<MerchantStore>;

  /** Updates the caller's own `store` (which identifies the row/vertical) with the new field values. */
  updateStore(store: MerchantStore, input: UpdateMerchantStoreInput): Promise<MerchantStore>;
}

function selectColumns(vertical: MerchantVertical): string {
  const config = MERCHANT_VERTICAL_CONFIG[vertical];
  return [
    'id',
    'name',
    config.storeLocationColumn,
    config.storeActiveColumn,
    ...(config.storeSupportsDescription ? ['description'] : []),
    config.storeImageColumn,
  ].join(', ');
}

function nullIfBlank(value: string | null | undefined): string | null {
  const trimmed = value?.trim() ?? '';
  return trimmed.length === 0 ? null : trimmed;
}

function requireName(name: string): string {
  const trimmed = name.trim();
  if (trimmed.length === 0) {
    throw new MerchantStoreValidationError('A store name is required.');
  }
  return trimmed;
}

function unwrapRow({ data, error }: SupabaseResult<Row>): Row {
  if (error) throw error;
  if (data == null) throw new Error('The store row was not returned.');
  return data;
}

export class SupabaseMerchantStoreRepository implements MerchantStoreRepository {
  private readonly client: MerchantStoreSource;

  constructor(client: MerchantStoreSource = supabase as unknown as MerchantStoreSource) {
    this.client = client;
  }

  async fetchOwnStore(ownerId: string): Promise<MerchantStore | null> {
    for (const vertical of MERCHANT_VERTICALS) {
      const { data, error } = await this.client
        .from(MERCHANT_VERTICAL_CONFIG[vertical].storeTable)
        .select(selectColumns(vertical))
        .eq('owner_id', ownerId)
        .maybeSingle();
      if (error) throw error;
      if (data != null) {
        return merchantStoreFromRow(data, vertical);
      }
    }
    return null;
  }

  async createStore({
    vertical,
    ownerId,
    name,
    location,
    description,
    imageUrl,
  }: CreateMerchantStoreInput): Promise<MerchantStore> {
    const trimmedName = requireName(name);
    const config = MERCHANT_VERTICAL_CONFIG[vertical];

    const payload: Row = {
      owner_id: ownerId,
      name: trimmedName,
      [config.storeLocationColumn]: location.trim(),
      ...(config.storeSupportsDescription ? { description: description?.trim() ?? null } : {}),
      [config.storeImageColumn]: nullIfBlank(imageUrl),
    };
    if (!config.storeIdIsServerGenerated) {
      payload.id = generateMerchantSlugId(trimmedName);
    }

    const result = await this.client.from(config.storeTable).insert(payload).select(selectColumns(vertical)).single();
    return merchantStoreFromRow(unwrapRow(result), vertical);
  }

  async updateStore(
    store: MerchantStore,
    { ownerId, name, location, isOpen, description, imageUrl }: UpdateMerchantStoreInput,
  ): Promise<MerchantStore> {
    const trimmedName = requireName(name);
    const vertical = store.vertical;
    const config = MERCHANT_VERTICAL_CONFIG[vertical];

    const payload: Row = {
      name: trimmedName,
      [config.storeLocationColumn]: location.trim(),
      [config.storeActiveColumn]: isOpen,
      ...(config.storeSupportsDescription ? { description: description?.trim() ?? null } : {}),
      [config.storeImageColumn]: nullIfBlank(imageUrl),
    };

    const result = await this.client
      .from(config.storeTable)
      .update(payload)
      // Belt-and-braces client-side scoping on top of the server-side RLS predicate.
      .eq('id', store.id)
      .eq('owner_id', ownerId)
      .select(selectColumns(vertical))
      .single();
    return merchantStoreFromRow(unwrapRow(result), vertical);
  }
}
