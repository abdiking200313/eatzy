/**
 * Ports `flutter_app/test/super_app_home_test.dart` (issue #373 / P4-02).
 * The Dart test injects `storeListingLoader`/`activityController`
 * constructor params; this screen takes the analogous
 * `storeListingLoader`/`fetchActivityPreview` props (see `app.tsx`'s top
 * comment for why there's no ported `ActivityController`).
 *
 * `expo-router`'s imperative `router` is mocked the same way
 * `login.test.tsx` mocks it -- this screen only ever calls
 * `router.replace`/`router.push`, never `useRouter()`/`<Link>`, so no real
 * route tree is needed. `@/platform/supabase/client` is stubbed because
 * importing `store-listing-repository.ts`/`activity-repository.ts`
 * (for their default-parameter fallbacks, never actually called here since
 * every test injects its own loader) pulls in that module, which reads
 * env vars at import time.
 */
import { fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import type { TestInstance } from 'test-renderer';

import { renderWithProviders } from '@/test-utils';
import type { ActivityItem } from '@/platform/activity/api/activity-item';
import type { StoreListing } from '@/platform/discovery/store-listing';

import SuperAppHomeScreen from './app';

jest.mock('expo-router', () => ({
  router: {
    replace: jest.fn(),
    push: jest.fn(),
  },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function findImage(instance: TestInstance) {
  return instance.queryAll((node) => node.type === 'ViewManagerAdapter_ExpoImage')[0];
}

async function noStores(): Promise<StoreListing[]> {
  return [];
}

async function noActivity(): Promise<ActivityItem[]> {
  return [];
}

const groceryListing: StoreListing = {
  id: 'store-1',
  serviceId: 'grocery',
  name: 'Bakaara Mart',
  subtitle: 'Bakaara',
  imageUrl: 'https://example.com/store.jpg',
  route: '/grocery/stores/store-1',
};

beforeEach(() => {
  (router.replace as jest.Mock).mockClear();
  (router.push as jest.Mock).mockClear();
});

describe('SuperAppHomeScreen', () => {
  it('renders every service tile and switches shell branches when one is tapped', async () => {
    const { getByText, getByTestId } = await renderWithProviders(
      <SuperAppHomeScreen storeListingLoader={noStores} fetchActivityPreview={noActivity} />,
    );

    for (const label of ['Food', 'Grocery', 'Pharmacy']) {
      expect(getByText(label)).toBeOnTheScreen();
    }
    // The tile is a full-bleed photo, never tinted with the per-service color.
    expect(findImage(getByTestId('service-grocery'))).toBeOnTheScreen();

    await fireEvent.press(getByTestId('service-grocery'));

    expect(router.replace).toHaveBeenCalledWith('/grocery');
  });

  it('includes Fresh Meat, Electronics, and More, with no coming-soon placeholders', async () => {
    const { getByText, queryByText } = await renderWithProviders(
      <SuperAppHomeScreen storeListingLoader={noStores} fetchActivityPreview={noActivity} />,
    );

    for (const label of ['Fresh Meat', 'Electronics', 'More']) {
      expect(getByText(label)).toBeOnTheScreen();
    }
    // Coming-soon categories live only on the full Services list (#374).
    for (const label of ['Delivery', 'Deals', 'Soon']) {
      expect(queryByText(label)).toBeNull();
    }
  });

  it('"More" opens the full Services list', async () => {
    const { getByTestId } = await renderWithProviders(
      <SuperAppHomeScreen storeListingLoader={noStores} fetchActivityPreview={noActivity} />,
    );

    await fireEvent.press(getByTestId('service-more'));

    expect(router.push).toHaveBeenCalledWith('/services');
  });

  it('previews recent cross-service activity', async () => {
    const item: ActivityItem = {
      id: 'grocery-preview',
      serviceId: 'grocery',
      title: 'Bakaara groceries',
      status: 'Confirmed',
      occurredAt: new Date('2026-07-27T00:00:00.000Z'),
      amount: 2400,
      detailsRoute: '/grocery',
    };

    const { getByText } = await renderWithProviders(
      <SuperAppHomeScreen storeListingLoader={noStores} fetchActivityPreview={async () => [item]} />,
    );

    expect(await getByText('Recent Activity')).toBeOnTheScreen();
    expect(await getByText('Bakaara groceries')).toBeOnTheScreen();
    expect(await getByText('$24.00')).toBeOnTheScreen();
    expect(await getByText('Confirmed')).toBeOnTheScreen();
  });

  it('shows the Popular Stores error state with a working retry, instead of silently disappearing (issue #286)', async () => {
    let attempts = 0;
    const loader = async (): Promise<StoreListing[]> => {
      attempts += 1;
      if (attempts === 1) {
        throw new Error('offline');
      }
      return [];
    };

    const { getByText, queryByText } = await renderWithProviders(
      <SuperAppHomeScreen storeListingLoader={loader} fetchActivityPreview={noActivity} />,
    );

    await waitFor(() => expect(getByText('Popular stores could not be loaded.')).toBeOnTheScreen());
    expect(getByText('Try again')).toBeOnTheScreen();
    // No raw error text leaks into the UI.
    expect(queryByText(/offline/)).toBeNull();

    await fireEvent.press(getByText('Try again'));

    await waitFor(() => expect(attempts).toBe(2));
    await waitFor(() => expect(queryByText('Popular stores could not be loaded.')).toBeNull());
  });

  it('shows the real photo for a popular store with an imageUrl, and opens it on tap', async () => {
    const { getByText, getByTestId } = await renderWithProviders(
      <SuperAppHomeScreen storeListingLoader={async () => [groceryListing]} fetchActivityPreview={noActivity} />,
    );

    await waitFor(() => expect(getByText('Bakaara Mart')).toBeOnTheScreen());
    expect(findImage(getByTestId('popular-store-store-1'))).toBeOnTheScreen();

    await fireEvent.press(getByTestId('popular-store-store-1'));

    expect(router.push).toHaveBeenCalledWith('/grocery/stores/store-1');
  });
});
