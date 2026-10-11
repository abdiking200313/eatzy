/**
 * Ports `flutter_app/lib/features/addresses/data/delivery_address_repository.dart`
 * (issue #545): data access for the shared `public.delivery_addresses`
 * platform table.
 *
 * As in Flutter, this is the data layer for a real saved-addresses feature
 * that the addresses screen does not consume yet -- the screen still shows
 * hardcoded demo data (see `src/features/addresses/addresses-screen.tsx`).
 */
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { supabase } from '@/platform/supabase/client';

import {
  DeliveryAddressFormatError,
  newDeliveryAddressToRow,
  parseDeliveryAddress,
  type DeliveryAddress,
  type DeliveryAddressWriteRow,
  type NewDeliveryAddress,
} from './delivery-address';

const DELIVERY_ADDRESS_COLUMNS =
  'id, label, recipient_name, phone, street, district, city, is_default, created_at, updated_at';

type SupabaseResult<T> = { data: T | null; error: unknown };

/** A filter chain on `delivery_addresses`, loose enough for every query below. */
interface DeliveryAddressFilterBuilder extends PromiseLike<SupabaseResult<Record<string, unknown>[]>> {
  eq(column: 'id' | 'profile_id', value: string): DeliveryAddressFilterBuilder;
  order(column: 'is_default' | 'created_at', options: { ascending: boolean }): DeliveryAddressFilterBuilder;
  select(columns: string): DeliveryAddressFilterBuilder;
  single(): PromiseLike<SupabaseResult<Record<string, unknown>>>;
}

/**
 * The slice of `supabase` {@link SupabaseDeliveryAddressRepository} depends
 * on, narrowed the same way `profile-repository.ts`'s `ProfileSource` is --
 * lets a test inject `src/test-utils/fake-supabase-client.ts` plus a plain
 * `auth.getSession` stub instead of the real client.
 */
export interface DeliveryAddressSource {
  auth: {
    getSession(): Promise<{ data: { session: { user: { id: string } } | null } }>;
  };
  from(table: 'delivery_addresses'): {
    select(columns: string): DeliveryAddressFilterBuilder;
    insert(row: DeliveryAddressWriteRow & { profile_id: string }): DeliveryAddressFilterBuilder;
    update(row: DeliveryAddressWriteRow): DeliveryAddressFilterBuilder;
    delete(): DeliveryAddressFilterBuilder;
  };
}

/** Mirrors the Dart `StateError` every method throws before touching the network when no one is signed in. */
export class DeliveryAddressSignInRequiredError extends Error {
  constructor() {
    super('Sign in before loading saved addresses.');
    this.name = 'DeliveryAddressSignInRequiredError';
  }
}

export interface DeliveryAddressRepository {
  /** The signed-in profile's saved addresses, default address first, then most recently created first. */
  fetchSavedAddresses(): Promise<DeliveryAddress[]>;

  create(address: NewDeliveryAddress): Promise<DeliveryAddress>;

  /**
   * Updates the saved address identified by `id`. Only rows owned by the
   * signed-in profile can ever match, both via RLS and via the explicit
   * `profile_id` filter -- another profile's address id resolves as "not
   * found" (a `.single()` error), not as a permission error.
   */
  update(id: string, address: NewDeliveryAddress): Promise<DeliveryAddress>;

  delete(id: string): Promise<void>;
}

export class SupabaseDeliveryAddressRepository implements DeliveryAddressRepository {
  private readonly client: DeliveryAddressSource;

  constructor(client: DeliveryAddressSource = supabase as unknown as DeliveryAddressSource) {
    this.client = client;
  }

  async fetchSavedAddresses(): Promise<DeliveryAddress[]> {
    const profileId = await this.requireProfileId();

    const { data, error } = await this.client
      .from('delivery_addresses')
      .select(DELIVERY_ADDRESS_COLUMNS)
      .eq('profile_id', profileId)
      .order('is_default', { ascending: false })
      .order('created_at', { ascending: false });
    if (error) throw error;

    // Parse each row independently: one malformed row must not blank the
    // whole address list -- same defensive approach as `fetchActivities`.
    const addresses: DeliveryAddress[] = [];
    for (const row of data ?? []) {
      try {
        addresses.push(parseDeliveryAddress(row));
      } catch (parseError) {
        if (!(parseError instanceof DeliveryAddressFormatError)) throw parseError;
        ErrorReporting.instance.reportError(
          parseError,
          parseError.stack,
          'SupabaseDeliveryAddressRepository.fetchSavedAddresses',
        );
      }
    }
    return addresses;
  }

  async create(address: NewDeliveryAddress): Promise<DeliveryAddress> {
    const profileId = await this.requireProfileId();

    const { data, error } = await this.client
      .from('delivery_addresses')
      .insert({ ...newDeliveryAddressToRow(address), profile_id: profileId })
      .select(DELIVERY_ADDRESS_COLUMNS)
      .single();
    if (error) throw error;
    if (data == null) throw new Error('delivery_addresses insert returned no row.');
    return parseDeliveryAddress(data);
  }

  async update(id: string, address: NewDeliveryAddress): Promise<DeliveryAddress> {
    const profileId = await this.requireProfileId();

    const { data, error } = await this.client
      .from('delivery_addresses')
      .update(newDeliveryAddressToRow(address))
      .eq('id', id)
      .eq('profile_id', profileId)
      .select(DELIVERY_ADDRESS_COLUMNS)
      .single();
    if (error) throw error;
    if (data == null) throw new Error('delivery_addresses update returned no row.');
    return parseDeliveryAddress(data);
  }

  async delete(id: string): Promise<void> {
    const profileId = await this.requireProfileId();

    const { error } = await this.client.from('delivery_addresses').delete().eq('id', id).eq('profile_id', profileId);
    if (error) throw error;
  }

  private async requireProfileId(): Promise<string> {
    const {
      data: { session },
    } = await this.client.auth.getSession();
    const profileId = session?.user.id;
    if (!profileId) {
      throw new DeliveryAddressSignInRequiredError();
    }
    return profileId;
  }
}
