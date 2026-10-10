/**
 * Ports `flutter_app/test/grocery_screens_test.dart`'s
 * "groupByCategory orders sections by sort order, \"Other\" last" case
 * (issue #390 / P7-02), plus `_visibleProducts`' search filter.
 */
import type { GroceryProduct } from '@/stores/grocery-cart-store';

import { filterProductsByName, groupByCategory } from './grocery-catalog';

function product(name: string, category: string | null, sortOrder: number): GroceryProduct {
  return {
    id: name,
    storeId: 's1',
    name,
    description: '',
    unitPrice: 100,
    pricingUnit: 'each',
    stockState: 'inStock',
    availableQuantity: 10,
    icon: '🛒',
    categoryName: category,
    categorySortOrder: sortOrder,
  };
}

describe('groupByCategory', () => {
  it('orders sections by sort order, "Other" last', () => {
    const sections = groupByCategory([
      product('Bread', 'Bread & bakery', 5),
      product('Mystery box', null, 0),
      product('Apples', 'Fruits & vegetables', 1),
      product('Baguette', 'Bread & bakery', 5),
    ]);

    expect(sections.map((s) => s.name)).toEqual(['Fruits & vegetables', 'Bread & bakery', 'Other']);
    expect(sections[1].products.map((p) => p.name)).toEqual(['Bread', 'Baguette']);
  });

  it('breaks a sort-order tie by category name, and returns no sections for no products', () => {
    const sections = groupByCategory([product('Milk', 'Dairy', 2), product('Rice', 'Bakery', 2)]);
    expect(sections.map((s) => s.name)).toEqual(['Bakery', 'Dairy']);
    expect(groupByCategory([])).toEqual([]);
  });
});

describe('filterProductsByName', () => {
  const products = [product('Bananas', null, 0), product('Basmati rice', null, 0)];

  it('matches a case-insensitive, trimmed substring of the product name', () => {
    expect(filterProductsByName(products, '  RICE ').map((p) => p.name)).toEqual(['Basmati rice']);
  });

  it('returns every product for a blank query', () => {
    expect(filterProductsByName(products, '   ')).toBe(products);
  });
});
