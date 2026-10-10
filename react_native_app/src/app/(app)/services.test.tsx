/**
 * Ports the `CategoriesScreen`-specific cases from
 * `flutter_app/test/categories_screen_test.dart` (issue #374 / P4-03).
 *
 * Not ported: the file's `CategoriesSection`/`SectionHeader` cases (food
 * home-screen widgets unrelated to this screen) and the narrow/large-text
 * overflow case (a Flutter `RenderFlex` overflow assertion with no React
 * Native equivalent -- RN's flexbox layout doesn't fail the same way).
 */
import { fireEvent } from '@testing-library/react-native';
import type { TestInstance } from 'test-renderer';

import { renderWithProviders } from '@/test-utils';

import ServicesScreen from './services';

// See store-list-card.test.tsx's comment on this helper.
function findImage(instance: TestInstance) {
  return instance.queryAll((node) => node.type === 'ViewManagerAdapter_ExpoImage')[0];
}

// Each card renders one `RNSVGRect` for its bottom gradient scrim; a card
// with no photo renders a second one for its drawn gradient-placeholder
// background (see `PhotoPlaceholder` in `./services.tsx`).
function gradientRectCount(instance: TestInstance) {
  return instance.queryAll((node) => node.type === 'RNSVGRect').length;
}

describe('ServicesScreen', () => {
  it('renders a real photo for modules with a photoUrl, and a drawn icon-watermark placeholder for a coming-soon category with none, without crashing', async () => {
    const { getByTestId } = await renderWithProviders(<ServicesScreen showBackButton={false} />);

    // Food and Grocery both have a real photoUrl (see ServiceRegistry.modules)
    // -- just the bottom scrim's gradient, no placeholder gradient.
    for (const slug of ['food', 'grocery']) {
      const card = getByTestId(`services-${slug}`);
      expect(findImage(card)).toBeOnTheScreen();
      expect(gradientRectCount(card)).toBe(1);
    }

    // "Delivery" has no photoUrl -- falls back to the drawn placeholder
    // (its own gradient, plus the scrim's), not a photo.
    const deliveryCard = getByTestId('services-coming-soon-delivery');
    expect(findImage(deliveryCard)).toBeUndefined();
    expect(gradientRectCount(deliveryCard)).toBe(2);
  });

  it('renders the Services title, no back button, and every module title, from one screen', async () => {
    const { getByText, queryByLabelText } = await renderWithProviders(<ServicesScreen showBackButton={false} />);

    expect(getByText('Services')).toBeOnTheScreen();
    expect(queryByLabelText('Back')).toBeNull();

    for (const title of ['Food', 'Pharmacy', 'Grocery']) {
      expect(getByText(title)).toBeOnTheScreen();
    }
  });

  it('includes the coming-soon categories, and tapping one shows a "coming soon" message', async () => {
    const { getByText, getByTestId } = await renderWithProviders(<ServicesScreen showBackButton={false} />);

    // Electronics and Fresh Meat are real (grocery-engine) services now.
    expect(getByText('Electronics')).toBeOnTheScreen();

    await fireEvent.press(getByTestId('services-coming-soon-deals'));

    expect(getByText('Deals is coming soon')).toBeOnTheScreen();
  });

  it('shows a back control when pushed as a standalone screen', async () => {
    const { getByLabelText } = await renderWithProviders(<ServicesScreen />);

    expect(getByLabelText('Back')).toBeOnTheScreen();
  });
});
