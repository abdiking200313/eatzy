/**
 * Ports the `CategoriesSection` case from
 * `flutter_app/test/categories_screen_test.dart` (issue #544): the food
 * home category rail shows an empty state when there are no categories.
 */
import { renderWithProviders } from '@/test-utils';

import { CategoriesSection } from './categories-section';

describe('CategoriesSection', () => {
  it('shows an empty state when there are no categories', async () => {
    const { getByText } = await renderWithProviders(
      <CategoriesSection categories={[]} selectedCategoryId={null} onCategorySelected={() => {}} />,
    );

    expect(getByText('No categories found')).toBeOnTheScreen();
  });
});
