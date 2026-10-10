/**
 * `fetchMenu` has no dedicated Flutter test file of its own (checked
 * `flutter_app/test/` directly) -- `restaurant_screen_test.dart`'s three
 * direct `MenuItem.fromMap` cases (ported below, against `menuItemFromRow`)
 * are the only pre-existing coverage; the rest is new, focused coverage for
 * this port's own `fetchMenu`/`groupItemsByCategory` contract -- category
 * sort (alphabetical, case-insensitive, with 'Other' always last) and the
 * per-item `InvalidMenuItemPriceError` handling that excludes just the bad
 * item (reporting it) rather than failing the whole menu load -- against
 * `src/test-utils/fake-supabase-client.ts`, the same way
 * `restaurant-repository.test.ts` tests `fetchRestaurants`.
 */
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { fetchMenu, type RestaurantMenuSource } from './restaurant-menu-repository';
import { InvalidMenuItemPriceError, menuItemFromRow } from './restaurant-menu';

// `restaurant-menu-repository.ts` imports the real `@/platform/supabase/client`
// for its default `client` parameter, used only when a test doesn't inject
// its own (every test below does) -- see merchant-role-service.test.ts's
// own comment for why that import needs stubbing under Jest.
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

class FakeErrorReporter implements ErrorReporter {
  readonly reported: { error: unknown; context?: string }[] = [];

  reportError(error: unknown, _stack?: string, context?: string): void {
    this.reported.push({ error, context });
  }
}

function fakeClient() {
  return createFakeSupabaseClient() as unknown as RestaurantMenuSource & ReturnType<typeof createFakeSupabaseClient>;
}

const restaurantRow = { id: 'restaurant-1', name: 'Test Kitchen', description: 'Fresh food made daily', logo_url: '' };

describe('menuItemFromRow', () => {
  it('parses numeric strings from Supabase', () => {
    const item = menuItemFromRow({
      id: 'item-1',
      name: 'Chicken Wrap',
      description: null,
      price: '450',
      image_url: null,
      categorie_id: 'wraps',
      item_categories: null,
    });

    expect(item.price).toBe(450);
    expect(item.description).toBe('');
    expect(item.categoryId).toBe('wraps');
  });

  it("throws instead of silently pricing at $0.00 for an unparseable price (#62)", () => {
    expect(() =>
      menuItemFromRow({
        id: 'item-2',
        name: 'Mystery Item',
        description: null,
        price: 'not-a-number',
        image_url: null,
        categorie_id: 'mains',
        item_categories: null,
      }),
    ).toThrow(InvalidMenuItemPriceError);
  });

  it('throws for a missing price rather than defaulting to $0.00', () => {
    expect(() =>
      menuItemFromRow({
        id: 'item-3',
        name: 'No Price Item',
        description: null,
        price: null,
        image_url: null,
        categorie_id: 'mains',
        item_categories: null,
      }),
    ).toThrow(InvalidMenuItemPriceError);
  });

  it('throws for a negative price', () => {
    expect(() =>
      menuItemFromRow({
        id: 'item-4',
        name: 'Negative Item',
        description: null,
        price: -5,
        image_url: null,
        categorie_id: 'mains',
        item_categories: null,
      }),
    ).toThrow(InvalidMenuItemPriceError);
  });

  it('falls back to "uncategorized" when categorie_id is missing', () => {
    const item = menuItemFromRow({
      id: 'item-5',
      name: 'Item',
      description: null,
      price: 100,
      image_url: null,
      categorie_id: null,
      item_categories: null,
    });

    expect(item.categoryId).toBe('uncategorized');
  });
});

