/**
 * Covers `GroceryProductCard` (issue #390 / P7-02), ported from
 * flutter_app/lib/services/grocery/presentation/widgets/grocery_product_card.dart.
 */
import { fireEvent, render } from '@testing-library/react-native';

import type { GroceryProduct } from '@/stores/grocery-cart-store';

import { GroceryProductCard, groceryStockLabel, groceryUnitLabel } from './grocery-product-card';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const bananas: GroceryProduct = {
  id: 'bananas',
  storeId: 's1',
  name: 'Bananas',
  description: 'Fresh bananas, sold by weight',
  unitPrice: 180,
  pricingUnit: 'kilogram',
  stockState: 'lowStock',
  availableQuantity: 2,
  icon: '🍌',
  imageUrl: null,
};

describe('GroceryProductCard', () => {
  it('renders name, description, price per unit, stock pill and the emoji fallback', async () => {
    const onAdd = jest.fn();
    const onPress = jest.fn();
    const { getByText, getByLabelText } = await render(<GroceryProductCard product={bananas} onAdd={onAdd} onPress={onPress} />);

    expect(getByText('Bananas')).toBeOnTheScreen();
    expect(getByText('Fresh bananas, sold by weight')).toBeOnTheScreen();
    expect(getByText('$1.80 per kg')).toBeOnTheScreen();
    expect(getByText('Low stock')).toBeOnTheScreen();
    expect(getByText('🍌')).toBeOnTheScreen();

    await fireEvent.press(getByLabelText('Add Bananas'));
    expect(onAdd).toHaveBeenCalledTimes(1);
    await fireEvent.press(getByText('Bananas'));
    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it('disables the add button with the stock label as its tooltip when out of stock', async () => {
    const onAdd = jest.fn();
    const { getByLabelText, getAllByText } = await render(
      <GroceryProductCard product={{ ...bananas, stockState: 'outOfStock', availableQuantity: 0 }} onAdd={onAdd} />,
    );

    const button = getByLabelText('Out of stock');
    expect(button.props.accessibilityState).toEqual({ disabled: true });
    await fireEvent.press(button);
    expect(onAdd).not.toHaveBeenCalled();
    expect(getAllByText('Out of stock')).toHaveLength(1);
  });

  it('maps stock states and pricing units to their labels', () => {
    expect(groceryStockLabel('inStock')).toBe('In stock');
    expect(groceryStockLabel('lowStock')).toBe('Low stock');
    expect(groceryStockLabel('outOfStock')).toBe('Out of stock');
    expect(groceryUnitLabel(bananas)).toBe('per kg');
    expect(groceryUnitLabel({ ...bananas, pricingUnit: 'each' })).toBe('each');
  });
});
