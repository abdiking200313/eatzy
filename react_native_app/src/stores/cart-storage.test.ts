/**
 * Ports `flutter_app/test/cart_storage_test.dart` (issue #180 on the Flutter
 * side, #376 here): the `CartWriteQueue` group one-for-one, the
 * `SharedPreferencesCartStorage.read` group against
 * {@link AsyncStorageCartStorage} (using an in-memory fake `KeyValueStore`,
 * the same pattern `onboarding-preferences.test.ts` uses for its own
 * injectable storage), and the `readCartLogged` group one-for-one.
 *
 * Also covers this file's own per-module/per-owner key-scoping contract
 * (`${keyPrefix}.${ownerId}`) directly, since that's the one piece of
 * `AsyncStorageCartStorage` the Dart test exercises only indirectly (through
 * each vertical's own distinct `keyPrefix`).
 */
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';

import { AsyncStorageCartStorage, CartWriteQueue, GUEST_CART_OWNER, readCartLogged, type CartStorage, type KeyValueStore } from './cart-storage';

interface Item {
  id: string;
}

function toJson(item: Item): Record<string, unknown> {
  return { id: item.id };
}

function fromJson(json: Record<string, unknown>): Item {
  return { id: json.id as string };
}

function createInMemoryKeyValueStore(initial: Record<string, string> = {}): KeyValueStore {
  const data = new Map(Object.entries(initial));
  return {
    getItem: async (key) => data.get(key) ?? null,
    setItem: async (key, value) => {
      data.set(key, value);
    },
    removeItem: async (key) => {
      data.delete(key);
    },
  };
}

class FakeErrorReporter implements ErrorReporter {
  readonly reported: { error: unknown; context?: string }[] = [];

  reportError(error: unknown, _stack?: string, context?: string): void {
    this.reported.push({ error, context });
  }
}

class ThrowingCartStorage<T> implements CartStorage<T> {
  async read(_ownerId: string): Promise<T[]> {
    throw new Error('storage unavailable');
  }
  async write(_ownerId: string, _items: T[]): Promise<void> {}
  async clear(_ownerId: string): Promise<void> {}
}

describe('CartWriteQueue (issue #180)', () => {
  let originalReporter: ErrorReporter;
  let fakeReporter: FakeErrorReporter;

  beforeEach(() => {
    originalReporter = ErrorReporting.instance;
    fakeReporter = new FakeErrorReporter();
    ErrorReporting.instance = fakeReporter;
  });

  afterEach(() => {
    ErrorReporting.instance = originalReporter;
  });

  it('a failed write is reported rather than becoming an unhandled error', async () => {
    const queue = new CartWriteQueue('TestController');

    // The returned promise must resolve normally (not reject) even though
    // the write itself fails -- otherwise a fire-and-forget caller
    // (`void queue.enqueue(...)`) would produce an unhandled rejection.
    await queue.enqueue(async () => {
      throw new Error('disk full');
    });

    expect(fakeReporter.reported).toHaveLength(1);
    expect(fakeReporter.reported[0].context).toBe('TestController.enqueue');
    expect(fakeReporter.reported[0].error).toBeInstanceOf(Error);
    expect((fakeReporter.reported[0].error as Error).message).toContain('disk full');
  });

  it('a later write still gets a chance to persist after an earlier one fails', async () => {
    const queue = new CartWriteQueue('TestController');
    const persisted: number[] = [];

    await queue.enqueue(async () => {
      throw new Error('boom');
    });
    await queue.enqueue(async () => {
      persisted.push(1);
    });

    expect(persisted).toEqual([1]);
    expect(fakeReporter.reported).toHaveLength(1);
  });

  it('a successful write reports nothing', async () => {
    const queue = new CartWriteQueue('TestController');
    await queue.enqueue(async () => {});
    expect(fakeReporter.reported).toEqual([]);
  });

  it('pending resolves once the queued write settles', async () => {
    const queue = new CartWriteQueue('TestController');
    let completed = false;
    const operation = queue.enqueue(async () => {
      completed = true;
    });

    expect(queue.pending).toBe(operation);
    await queue.pending;
    expect(completed).toBe(true);
  });
});

