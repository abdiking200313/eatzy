/**
 * Ports `flutter_app/test/my_store_screen_test.dart` (issue #407 / P9-02):
 * "My Store"'s loading/empty/error/loaded states against the in-memory
 * `FakeMerchantStoreRepository`, plus RN-only cases (create flow, name
 * validation, vertical-specific fields, store photo, Manage catalog). Photo
 * upload itself is covered by `../shared/merchant-photo-upload.test.tsx`.
 *
 * The Dart `find.byType(CircularProgressIndicator)` becomes the shared
 * `LoadingState`'s `testID`; `find.widgetWithText(TextFormField, 'Store
 * name')` becomes the field's placeholder (`AppTextField`'s `hint`).
 */
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';

import { FakeMerchantStoreRepository } from '@/test-utils/fake-merchant-store-repository';

import type { MerchantStore } from './api/merchant-store';
import type { MerchantStoreRepository } from './api/merchant-store-repository';
import { MerchantStoreController } from './merchant-store-controller';
import { MyStoreScreen } from './my-store-screen';

jest.mock('expo-router', () => ({ router: { push: jest.fn() } }));
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));
jest.mock('@/platform/error-reporting/error-reporter', () => ({ ErrorReporting: { instance: { reportError: jest.fn() } } }));

/** Mirrors the Dart `_NeverCompletingStoreRepository`: `fetchOwnStore` hangs until `complete` is called. */
class NeverCompletingStoreRepository implements MerchantStoreRepository {
  private resolve!: (store: MerchantStore | null) => void;
  private readonly pending = new Promise<MerchantStore | null>((resolve) => {
    this.resolve = resolve;
  });

  complete(store: MerchantStore | null): void {
    this.resolve(store);
  }

  fetchOwnStore(): Promise<MerchantStore | null> {
    return this.pending;
  }
  createStore(): Promise<MerchantStore> {
    throw new Error('unimplemented');
  }
  updateStore(): Promise<MerchantStore> {
    throw new Error('unimplemented');
  }
}

const dinerStore: MerchantStore = {
  id: 'restaurant-1',
  vertical: 'food',
  name: 'Zivo Diner',
  location: '123 Main St',
  isOpen: true,
  description: 'Somali comfort food',
  imageUrl: null,
};

function controllerFor(repository: MerchantStoreRepository) {
  return new MerchantStoreController({ repository });
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe('MyStoreScreen (my_store_screen_test.dart)', () => {
  it('shows a loading indicator while the store loads', async () => {
    const repository = new NeverCompletingStoreRepository();
    await render(<MyStoreScreen ownerId="merchant-1" controller={controllerFor(repository)} />);

    expect(screen.getByTestId('loading-state')).toBeTruthy();

    // Resolving lets the screen move on, proving it was genuinely waiting rather than stuck.
    await act(async () => repository.complete(null));
    await waitFor(() => expect(screen.queryByTestId('loading-state')).toBeNull());
  });

  it('shows the create-store empty state when the merchant has no store', async () => {
    await render(<MyStoreScreen ownerId="merchant-1" controller={controllerFor(new FakeMerchantStoreRepository())} />);

    expect(await screen.findByText("You don't have a store yet")).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Create store' })).toBeTruthy();
  });

  it('shows an error state with retry when the load fails', async () => {
    const repository = new FakeMerchantStoreRepository();
    repository.failureToThrow = new Error('boom');
    await render(<MyStoreScreen ownerId="merchant-1" controller={controllerFor(repository)} />);

    expect(await screen.findByText('Your store could not be loaded. Please try again.')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeTruthy();

    // Retrying with a working repository recovers into the loaded state.
    repository.failureToThrow = null;
    await fireEvent.press(screen.getByRole('button', { name: 'Try again' }));

    expect(await screen.findByText("You don't have a store yet")).toBeTruthy();
  });

  it('shows the edit form once a store is loaded', async () => {
    await render(
      <MyStoreScreen ownerId="merchant-1" controller={controllerFor(new FakeMerchantStoreRepository({ initialStore: dinerStore }))} />,
    );

    expect(await screen.findByText('Food store')).toBeTruthy();
    expect(screen.getByPlaceholderText('Store name')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Save changes' })).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Manage catalog' })).toBeTruthy();
  });

  it('editing and saving updates the store profile', async () => {
    const controller = controllerFor(new FakeMerchantStoreRepository({ initialStore: { ...dinerStore, description: null } }));
    await render(<MyStoreScreen ownerId="merchant-1" controller={controller} />);

    await fireEvent.changeText(await screen.findByPlaceholderText('Store name'), 'Zivo Diner Renamed');
    await fireEvent.press(screen.getByRole('button', { name: 'Save changes' }));

    await waitFor(() => expect(controller.store!.name).toBe('Zivo Diner Renamed'));
    expect(await screen.findByText('Store saved.')).toBeTruthy();
  });
});

