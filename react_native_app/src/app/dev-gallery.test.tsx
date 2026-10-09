import { renderWithProviders } from '@/test-utils';

import DevGalleryScreen from './dev-gallery';

// Mirrors app-scaffold.test.tsx's approach: stub the one `expo-router` export
// this screen touches (`Redirect`) rather than standing up a full route tree
// (`expo-router/testing-library`'s `renderRouter`) for a screen that itself
// renders no navigation. Only exercised by the `__DEV__ === false` case below
// — the `__DEV__ === true` branch never renders `Redirect` at all.
jest.mock('expo-router', () => {
  // Jest's mock-factory hoisting forbids referencing an out-of-scope
  // `import`, so this has to require() lazily inside the factory instead.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { Text } = require('react-native');
  return {
    Redirect: ({ href }: { href: string }) => <Text testID="redirect-stub">{href}</Text>,
  };
});

// `__DEV__` is typed as a `const` global (it never legitimately changes
// within a real running bundle), so flipping it here to exercise both
// branches needs a cast rather than a direct assignment.
const devFlag = globalThis as unknown as { __DEV__: boolean };

describe('DevGalleryScreen', () => {
  const originalDev = devFlag.__DEV__;

  afterEach(() => {
    devFlag.__DEV__ = originalDev;
  });

  it('renders the shared components when __DEV__ is true', async () => {
    devFlag.__DEV__ = true;

    const { getByText } = await renderWithProviders(<DevGalleryScreen />);

    expect(getByText('Component gallery')).toBeOnTheScreen();
    expect(getByText('LoadingState (no caption)')).toBeOnTheScreen();
    expect(getByText('EmptyState')).toBeOnTheScreen();
    expect(getByText('ErrorState')).toBeOnTheScreen();
    expect(getByText('PrimaryButton')).toBeOnTheScreen();
  });

  it('redirects to "/" instead of rendering when __DEV__ is false', async () => {
    devFlag.__DEV__ = false;

    const { getByTestId, queryByText } = await renderWithProviders(<DevGalleryScreen />);

    expect(getByTestId('redirect-stub')).toHaveTextContent('/');
    expect(queryByText('Component gallery')).toBeNull();
  });
});
