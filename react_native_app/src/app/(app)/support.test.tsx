/**
 * Issue #403 / P8-07. Flutter has no dedicated support test; its only
 * coverage is the `Support` row in flutter_app/test/layout_test.dart
 * (renders, shows the 'Help & Support' title). That narrow-screen
 * overflow assertion has no React Native equivalent, so this checks the
 * rendered content against the Flutter screen's static lists instead.
 */
import { fireEvent } from '@testing-library/react-native';
import { router } from 'expo-router';

import { CONTACT_OPTIONS, FAQ_ITEMS, HELP_TOPICS } from '@/features/support/support-content';
import { renderWithProviders } from '@/test-utils';
import { ServiceThemes } from '@/theme/service-theme';

import SupportScreen from './support';

describe('SupportScreen', () => {
  it('renders the Help & Support title, a back button, and all three section headings', async () => {
    const { getByText, getByLabelText } = await renderWithProviders(<SupportScreen />);

    expect(getByText('Help & Support')).toBeOnTheScreen();
    expect(getByLabelText('Back')).toBeOnTheScreen();
    expect(getByText('How can we help?')).toBeOnTheScreen();
    expect(getByText('Need more help?')).toBeOnTheScreen();
    expect(getByText('Frequently Asked Questions')).toBeOnTheScreen();
  });

  it('renders every help topic, contact option, and FAQ entry with Flutter copy', async () => {
    const { getByText } = await renderWithProviders(<SupportScreen />);

    for (const topic of [...HELP_TOPICS, ...CONTACT_OPTIONS]) {
      expect(getByText(topic.title)).toBeOnTheScreen();
      expect(getByText(topic.subtitle)).toBeOnTheScreen();
    }
    for (const item of FAQ_ITEMS) {
      expect(getByText(item.question)).toBeOnTheScreen();
      expect(getByText(item.answer)).toBeOnTheScreen();
    }
  });

  it('matches the Flutter contact details exactly', () => {
    expect(CONTACT_OPTIONS.map(({ title, subtitle }) => [title, subtitle])).toEqual([
      ['Email Us', 'support@zivo.com'],
      ['Call Us', '+234 XXX XXXX XXXX'],
      ['Live Chat', 'Chat with our team 9AM - 9PM'],
    ]);
    expect(HELP_TOPICS.map((t) => t.title)).toEqual([
      'Orders & Delivery',
      'Payment',
      'Restaurants & Food',
      'Account',
    ]);
  });

  it('groups each list in one card with a divider between rows but not after the last', async () => {
    const { getByTestId, queryAllByTestId } = await renderWithProviders(<SupportScreen />);

    expect(getByTestId('support-help-topics')).toBeOnTheScreen();
    expect(queryAllByTestId('support-help-topics-divider')).toHaveLength(HELP_TOPICS.length - 1);
    expect(queryAllByTestId('support-contact-options-divider')).toHaveLength(CONTACT_OPTIONS.length - 1);
    expect(queryAllByTestId('support-faq-divider')).toHaveLength(FAQ_ITEMS.length - 1);
  });

  it('renders rows as display-only (no tappable buttons besides Back), like Flutter', async () => {
    const { queryAllByRole } = await renderWithProviders(<SupportScreen />);

    expect(queryAllByRole('button')).toHaveLength(1);
  });

  it('tints the row icon chips with the neutral platform palette', async () => {
    const { getByTestId } = await renderWithProviders(<SupportScreen />);
    const card = getByTestId('support-help-topics');
    const chips = card.queryAll(
      (node) =>
        typeof node.type === 'string' &&
        JSON.stringify(node.props.style ?? '').includes(ServiceThemes.platform.soft),
    );

    expect(chips.length).toBeGreaterThanOrEqual(HELP_TOPICS.length);
  });

  it('goes back when Back is pressed', async () => {
    const canGoBack = jest.spyOn(router, 'canGoBack').mockReturnValue(true);
    const back = jest.spyOn(router, 'back').mockImplementation(() => {});
    const { getByLabelText } = await renderWithProviders(<SupportScreen />);

    fireEvent.press(getByLabelText('Back'));

    expect(back).toHaveBeenCalled();
    canGoBack.mockRestore();
    back.mockRestore();
  });
});
