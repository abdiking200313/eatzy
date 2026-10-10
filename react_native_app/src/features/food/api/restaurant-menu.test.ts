/**
 * Ports the model cases of `flutter_app/test/restaurant_screen_test.dart`
 * (issue #383): `MenuItem.fromMap`'s numeric-string parsing and its refusal
 * to price an item at $0.00 for a missing/unparseable price.
 */
import { MenuItemFormatError, menuItemFromRow, restaurantMenuItemCount, type RestaurantMenu } from './restaurant-menu';

describe('menuItemFromRow', () => {
  it('parses numeric strings from Supabase', () => {
    const item = menuItemFromRow({
      id: 'item-1',
      name: 'Chicken Wrap',
      description: null,
      price: '450',
      image_url: null,
      categorie_id: 'wraps',
    });

    expect(item.price).toBe(450);
    expect(item.description).toBe('');
    expect(item.categoryId).toBe('wraps');
  });

  it('rounds a numeric price and falls back for missing optional fields', () => {
    const item = menuItemFromRow({ id: 7, price: 449.6 });

    expect(item).toEqual({
      id: '7',
      name: 'Unnamed item',
      description: '',
      price: 450,
      imageUrl: '',
      categoryId: 'uncategorized',
    });
  });

  it('throws instead of silently pricing at $0.00 for an unparseable price (#62)', () => {
    expect(() =>
      menuItemFromRow({
        id: 'item-2',
        name: 'Mystery Item',
        description: null,
        price: 'not-a-number',
        image_url: null,
        categorie_id: 'mains',
      }),
    ).toThrow(MenuItemFormatError);
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
      }),
    ).toThrow(MenuItemFormatError);
  });

  it('throws for a negative price', () => {
    expect(() => menuItemFromRow({ id: 'item-4', price: -1 })).toThrow(MenuItemFormatError);
  });
});

describe('restaurantMenuItemCount', () => {
  it('sums items across categories', () => {
    const item = { id: 'a', name: 'A', description: '', price: 100, imageUrl: '', categoryId: 'x' };
    const menu: RestaurantMenu = {
      restaurant: { id: 'r', name: 'R', description: '', logoUrl: '' },
      categories: [
        { id: 'x', name: 'X', items: [item, { ...item, id: 'b' }] },
        { id: 'y', name: 'Y', items: [{ ...item, id: 'c' }] },
      ],
    };

    expect(restaurantMenuItemCount(menu)).toBe(3);
  });
});