describe('AsyncStorageCartStorage.read (issue #180)', () => {
  let originalReporter: ErrorReporter;
  let fakeReporter: FakeErrorReporter;

  beforeEach(() => {
    originalReporter = ErrorReporting.instance;
    fakeReporter = new FakeErrorReporter();
    ErrorReporting.instance = fakeReporter;
  });

  afterEach(() => {
    ErrorReporting.instance = originalReporter;
  });

  it('no saved cart at all returns empty and reports nothing', async () => {
    const storage = new AsyncStorageCartStorage<Item>({
      keyPrefix: 'test.cart',
      toJson,
      fromJson,
      store: createInMemoryKeyValueStore(),
    });

    const result = await storage.read('owner-1');

    expect(result).toEqual([]);
    expect(fakeReporter.reported).toEqual([]);
  });

  it('a corrupted saved cart is reported distinctly from "no saved cart", and is discarded rather than crashing the read', async () => {
    const kv = createInMemoryKeyValueStore({ 'test.cart.owner-1': 'not valid json cart data' });
    const storage = new AsyncStorageCartStorage<Item>({ keyPrefix: 'test.cart', toJson, fromJson, store: kv });

    const result = await storage.read('owner-1');

    expect(result).toEqual([]);
    expect(fakeReporter.reported).toHaveLength(1);
    expect(fakeReporter.reported[0].context).toBe('AsyncStorageCartStorage.read');
    // The broken value is removed so a subsequent read doesn't have to fail
    // (and re-report) the same way again.
    expect(await kv.getItem('test.cart.owner-1')).toBeNull();
    fakeReporter.reported.length = 0;
    expect(await storage.read('owner-1')).toEqual([]);
    expect(fakeReporter.reported).toEqual([]);
  });

  it('a saved value that is valid JSON but not a list is also treated as corrupted', async () => {
    const kv = createInMemoryKeyValueStore({ 'test.cart.owner-1': JSON.stringify({ not: 'an array' }) });
    const storage = new AsyncStorageCartStorage<Item>({ keyPrefix: 'test.cart', toJson, fromJson, store: kv });

    const result = await storage.read('owner-1');

    expect(result).toEqual([]);
    expect(fakeReporter.reported).toHaveLength(1);
    expect(fakeReporter.reported[0].context).toBe('AsyncStorageCartStorage.read');
  });

  it('writes, reads back, and clears a cart for one owner', async () => {
    const storage = new AsyncStorageCartStorage<Item>({
      keyPrefix: 'test.cart',
      toJson,
      fromJson,
      store: createInMemoryKeyValueStore(),
    });

    await storage.write('owner-1', [{ id: 'a' }, { id: 'b' }]);
    expect(await storage.read('owner-1')).toEqual([{ id: 'a' }, { id: 'b' }]);

    await storage.clear('owner-1');
    expect(await storage.read('owner-1')).toEqual([]);
    expect(fakeReporter.reported).toEqual([]);
  });

  it('scopes persisted values by both keyPrefix (module) and ownerId, so they never collide', async () => {
    const kv = createInMemoryKeyValueStore();
    const foodStorage = new AsyncStorageCartStorage<Item>({ keyPrefix: 'zivo.cart.v1', toJson, fromJson, store: kv });
    const pharmacyStorage = new AsyncStorageCartStorage<Item>({ keyPrefix: 'zivo.cart.v1.pharmacy', toJson, fromJson, store: kv });

    await foodStorage.write('user-1', [{ id: 'food-a' }]);
    await pharmacyStorage.write('user-1', [{ id: 'pharmacy-a' }]);
    await foodStorage.write('user-2', [{ id: 'food-b' }]);

    expect(await foodStorage.read('user-1')).toEqual([{ id: 'food-a' }]);
    expect(await pharmacyStorage.read('user-1')).toEqual([{ id: 'pharmacy-a' }]);
    expect(await foodStorage.read('user-2')).toEqual([{ id: 'food-b' }]);

    // Clearing one module's cart for one owner never touches another
    // module's cart for the same owner, or the same module's cart for a
    // different owner.
    await foodStorage.clear('user-1');
    expect(await foodStorage.read('user-1')).toEqual([]);
    expect(await pharmacyStorage.read('user-1')).toEqual([{ id: 'pharmacy-a' }]);
    expect(await foodStorage.read('user-2')).toEqual([{ id: 'food-b' }]);
  });
});

describe('readCartLogged (issue #180)', () => {
  let originalReporter: ErrorReporter;
  let fakeReporter: FakeErrorReporter;

  beforeEach(() => {
    originalReporter = ErrorReporting.instance;
    fakeReporter = new FakeErrorReporter();
    ErrorReporting.instance = fakeReporter;
  });

  afterEach(() => {
    ErrorReporting.instance = originalReporter;
  });

  it('a missing cart is not reported as a failure -- it is genuinely empty', async () => {
    const storage = new AsyncStorageCartStorage<Item>({
      keyPrefix: 'test.cart',
      toJson,
      fromJson,
      store: createInMemoryKeyValueStore(),
    });

    const result = await readCartLogged(storage, 'owner-1', 'TestController');

    expect(result).toEqual([]);
    expect(fakeReporter.reported).toEqual([]);
  });

  it('a read that throws is reported distinctly from a missing cart, and still resolves to an empty cart', async () => {
    const storage = new ThrowingCartStorage<string>();

    const result = await readCartLogged(storage, 'owner-1', 'TestController');

    expect(result).toEqual([]);
    expect(fakeReporter.reported).toHaveLength(1);
    expect(fakeReporter.reported[0].context).toBe('TestController.loadForOwner');
  });
});

describe('GUEST_CART_OWNER', () => {
  it('is the stable owner key used for a signed-out cart', () => {
    expect(GUEST_CART_OWNER).toBe('guest');
  });
});
