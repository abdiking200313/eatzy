import { fireEvent } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Text } from 'react-native';

import { renderWithProviders } from '@/test-utils';

import { AppScaffold } from './app-scaffold';

jest.mock('expo-router', () => ({
  router: {
    canGoBack: jest.fn(() => false),
    back: jest.fn(),
    replace: jest.fn(),
  },
}));

describe('AppScaffold', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it('renders the title and children', async () => {
    const { getByText } = await renderWithProviders(
      <AppScaffold title="Profile">
        <Text>Body content</Text>
      </AppScaffold>,
    );

    expect(getByText('Profile')).toBeOnTheScreen();
    expect(getByText('Body content')).toBeOnTheScreen();
  });

  it('shows no back button by default', async () => {
    const { queryByLabelText } = await renderWithProviders(
      <AppScaffold title="Home">
        <Text>Body</Text>
      </AppScaffold>,
    );

    expect(queryByLabelText('Back')).toBeNull();
  });

  it('shows a back button when showBackButton is set', async () => {
    const { getByLabelText } = await renderWithProviders(
      <AppScaffold title="Order details" showBackButton>
        <Text>Body</Text>
      </AppScaffold>,
    );

    expect(getByLabelText('Back')).toBeOnTheScreen();
  });

  it('calls router.back() when it can go back', async () => {
    (router.canGoBack as jest.Mock).mockReturnValue(true);

    const { getByLabelText } = await renderWithProviders(
      <AppScaffold title="Order details" showBackButton>
        <Text>Body</Text>
      </AppScaffold>,
    );

    await fireEvent.press(getByLabelText('Back'));

    expect(router.back).toHaveBeenCalledTimes(1);
    expect(router.replace).not.toHaveBeenCalled();
  });

  it("falls back to router.replace('/') when it cannot go back", async () => {
    (router.canGoBack as jest.Mock).mockReturnValue(false);

    const { getByLabelText } = await renderWithProviders(
      <AppScaffold title="Order details" showBackButton>
        <Text>Body</Text>
      </AppScaffold>,
    );

    await fireEvent.press(getByLabelText('Back'));

    expect(router.replace).toHaveBeenCalledWith('/');
    expect(router.back).not.toHaveBeenCalled();
  });

  it('renders actions and a floating action button when given', async () => {
    const { getByText } = await renderWithProviders(
      <AppScaffold
        title="Home"
        actions={<Text>action-slot</Text>}
        floatingActionButton={<Text>fab-slot</Text>}>
        <Text>Body</Text>
      </AppScaffold>,
    );

    expect(getByText('action-slot')).toBeOnTheScreen();
    expect(getByText('fab-slot')).toBeOnTheScreen();
  });

  it('renders a bottomBar when given one', async () => {
    const { getByText } = await renderWithProviders(
      <AppScaffold title="Home" bottomBar={<Text>bottom-bar-slot</Text>}>
        <Text>Body</Text>
      </AppScaffold>,
    );

    expect(getByText('bottom-bar-slot')).toBeOnTheScreen();
  });
});