describe('fetchMenu', () => {
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

  it('loads the restaurant and groups its items by category', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(restaurantRow));
    client.queueTableResponse(
      'menu_items',
      fakeSupabaseOk([
        {
          id: 'burger-1',
          name: 'Classic Burger',
          description: 'Beef, cheese, and house sauce',
          price: 550,
          image_url: '',
          categorie_id: 'burgers',
          item_categories: { id: 'burgers', name: 'Burgers' },
        },
        {
          id: 'drink-1',
          name: 'Fresh Lemonade',
          description: 'Lemon and mint',
          price: 100,
          image_url: '',
          categorie_id: 'drinks',
          item_categories: { id: 'drinks', name: 'Drinks' },
        },
      ]),
    );

    const menu = await fetchMenu('restaurant-1', client);

    expect(menu.restaurant).toEqual({ id: 'restaurant-1', name: 'Test Kitchen', description: 'Fresh food made daily', logoUrl: '' });
    expect(menu.categories).toEqual([
      { id: 'burgers', name: 'Burgers', items: [expect.objectContaining({ id: 'burger-1', price: 550 })] },
      { id: 'drinks', name: 'Drinks', items: [expect.objectContaining({ id: 'drink-1', price: 100 })] },
    ]);
  });

  it('sorts categories alphabetically (case-insensitively), with "Other" always last', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(restaurantRow));
    client.queueTableResponse(
      'menu_items',
      fakeSupabaseOk([
        { id: 'item-uncat', name: 'Mystery Side', description: '', price: 100, image_url: '', categorie_id: 'misc', item_categories: null },
        { id: 'item-zebras', name: 'Z', description: '', price: 100, image_url: '', categorie_id: 'zebras', item_categories: { id: 'zebras', name: 'zebras' } },
        { id: 'item-apples', name: 'Apple', description: '', price: 100, image_url: '', categorie_id: 'apples', item_categories: { id: 'apples', name: 'Apples' } },
      ]),
    );

    const menu = await fetchMenu('restaurant-1', client);

    expect(menu.categories.map((category) => category.name)).toEqual(['Apples', 'zebras', 'Other']);
  });

  it('excludes just the item with an invalid price, keeps the rest, and reports the failure', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(restaurantRow));
    client.queueTableResponse(
      'menu_items',
      fakeSupabaseOk([
        {
          id: 'burger-1',
          name: 'Classic Burger',
          description: '',
          price: 550,
          image_url: '',
          categorie_id: 'burgers',
          item_categories: { id: 'burgers', name: 'Burgers' },
        },
        {
          id: 'bad-item',
          name: 'Mystery Item',
          description: '',
          price: 'not-a-number',
          image_url: '',
          categorie_id: 'burgers',
          item_categories: { id: 'burgers', name: 'Burgers' },
        },
      ]),
    );

    const menu = await fetchMenu('restaurant-1', client);

    expect(menu.categories).toHaveLength(1);
    expect(menu.categories[0].items.map((item) => item.id)).toEqual(['burger-1']);
    expect(fakeReporter.reported).toHaveLength(1);
    expect(fakeReporter.reported[0].error).toBeInstanceOf(InvalidMenuItemPriceError);
    expect(fakeReporter.reported[0].context).toBe('fetchMenu.groupItemsByCategory');
  });

  it('uses "Other" for an item with no item_categories relation', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(restaurantRow));
    client.queueTableResponse(
      'menu_items',
      fakeSupabaseOk([{ id: 'item-1', name: 'Mystery Side', description: '', price: 100, image_url: '', categorie_id: 'misc', item_categories: null }]),
    );

    const menu = await fetchMenu('restaurant-1', client);

    expect(menu.categories).toEqual([{ id: 'misc', name: 'Other', items: [expect.objectContaining({ id: 'item-1' })] }]);
  });

  it('accepts item_categories returned as a one-element array', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(restaurantRow));
    client.queueTableResponse(
      'menu_items',
      fakeSupabaseOk([{ id: 'item-1', name: 'Side', description: '', price: 100, image_url: '', categorie_id: 'sides', item_categories: [{ id: 'sides', name: 'Sides' }] }]),
    );

    const menu = await fetchMenu('restaurant-1', client);

    expect(menu.categories).toEqual([{ id: 'sides', name: 'Sides', items: [expect.objectContaining({ id: 'item-1' })] }]);
  });

  it('returns an empty category list when there are no menu items', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(restaurantRow));
    client.queueTableResponse('menu_items', fakeSupabaseOk([]));

    const menu = await fetchMenu('restaurant-1', client);

    expect(menu.categories).toEqual([]);
  });

  it('propagates a restaurant query error', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseError('offline'));
    client.queueTableResponse('menu_items', fakeSupabaseOk([]));

    await expect(fetchMenu('restaurant-1', client)).rejects.toMatchObject({ message: 'offline' });
  });

  it('throws when the restaurant is not found', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(null));
    client.queueTableResponse('menu_items', fakeSupabaseOk([]));

    await expect(fetchMenu('missing-id', client)).rejects.toThrow('Restaurant not found: missing-id');
  });

  it('propagates a menu items query error', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(restaurantRow));
    client.queueTableResponse('menu_items', fakeSupabaseError('offline'));

    await expect(fetchMenu('restaurant-1', client)).rejects.toMatchObject({ message: 'offline' });
  });
});