describe('MyStoreScreen (RN-only cases)', () => {
  it('prefills the form, including description and open state, from the loaded store', async () => {
    await render(
      <MyStoreScreen ownerId="merchant-1" controller={controllerFor(new FakeMerchantStoreRepository({ initialStore: dinerStore }))} />,
    );

    expect((await screen.findByPlaceholderText('Store name')).props.value).toBe('Zivo Diner');
    expect(screen.getByPlaceholderText('Address').props.value).toBe('123 Main St');
    expect(screen.getByPlaceholderText('Description').props.value).toBe('Somali comfort food');
    expect(screen.getByText('Customers can see and order from this store.')).toBeTruthy();
  });

  it('toggling "Open for business" saves the store as closed', async () => {
    const controller = controllerFor(new FakeMerchantStoreRepository({ initialStore: dinerStore }));
    await render(<MyStoreScreen ownerId="merchant-1" controller={controller} />);

    await fireEvent(await screen.findByLabelText('Open for business'), 'valueChange', false);
    expect(screen.getByText('This store is hidden from customers.')).toBeTruthy();
    await fireEvent.press(screen.getByRole('button', { name: 'Save changes' }));

    await waitFor(() => expect(controller.store!.isOpen).toBe(false));
  });

  it('blocks saving a blank store name', async () => {
    const controller = controllerFor(new FakeMerchantStoreRepository({ initialStore: dinerStore }));
    const update = jest.spyOn(controller, 'updateStore');
    await render(<MyStoreScreen ownerId="merchant-1" controller={controller} />);

    await fireEvent.changeText(await screen.findByPlaceholderText('Store name'), '   ');
    await fireEvent.press(screen.getByRole('button', { name: 'Save changes' }));

    expect(screen.getByText('Enter a store name.')).toBeTruthy();
    expect(update).not.toHaveBeenCalled();
  });

  it('shows the save error when saving fails', async () => {
    const repository = new FakeMerchantStoreRepository({ initialStore: dinerStore });
    await render(<MyStoreScreen ownerId="merchant-1" controller={controllerFor(repository)} />);
    await screen.findByText('Food store');

    repository.failureToThrow = new Error('nope');
    await fireEvent.press(screen.getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('Your store could not be saved. Please try again.')).toBeTruthy();
    expect(screen.queryByText('Store saved.')).toBeNull();
  });

  it('a grocery store shows "Area" and no description field', async () => {
    const grocery: MerchantStore = { ...dinerStore, id: 'g-1', vertical: 'grocery', location: 'Hodan', description: null };
    await render(<MyStoreScreen ownerId="merchant-1" controller={controllerFor(new FakeMerchantStoreRepository({ initialStore: grocery }))} />);

    expect(await screen.findByText('Grocery store')).toBeTruthy();
    expect(screen.getByPlaceholderText('Area').props.value).toBe('Hodan');
    expect(screen.queryByPlaceholderText('Description')).toBeNull();
  });

  it('shows the existing store photo with change/remove actions', async () => {
    const withPhoto = { ...dinerStore, imageUrl: 'https://example.com/logo.png' };
    await render(<MyStoreScreen ownerId="merchant-1" controller={controllerFor(new FakeMerchantStoreRepository({ initialStore: withPhoto }))} />);

    // expo-image normalizes `source` to an array internally.
    expect([(await screen.findByTestId('store-photo')).props.source].flat()).toContainEqual({ uri: 'https://example.com/logo.png' });
    expect(screen.queryByTestId('store-photo-placeholder')).toBeNull();
    expect(screen.getByRole('button', { name: 'Change photo' })).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Remove' })).toBeTruthy();
  });

  it('keeps the existing photo when saving', async () => {
    const withPhoto = { ...dinerStore, imageUrl: 'https://example.com/logo.png' };
    const repository = new FakeMerchantStoreRepository({ initialStore: withPhoto });
    const update = jest.spyOn(repository, 'updateStore');
    await render(<MyStoreScreen ownerId="merchant-1" controller={controllerFor(repository)} />);

    await fireEvent.press(await screen.findByRole('button', { name: 'Save changes' }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    expect(update.mock.calls[0][1]).toMatchObject({ ownerId: 'merchant-1', imageUrl: 'https://example.com/logo.png' });
  });

  it('shows a photo placeholder when the store has no photo', async () => {
    await render(
      <MyStoreScreen ownerId="merchant-1" controller={controllerFor(new FakeMerchantStoreRepository({ initialStore: dinerStore }))} />,
    );

    expect(await screen.findByTestId('store-photo-placeholder')).toBeTruthy();
    expect(screen.queryByTestId('store-photo')).toBeNull();
  });

  it('"Manage catalog" opens the merchant catalog route', async () => {
    await render(
      <MyStoreScreen ownerId="merchant-1" controller={controllerFor(new FakeMerchantStoreRepository({ initialStore: dinerStore }))} />,
    );

    await fireEvent.press(await screen.findByRole('button', { name: 'Manage catalog' }));

    expect(router.push).toHaveBeenCalledWith('/merchant/catalog');
  });

  it('creating a pharmacy store submits the picked vertical and shows the edit form', async () => {
    const controller = controllerFor(new FakeMerchantStoreRepository());
    await render(<MyStoreScreen ownerId="merchant-1" controller={controller} />);

    await fireEvent.press(await screen.findByRole('radio', { name: 'Pharmacy' }));
    expect(screen.queryByPlaceholderText('Description')).toBeNull();
    await fireEvent.changeText(screen.getByPlaceholderText('Store name'), 'Care Pharmacy');
    await fireEvent.changeText(screen.getByPlaceholderText('Address'), 'KM4');
    await fireEvent.press(screen.getByRole('button', { name: 'Create store' }));

    expect(await screen.findByText('Pharmacy store')).toBeTruthy();
    expect(controller.store).toMatchObject({ vertical: 'pharmacy', name: 'Care Pharmacy', location: 'KM4' });
    expect(screen.getByText('Store created.')).toBeTruthy();
  });

  it('blocks creating a store without a name', async () => {
    const controller = controllerFor(new FakeMerchantStoreRepository());
    await render(<MyStoreScreen ownerId="merchant-1" controller={controller} />);

    await fireEvent.press(await screen.findByRole('button', { name: 'Create store' }));

    expect(screen.getByText('Enter a store name.')).toBeTruthy();
    expect(controller.store).toBeNull();
  });
});
