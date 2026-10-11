/**
 * Ports `flutter_app/test/merchant_store_repository_test.dart` (issue #407 /
 * P9-02) against `src/test-utils/fake-supabase-client.ts` instead of the Dart
 * test's real `SupabaseClient` + `MockClient`. The Dart file guards the
 * queries against the *live* column names (`restaurants.logo_url`, not the
 * stale `schema.sql`'s `image_url`); the request URL's `select`/PATCH body
 * assertions become assertions on the recorded `select`/`update` steps.
 * Adds RN-only coverage for the grocery/pharmacy column mapping, create,
 * owner scoping and error propagation.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk, type FakeSupabaseCall } from '@/test-utils/fake-supabase-client';

import type { MerchantStore } from './merchant-store';
import { MerchantStoreValidationError, SupabaseMerchantStoreRepository, type MerchantStoreSource } from './merchant-store-repository';

// The repository imports the real `@/platform/supabase/client` for its
// default `client`, which loads env vars at import time.
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function setup() {
  const fake = createFakeSupabaseClient();
  const repo = new SupabaseMerchantStoreRepository(fake as unknown as MerchantStoreSource);
  return { fake, repo };
}

function stepArgs(call: FakeSupabaseCall, method: string): unknown[] {
  const step = call.steps.find((s) => s.method === method);
  if (!step) throw new Error(`no ${method} step on ${call.name}`);
  return step.args;
}

function selectedColumns(call: FakeSupabaseCall): string[] {
  return String(stepArgs(call, 'select')[0])
    .split(',')
    .map((c) => c.trim());
}

const foodRow = {
  id: 'r-1',
  name: 'Zivo Grill',
  address: 'Hodan',
  is_open: true,
  description: 'Grills',
  logo_url: 'https://example.com/logo.png',
};

describe('SupabaseMerchantStoreRepository (merchant_store_repository_test.dart)', () => {
  it('the food lookup selects the live restaurants columns', async () => {
    const { fake, repo } = setup();

    expect(await repo.fetchOwnStore('owner-1')).toBeNull();

    const food = fake.calls.find((c) => c.name === 'restaurants')!;
    const columns = selectedColumns(food);
    expect(columns).toEqual(expect.arrayContaining(['id', 'name', 'address', 'is_open']));
    expect(columns).toContain('description');
    expect(columns).toContain('logo_url');
    expect(columns).not.toContain('image_url');
  });

  it('a food store maps logo_url to imageUrl', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse('restaurants', fakeSupabaseOk(foodRow));

    const store = await repo.fetchOwnStore('owner-1');

    expect(store!.vertical).toBe('food');
    expect(store!.imageUrl).toBe('https://example.com/logo.png');
    expect(store!.location).toBe('Hodan');
  });

  it('updating a food store writes logo_url, not image_url', async () => {
    const { fake, repo } = setup();
    const row = { ...foodRow, description: null, logo_url: 'https://example.com/new.png' };
    fake.setDefaultTableResponse('restaurants', fakeSupabaseOk(row));
    const store = (await repo.fetchOwnStore('owner-1'))!;
    fake.calls.length = 0;

    await repo.updateStore(store, {
      ownerId: 'owner-1',
      name: 'Zivo Grill',
      location: 'Hodan',
      isOpen: true,
      imageUrl: 'https://example.com/new.png',
    });

    const body = stepArgs(fake.calls[0], 'update')[0] as Record<string, unknown>;
    expect(body.logo_url).toBe('https://example.com/new.png');
    expect(body).not.toHaveProperty('image_url');
  });
});

describe('SupabaseMerchantStoreRepository (RN-only cases)', () => {
  it('looks up food, then grocery, then pharmacy, scoped by owner_id, and stops at the first match', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse(
      'grocery_stores',
      fakeSupabaseOk({ id: 'bakaal-1', name: 'Bakaal', area: 'Hodan', is_active: false, image_url: null }),
    );

    const store = await repo.fetchOwnStore('owner-1');

    expect(fake.calls.map((c) => c.name)).toEqual(['restaurants', 'grocery_stores']);
    for (const call of fake.calls) {
      expect(stepArgs(call, 'eq')).toEqual(['owner_id', 'owner-1']);
    }
    expect(store).toEqual({
      id: 'bakaal-1',
      vertical: 'grocery',
      name: 'Bakaal',
      location: 'Hodan',
      isOpen: false,
      description: null,
      imageUrl: null,
    });
    expect(selectedColumns(fake.calls[1])).toEqual(['id', 'name', 'area', 'is_active', 'image_url']);
  });

  it('maps a pharmacy store from address/is_active/image_url', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse(
      'pharmacy_stores',
      fakeSupabaseOk({ id: 'ph-1', name: 'Care', address: 'KM4', is_active: true, image_url: 'https://x/p.png' }),
    );

    const store = await repo.fetchOwnStore('owner-1');

    expect(fake.calls.map((c) => c.name)).toEqual(['restaurants', 'grocery_stores', 'pharmacy_stores']);
    expect(store).toMatchObject({ vertical: 'pharmacy', location: 'KM4', isOpen: true, imageUrl: 'https://x/p.png' });
  });

  it('throws the Postgrest error when a lookup fails', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse('restaurants', fakeSupabaseError('column restaurants.image_url does not exist'));

    await expect(repo.fetchOwnStore('owner-1')).rejects.toMatchObject({
      message: 'column restaurants.image_url does not exist',
    });
  });

  it('creates a grocery store with a client-generated slug id and no description column', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse(
      'grocery_stores',
      fakeSupabaseOk({ id: 'bakaal-fresh-abc', name: 'Bakaal Fresh', area: 'Hodan', is_active: true, image_url: null }),
    );

    const store = await repo.createStore({
      vertical: 'grocery',
      ownerId: 'owner-1',
      name: '  Bakaal Fresh ',
      location: ' Hodan ',
      description: 'ignored',
      imageUrl: '   ',
    });

    const body = stepArgs(fake.calls[0], 'insert')[0] as Record<string, unknown>;
    expect(body).toMatchObject({ owner_id: 'owner-1', name: 'Bakaal Fresh', area: 'Hodan', image_url: null });
    expect(body).not.toHaveProperty('description');
    expect(String(body.id)).toMatch(/^bakaal-fresh-[a-z0-9]+$/);
    expect(store.vertical).toBe('grocery');
  });

  it('creates a food store without a client id (server-generated uuid)', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse('restaurants', fakeSupabaseOk(foodRow));

    await repo.createStore({ vertical: 'food', ownerId: 'owner-1', name: 'Zivo Grill', location: 'Hodan', description: ' Grills ' });

    const body = stepArgs(fake.calls[0], 'insert')[0] as Record<string, unknown>;
    expect(body).not.toHaveProperty('id');
    expect(body.description).toBe('Grills');
    expect(body.logo_url).toBeNull();
  });

  it('rejects a blank name before touching the network', async () => {
    const { fake, repo } = setup();
    const store: MerchantStore = {
      id: 'r-1',
      vertical: 'food',
      name: 'Zivo Grill',
      location: 'Hodan',
      isOpen: true,
      description: null,
      imageUrl: null,
    };

    await expect(repo.createStore({ vertical: 'food', ownerId: 'owner-1', name: '   ', location: '' })).rejects.toBeInstanceOf(
      MerchantStoreValidationError,
    );
    await expect(
      repo.updateStore(store, { ownerId: 'owner-1', name: '', location: '', isOpen: true }),
    ).rejects.toThrow('A store name is required.');
    expect(fake.calls).toHaveLength(0);
  });

  it('scopes an update to both the store id and the owner id, writing the vertical-specific columns', async () => {
    const { fake, repo } = setup();
    fake.queueTableResponse(
      'grocery_stores',
      fakeSupabaseOk({ id: 'g-1', name: 'New', area: 'Wadajir', is_active: false, image_url: null }),
    );
    const store: MerchantStore = {
      id: 'g-1',
      vertical: 'grocery',
      name: 'Old',
      location: 'Hodan',
      isOpen: true,
      description: null,
      imageUrl: null,
    };

    const updated = await repo.updateStore(store, { ownerId: 'owner-1', name: 'New', location: 'Wadajir', isOpen: false });

    const call = fake.calls[0];
    expect(call.name).toBe('grocery_stores');
    expect(call.steps.filter((s) => s.method === 'eq').map((s) => s.args)).toEqual([
      ['id', 'g-1'],
      ['owner_id', 'owner-1'],
    ]);
    expect(stepArgs(call, 'update')[0]).toEqual({ name: 'New', area: 'Wadajir', is_active: false, image_url: null });
    expect(updated).toMatchObject({ name: 'New', location: 'Wadajir', isOpen: false });
  });
});
