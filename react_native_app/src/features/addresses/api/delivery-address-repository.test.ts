/**
 * Ports `flutter_app/test/delivery_address_repository_test.dart` (issue
 * #545) against `src/test-utils/fake-supabase-client.ts` plus a plain
 * `auth.getSession` stub (same approach as `profile-repository.test.ts`),
 * instead of the Dart test's real `SupabaseClient` + `MockClient`. The
 * Dart "captured request body" assertion becomes the recorded `insert`
 * step's argument; `throwsFormatException`/`throwsStateError` become
 * `DeliveryAddressFormatError`/`DeliveryAddressSignInRequiredError`.
 *
 * All six Dart cases are ported (marked "Dart:"); the rest cover `update`,
 * `delete`, query shape and error propagation, which the Dart file doesn't.
 */
import { ErrorReporting, NoopErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { DeliveryAddressFormatError, newDeliveryAddressToRow, parseDeliveryAddress } from './delivery-address';
import {
  DeliveryAddressSignInRequiredError,
  SupabaseDeliveryAddressRepository,
  type DeliveryAddressSource,
} from './delivery-address-repository';

// The repository imports the real `@/platform/supabase/client` for its
// default `client`, which loads env vars at import time -- see
// `merchant-role-service.test.ts`.
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

let originalReporter: ErrorReporter;
beforeEach(() => {
  originalReporter = ErrorReporting.instance;
  ErrorReporting.instance = new NoopErrorReporter();
});
afterEach(() => {
  ErrorReporting.instance = originalReporter;
});

function clientFor(userId: string | null) {
  const fake = createFakeSupabaseClient();
  const client = Object.assign(fake, {
    auth: {
      getSession: async () => ({ data: { session: userId ? { user: { id: userId } } : null } }),
    },
  });
  return { fake, client: client as unknown as DeliveryAddressSource };
}

const homeRow = {
  id: 'addr-1',
  label: 'Home',
  recipient_name: 'Asha Ali',
  phone: '+252 61 234 5678',
  street: 'Taleex Road, blue gate',
  district: 'Hodan',
  city: 'Mogadishu',
  is_default: true,
  created_at: '2026-09-01T00:00:00.000Z',
  updated_at: '2026-09-02T00:00:00.000Z',
};

const workAddress = {
  label: 'Work',
  recipientName: 'Asha Ali',
  phone: '+252 61 234 5678',
  street: 'Airport Road',
  district: 'Wadajir',
  city: 'Mogadishu',
};

const workRow = {
  id: 'addr-new',
  label: 'Work',
  recipient_name: 'Asha Ali',
  phone: '+252 61 234 5678',
  street: 'Airport Road',
  district: 'Wadajir',
  city: 'Mogadishu',
  is_default: false,
  created_at: '2026-09-03T00:00:00.000Z',
  updated_at: '2026-09-03T00:00:00.000Z',
};

describe('parseDeliveryAddress (DeliveryAddress.fromMap)', () => {
  it('Dart: parses a complete row', () => {
    const address = parseDeliveryAddress(homeRow);

    expect(address).toEqual({
      id: 'addr-1',
      label: 'Home',
      recipientName: 'Asha Ali',
      phone: '+252 61 234 5678',
      street: 'Taleex Road, blue gate',
      district: 'Hodan',
      city: 'Mogadishu',
      isDefault: true,
      createdAt: new Date('2026-09-01T00:00:00.000Z'),
      updatedAt: new Date('2026-09-02T00:00:00.000Z'),
    });
  });

  it('Dart: a null label parses to null, not a throw', () => {
    const address = parseDeliveryAddress({ ...homeRow, label: null, is_default: false });

    expect(address.label).toBeUndefined();
    expect(address.isDefault).toBe(false);
  });

  it('Dart: throws when a required field is missing', () => {
    const { label: _label, ...withoutLabel } = homeRow;
    expect(() => parseDeliveryAddress({ ...withoutLabel, recipient_name: '' })).toThrow(DeliveryAddressFormatError);
  });

  it('throws on an unparseable timestamp', () => {
    expect(() => parseDeliveryAddress({ ...homeRow, created_at: 'not a date' })).toThrow(
      new DeliveryAddressFormatError('Invalid delivery address creation time.'),
    );
    expect(() => parseDeliveryAddress({ ...homeRow, updated_at: 'not a date' })).toThrow(
      new DeliveryAddressFormatError('Invalid delivery address update time.'),
    );
  });

  it('treats a non-boolean is_default as false, as `== true` does in Dart', () => {
    expect(parseDeliveryAddress({ ...homeRow, is_default: 'true' }).isDefault).toBe(false);
  });
});

describe('newDeliveryAddressToRow (NewDeliveryAddress.toMap)', () => {
  it('Dart: trims text fields and normalizes a blank label to null', () => {
    const row = newDeliveryAddressToRow({
      label: '  ',
      recipientName: ' Asha Ali ',
      phone: ' +252 61 234 5678 ',
      street: ' Taleex Road ',
      district: ' Hodan ',
      city: ' Mogadishu ',
    });

    expect(row).toEqual({
      label: null,
      recipient_name: 'Asha Ali',
      phone: '+252 61 234 5678',
      street: 'Taleex Road',
      district: 'Hodan',
      city: 'Mogadishu',
      is_default: false,
    });
  });

  it('trims a non-blank label and keeps an explicit isDefault', () => {
    const row = newDeliveryAddressToRow({ ...workAddress, label: ' Work ', isDefault: true });

    expect(row.label).toBe('Work');
    expect(row.is_default).toBe(true);
  });
});

describe('SupabaseDeliveryAddressRepository', () => {
  it('Dart: fetchSavedAddresses skips a malformed row and returns the rest', async () => {
    const { fake, client } = clientFor('user-1');
    fake.queueTableResponse(
      'delivery_addresses',
      fakeSupabaseOk([
        homeRow,
        // Malformed: blank recipient_name. Must be skipped, not blank the whole list.
        { ...workRow, id: 'addr-bad', label: null, recipient_name: '' },
      ]),
    );

    const addresses = await new SupabaseDeliveryAddressRepository(client).fetchSavedAddresses();

    expect(addresses.map((address) => address.id)).toEqual(['addr-1']);
  });

  it('fetchSavedAddresses reports the skipped row', async () => {
    const reportError = jest.fn();
    ErrorReporting.instance = { reportError };
    const { fake, client } = clientFor('user-1');
    fake.queueTableResponse('delivery_addresses', fakeSupabaseOk([{ ...homeRow, city: '' }]));

    await expect(new SupabaseDeliveryAddressRepository(client).fetchSavedAddresses()).resolves.toEqual([]);
    expect(reportError).toHaveBeenCalledWith(
      expect.any(DeliveryAddressFormatError),
      expect.anything(),
      'SupabaseDeliveryAddressRepository.fetchSavedAddresses',
    );
  });

  it("fetchSavedAddresses queries the caller's own rows, default first then newest", async () => {
    const { fake, client } = clientFor('user-1');
    fake.queueTableResponse('delivery_addresses', fakeSupabaseOk([]));

    await new SupabaseDeliveryAddressRepository(client).fetchSavedAddresses();

    expect(fake.calls).toEqual([
      {
        kind: 'table',
        name: 'delivery_addresses',
        steps: [
          {
            method: 'select',
            args: ['id, label, recipient_name, phone, street, district, city, is_default, created_at, updated_at'],
          },
          { method: 'eq', args: ['profile_id', 'user-1'] },
          { method: 'order', args: ['is_default', { ascending: false }] },
          { method: 'order', args: ['created_at', { ascending: false }] },
        ],
      },
    ]);
  });

  it('fetchSavedAddresses propagates a query error', async () => {
    const { fake, client } = clientFor('user-1');
    fake.queueTableResponse('delivery_addresses', fakeSupabaseError('offline'));

    await expect(new SupabaseDeliveryAddressRepository(client).fetchSavedAddresses()).rejects.toMatchObject({
      message: 'offline',
    });
  });

  it('Dart: fetchSavedAddresses throws when no one is signed in', async () => {
    const { fake, client } = clientFor(null);

    await expect(new SupabaseDeliveryAddressRepository(client).fetchSavedAddresses()).rejects.toBeInstanceOf(
      DeliveryAddressSignInRequiredError,
    );
    expect(fake.calls).toEqual([]);
  });

  it('Dart: create posts the new address and parses the inserted row back', async () => {
    const { fake, client } = clientFor('user-1');
    fake.queueTableResponse('delivery_addresses', fakeSupabaseOk(workRow));

    const created = await new SupabaseDeliveryAddressRepository(client).create(workAddress);

    expect(created.id).toBe('addr-new');
    expect(created.label).toBe('Work');
    const insert = fake.calls[0].steps.find((step) => step.method === 'insert');
    expect(insert?.args[0]).toMatchObject({ profile_id: 'user-1', recipient_name: 'Asha Ali' });
    expect(fake.calls[0].steps.map((step) => step.method)).toEqual(['insert', 'select', 'single']);
  });

  it('update scopes the write to the id and the caller profile', async () => {
    const { fake, client } = clientFor('user-1');
    fake.queueTableResponse('delivery_addresses', fakeSupabaseOk({ ...workRow, street: 'Makka Road' }));

    const updated = await new SupabaseDeliveryAddressRepository(client).update('addr-new', {
      ...workAddress,
      street: ' Makka Road ',
    });

    expect(updated.street).toBe('Makka Road');
    const steps = fake.calls[0].steps;
    expect(steps[0]).toEqual({ method: 'update', args: [expect.objectContaining({ street: 'Makka Road' })] });
    expect(steps[0].args[0]).not.toHaveProperty('profile_id');
    expect(steps.slice(1).map((step) => [step.method, ...step.args.slice(0, 2)])).toEqual([
      ['eq', 'id', 'addr-new'],
      ['eq', 'profile_id', 'user-1'],
      ['select', expect.any(String)],
      ['single'],
    ]);
  });

  it("update of another profile's address surfaces the not-found error", async () => {
    const { fake, client } = clientFor('user-1');
    fake.queueTableResponse('delivery_addresses', fakeSupabaseError('JSON object requested, multiple (or no) rows returned', { code: 'PGRST116' }));

    await expect(new SupabaseDeliveryAddressRepository(client).update('someone-elses', workAddress)).rejects.toMatchObject({
      code: 'PGRST116',
    });
  });

  it('delete scopes the delete to the id and the caller profile', async () => {
    const { fake, client } = clientFor('user-1');

    await new SupabaseDeliveryAddressRepository(client).delete('addr-1');

    expect(fake.calls[0].steps).toEqual([
      { method: 'delete', args: [] },
      { method: 'eq', args: ['id', 'addr-1'] },
      { method: 'eq', args: ['profile_id', 'user-1'] },
    ]);
  });

  it('create/update/delete throw before any request when no one is signed in', async () => {
    const { fake, client } = clientFor(null);
    const repository = new SupabaseDeliveryAddressRepository(client);

    await expect(repository.create(workAddress)).rejects.toBeInstanceOf(DeliveryAddressSignInRequiredError);
    await expect(repository.update('addr-1', workAddress)).rejects.toBeInstanceOf(DeliveryAddressSignInRequiredError);
    await expect(repository.delete('addr-1')).rejects.toBeInstanceOf(DeliveryAddressSignInRequiredError);
    expect(fake.calls).toEqual([]);
  });
});
