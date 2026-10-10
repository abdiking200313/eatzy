/**
 * `RestaurantMenuRepository` has no dedicated Flutter test file (checked
 * `flutter_app/test/` directly) -- a focused test for this port's query
 * shape and its `_groupItemsByCategory` grouping/sorting/bad-price rules,
 * against `src/test-utils/fake-supabase-client.ts`.
 */
import type { ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { fetchRestaurantMenu, groupMenuItemsByCategory, type RestaurantMenuSource } from './restaurant-menu-repository';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function fakeClient() {
  return createFakeSupabaseClient() as unknown as RestaurantMenuSource & ReturnType<typeof createFakeSupabaseClient>;
}

function fakeReporter(): ErrorReporter & { reportError: jest.Mock } {
  return { reportError: jest.fn() };
}

const restaurantRow = { id: 'restaurant-1', name: 'Test Kitchen', description: 'Fresh food', logo_url: null };

describe('fetchRestaurantMenu', () => {
  it('selects the restaurant and its menu items with the Dart query shapes', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(restaurantRow));
    client.queueTableResponse('menu_items', fakeSupabaseOk([]));

    const menu = await fetchRestaurantMenu('restaurant-1', client, fakeReporter());

    expect(client.calls).toEqual([
      {
        kind: 'table',
        name: 'restaurants',
        steps: [
          { method: 'select', args: ['id, name, description, logo_url'] },
          { method: 'eq', args: ['id', 'restaurant-1'] },
          { method: 'single', args: [] },
        ],
      },
      {
        kind: 'table',
        name: 'menu_items',
        steps: [
          { method: 'select', args: ['id, name, description, price, image_url, categorie_id, item_categories(id, name)'] },
          { method: 'eq', args: ['restaurant_id', 'restaurant-1'] },
          { method: 'order', args: ['name'] },
        ],
      },
    ]);
    expect(menu).toEqual({
      restaurant: { id: 'restaurant-1', name: 'Test Kitchen', description: 'Fresh food', logoUrl: '' },
      categories: [],
    });
  });

  it('throws when either query fails', async () => {
    const client = fakeClient();
    client.queueTableResponse('restaurants', fakeSupabaseOk(restaurantRow));
    client.queueTableResponse('menu_items', fakeSupabaseError('boom'));

    await expect(fetchRestaurantMenu('restaurant-1', client, fakeReporter())).rejects.toEqual({ message: 'boom' });
  });
});

describe('groupMenuItemsByCategory', () => {
  it('groups by category, names from item_categories, sorts by name, and puts Other last', () => {
    const categories = groupMenuItemsByCategory(
      [
        { id: '1', name: 'Water', price: 100, categorie_id: 'drinks', item_categories: { id: 'drinks', name: 'drinks' } },
        { id: '2', name: 'Mystery', price: 200, categorie_id: null, item_categories: null },
        { id: '3', name: 'Burger', price: 550, categorie_id: 'burgers', item_categories: { id: 'burgers', name: ' Burgers ' } },
        { id: '4', name: 'Cola', price: 150, categorie_id: 'drinks', item_categories: { id: 'drinks', name: 'drinks' } },
        { id: '5', name: 'Blank', price: 150, categorie_id: 'blank', item_categories: { id: 'blank', name: '   ' } },
      ],
      fakeReporter(),
    );

    expect(categories.map((category) => [category.id, category.name, category.items.map((item) => item.id)])).toEqual([
      ['burgers', 'Burgers', ['3']],
      ['drinks', 'drinks', ['1', '4']],
      ['uncategorized', 'Other', ['2']],
      ['blank', 'Other', ['5']],
    ]);
  });

  it('reports and skips an item with an invalid price instead of failing the whole menu', () => {
    const reporter = fakeReporter();

    const categories = groupMenuItemsByCategory(
      [
        { id: 'bad', name: 'Bad', price: 'oops', categorie_id: 'mains', item_categories: { name: 'Mains' } },
        { id: 'good', name: 'Good', price: 300, categorie_id: 'mains', item_categories: { name: 'Mains' } },
      ],
      reporter,
    );

    expect(categories).toHaveLength(1);
    expect(categories[0].items.map((item) => item.id)).toEqual(['good']);
    expect(reporter.reportError).toHaveBeenCalledTimes(1);
  });
});
