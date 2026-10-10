/**
 * Ports `flutter_app/test/explore_screen_test.dart` (issue #375 / P4-04).
 *
 * Not ported: the narrow/large-text overflow case (a Flutter `RenderFlex`
 * overflow assertion with no React Native equivalent -- RN's flexbox
 * layout doesn't fail the same way), same precedent as `../services.test.tsx`.
 *
 * `expo-router`'s imperative `router` and `@/platform/supabase/client` are
 * mocked the same way `app.test.tsx` mocks them -- this screen only ever
 * calls `router.push`, never `useRouter()`/`<Link>`, and importing
 * `store-listing-repository.ts` (for the default-parameter loader's
 * fallback, never actually called here since every test injects its own
 * loader) pulls in the Supabase client module, which reads env vars at
 * import time.
 */
import { fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';

import { renderWithProviders } from '@/test-utils';
import type { StoreListing } from '@/platform/discovery/store-listing';
import type { ServiceId } from '@/theme/service-theme';

import ExploreScreen from './explore';

jest.mock('expo-router', () => ({
  router: {
    push: jest.fn(),
  },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const sampleStores: StoreListing[] = [
  {
    id: 'restaurant-1',
    serviceId: 'food',
    name: 'Mogadishu Kitchen',
    subtitle: 'Somali favourites',
    imageUrl: null,
    route: '/food/restaurants/restaurant-1',
  },
  {
    id: 'grocery-1',
    serviceId: 'grocery',
    name: 'Bakaara Mart',
    subtitle: 'Bakaara',
    imageUrl: null,
    route: '/grocery/stores/grocery-1',
  },
  {
    id: 'pharmacy-1',
    serviceId: 'pharmacy',
    name: 'Hodan Pharmacy',
    subtitle: 'Hodan',
    imageUrl: null,
    route: '/pharmacy/stores/pharmacy-1',
  },
];

/** Mirrors `StoreListingRepository.fetchStores`'s filter contract closely enough for these tests: `null` returns everything, otherwise only that vertical's stores. */
async function loadStores(filter: ServiceId | null): Promise<StoreListing[]> {
  if (!filter) {
    return sampleStores;
  }
  return sampleStores.filter((store) => store.serviceId === filter);
}

beforeEach(() => {
  (router.push as jest.Mock).mockClear();
});

describe('ExploreScreen', () => {
  it('lists stores from every vertical', async () => {
    const { getByText } = await renderWithProviders(<ExploreScreen storeListingLoader={loadStores} />);

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());

    expect(getByText('Explore')).toBeOnTheScreen();
    for (const label of ['All', 'Food', 'Grocery', 'Pharmacy']) {
      expect(getByText(label)).toBeOnTheScreen();
    }
    for (const store of sampleStores) {
      expect(getByText(store.name)).toBeOnTheScreen();
    }
  });

  it('selecting a service filter chip narrows the store feed', async () => {
    const { getByText, queryByText } = await renderWithProviders(<ExploreScreen storeListingLoader={loadStores} />);

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());
    expect(getByText('Bakaara Mart')).toBeOnTheScreen();
    expect(getByText('Hodan Pharmacy')).toBeOnTheScreen();

    await fireEvent.press(getByText('Food'));

    await waitFor(() => expect(queryByText('Bakaara Mart')).toBeNull());
    expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen();
    expect(queryByText('Hodan Pharmacy')).toBeNull();

    await fireEvent.press(getByText('All'));

    await waitFor(() => expect(getByText('Bakaara Mart')).toBeOnTheScreen());
    expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen();
    expect(getByText('Hodan Pharmacy')).toBeOnTheScreen();
  });

  it('shows an error message, with no retry, when the store feed fails to load', async () => {
    const { getByText, queryByText } = await renderWithProviders(
      <ExploreScreen storeListingLoader={async () => Promise.reject(new Error('offline'))} />,
    );

    await waitFor(() => expect(getByText('Stores could not be loaded.')).toBeOnTheScreen());
    // No raw error text leaks into the UI, and (matching the Dart source)
    // this message has no retry action.
    expect(queryByText(/offline/)).toBeNull();
    expect(queryByText('Try again')).toBeNull();
  });

  it('filtering by search narrows the feed to matching store names', async () => {
    const { getByText, queryByText, getByPlaceholderText } = await renderWithProviders(
      <ExploreScreen storeListingLoader={loadStores} />,
    );

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());

    await fireEvent.changeText(getByPlaceholderText('Search restaurants, stores...'), 'bakaara');

    await waitFor(() => expect(queryByText('Mogadishu Kitchen')).toBeNull());
    expect(getByText('Bakaara Mart')).toBeOnTheScreen();
    expect(queryByText('Hodan Pharmacy')).toBeNull();
  });

  it('opens a store route when tapped', async () => {
    const { getByText } = await renderWithProviders(<ExploreScreen storeListingLoader={loadStores} />);

    await waitFor(() => expect(getByText('Mogadishu Kitchen')).toBeOnTheScreen());

    await fireEvent.press(getByText('Mogadishu Kitchen'));

    expect(router.push).toHaveBeenCalledWith('/food/restaurants/restaurant-1');
  });
});
