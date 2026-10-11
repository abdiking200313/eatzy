/**
 * Ports `flutter_app/test/catalog_screen_test.dart` (issue #410 / P9-05):
 * the Catalog screen's loading/empty/error/loaded states plus add/delete/
 * toggle against the in-memory `FakeMerchantCatalogRepository`, and RN-only
 * cases (edit, form validation, vertical-specific fields, self-resolving
 * the merchant's own store on the route).
 *
 * `find.byType(CircularProgressIndicator)` becomes the shared
 * `LoadingState`'s `testID`; `find.widgetWithText(TextFormField, 'Name')`
 * becomes the field's placeholder; the Dart `AlertDialog` is the platform
 * `Alert.alert`, whose "Delete" button is invoked from the spy.
 */
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { Alert, type AlertButton } from 'react-native';

import { FakeMerchantCatalogRepository } from '@/test-utils/fake-merchant-catalog-repository';
import { FakeMerchantStoreRepository } from '@/test-utils/fake-merchant-store-repository';

import { MerchantStoreController } from '../store/merchant-store-controller';
import type { MerchantCatalogItem, PharmacyCategory } from './api/merchant-catalog-item';
import type { MerchantCatalogRepository } from './api/merchant-catalog-repository';
import { CatalogScreen } from './catalog-screen';
import { MerchantCatalogController } from './merchant-catalog-controller';

jest.mock('expo-router', () => ({ router: { push: jest.fn(), back: jest.fn(), canGoBack: jest.fn(() => true), replace: jest.fn() } }));
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));
jest.mock('@/platform/error-reporting/error-reporter', () => ({ ErrorReporting: { instance: { reportError: jest.fn() } } }));

/** Mirrors the Dart `_NeverCompletingCatalogRepository`: `fetchItems` hangs until `complete` is called. */
class NeverCompletingCatalogRepository implements MerchantCatalogRepository {
  private resolve!: (items: MerchantCatalogItem[]) => void;
  private readonly pending = new Promise<MerchantCatalogItem[]>((resolve) => {
    this.resolve = resolve;
  });

  complete(items: MerchantCatalogItem[]): void {
    this.resolve(items);
  }

  fetchItems(): Promise<MerchantCatalogItem[]> {
    return this.pending;
  }
  createItem(): Promise<MerchantCatalogItem> {
    throw new Error('unimplemented');
  }
  updateItem(): Promise<MerchantCatalogItem> {
    throw new Error('unimplemented');
  }
  deleteItem(): Promise<void> {
    throw new Error('unimplemented');
  }
  setAvailability(): Promise<MerchantCatalogItem> {
    throw new Error('unimplemented');
  }
  async fetchPharmacyCategories(): Promise<PharmacyCategory[]> {
    return [];
  }
}

const item: MerchantCatalogItem = {
  id: 'item-1',
  storeId: 'store-1',
  vertical: 'food',
  name: 'Sambusa',
  description: 'Fried pastry with spiced filling',
  priceCents: 250,
  isAvailable: true,
  imageUrl: null,
  pricingUnit: null,
  availableQuantity: null,
  categoryId: null,
  stockQuantity: null,
};

function foodController(repository: MerchantCatalogRepository) {
  return new MerchantCatalogController({ repository, vertical: 'food', storeId: 'store-1' });
}

function renderScreen(controller: MerchantCatalogController) {
  return render(<CatalogScreen vertical={controller.vertical} storeId={controller.storeId} storeName="Zivo Diner" controller={controller} />);
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe('CatalogScreen (catalog_screen_test.dart)', () => {
  it('shows a loading indicator while the catalog loads', async () => {
    const repository = new NeverCompletingCatalogRepository();
    await renderScreen(foodController(repository));

    expect(screen.getByTestId('loading-state')).toBeTruthy();

    await act(async () => repository.complete([]));
    await waitFor(() => expect(screen.queryByTestId('loading-state')).toBeNull());
  });

  it('shows an empty state with an add-item action', async () => {
    await renderScreen(foodController(new FakeMerchantCatalogRepository()));

    expect(await screen.findByText('No items yet')).toBeTruthy();
    expect(screen.getByTestId('catalog-empty-add')).toBeTruthy();
  });

  it('shows an error state with retry when the load fails', async () => {
    const repository = new FakeMerchantCatalogRepository();
    repository.failureToThrow = new Error('boom');
    await renderScreen(foodController(repository));

    expect(await screen.findByText('Your catalog could not be loaded. Please try again.')).toBeTruthy();

    repository.failureToThrow = null;
    await fireEvent.press(screen.getByRole('button', { name: 'Try again' }));

    expect(await screen.findByText('No items yet')).toBeTruthy();
  });

  it('lists items with price, and supports delete', async () => {
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
    await renderScreen(foodController(new FakeMerchantCatalogRepository({ initialItems: [item] })));

    expect(await screen.findByText('Sambusa')).toBeTruthy();
    expect(screen.getByText('$2.50')).toBeTruthy();

    await fireEvent.press(screen.getByRole('button', { name: 'Delete' }));
    expect(alertSpy).toHaveBeenCalledWith('Delete item?', '"Sambusa" will be removed from your catalog.', expect.any(Array));
    const buttons = alertSpy.mock.calls[0][2] as AlertButton[];
    await act(async () => buttons.find((b) => b.text === 'Delete')!.onPress!());

    await waitFor(() => expect(screen.queryByText('Sambusa')).toBeNull());
    expect(screen.getByText('No items yet')).toBeTruthy();
  });

  it('toggling the switch flips availability', async () => {
    const controller = foodController(new FakeMerchantCatalogRepository({ initialItems: [item] }));
    await renderScreen(controller);
    await screen.findByText('Sambusa');

    expect(controller.items[0].isAvailable).toBe(true);

    await fireEvent(screen.getByLabelText('Sambusa available'), 'valueChange', false);

    await waitFor(() => expect(controller.items[0].isAvailable).toBe(false));
  });

  it('adding an item through the form appends it to the list', async () => {
    const controller = foodController(new FakeMerchantCatalogRepository());
    await renderScreen(controller);
    await screen.findByText('No items yet');

    // The FAB, rather than the empty state's identically labelled button.
    await fireEvent.press(screen.getByTestId('catalog-add-fab'));
    await fireEvent.changeText(await screen.findByPlaceholderText('Name'), 'Cambuulo');
    await fireEvent.changeText(screen.getByPlaceholderText('Price (USD)'), '3.50');
    await fireEvent.press(screen.getByTestId('catalog-item-submit'));

    await waitFor(() => expect(controller.items).toHaveLength(1));
    expect(controller.items[0].name).toBe('Cambuulo');
    expect(controller.items[0].priceCents).toBe(350);
    await waitFor(() => expect(screen.queryByTestId('catalog-item-form')).toBeNull());
    expect(screen.getByText('Cambuulo')).toBeTruthy();
  });
});

describe('CatalogScreen (RN-only cases)', () => {
  it('cancelling the delete confirmation keeps the item', async () => {
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
    const repository = new FakeMerchantCatalogRepository({ initialItems: [item] });
    const remove = jest.spyOn(repository, 'deleteItem');
    await renderScreen(foodController(repository));

    await fireEvent.press(await screen.findByRole('button', { name: 'Delete' }));
    const buttons = alertSpy.mock.calls[0][2] as AlertButton[];
    expect(buttons.find((b) => b.text === 'Cancel')!.onPress).toBeUndefined();

    expect(remove).not.toHaveBeenCalled();
    expect(screen.getByText('Sambusa')).toBeTruthy();
  });

  it('editing an item prefills the form and saves the change', async () => {
    const controller = foodController(new FakeMerchantCatalogRepository({ initialItems: [item] }));
    await renderScreen(controller);

    await fireEvent.press(await screen.findByRole('button', { name: 'Edit' }));
    expect(screen.getByText('Edit item')).toBeTruthy();
    expect(screen.getByPlaceholderText('Name').props.value).toBe('Sambusa');
    expect(screen.getByPlaceholderText('Price (USD)').props.value).toBe('2.50');

    await fireEvent.changeText(screen.getByPlaceholderText('Price (USD)'), '2.75');
    await fireEvent.press(screen.getByRole('button', { name: 'Save item' }));

    await waitFor(() => expect(controller.items[0].priceCents).toBe(275));
    expect(controller.items[0].id).toBe('item-1');
    expect(await screen.findByText('$2.75')).toBeTruthy();
  });

  it('blocks submitting a blank name or invalid price', async () => {
    const controller = foodController(new FakeMerchantCatalogRepository());
    const create = jest.spyOn(controller, 'createItem');
    await renderScreen(controller);
    await screen.findByText('No items yet');

    await fireEvent.press(screen.getByTestId('catalog-add-fab'));
    await fireEvent.changeText(await screen.findByPlaceholderText('Price (USD)'), '-1');
    await fireEvent.press(screen.getByTestId('catalog-item-submit'));

    expect(screen.getByText('Enter a name.')).toBeTruthy();
    expect(screen.getByText('Enter a valid, non-negative price.')).toBeTruthy();
    expect(create).not.toHaveBeenCalled();
  });

  it('shows the save error and keeps the form open when saving fails', async () => {
    const repository = new FakeMerchantCatalogRepository();
    await renderScreen(foodController(repository));
    await screen.findByText('No items yet');
    repository.failureToThrow = new Error('nope');

    await fireEvent.press(screen.getByTestId('catalog-add-fab'));
    await fireEvent.changeText(await screen.findByPlaceholderText('Name'), 'Cambuulo');
    await fireEvent.changeText(screen.getByPlaceholderText('Price (USD)'), '3.50');
    await fireEvent.press(screen.getByTestId('catalog-item-submit'));

    expect(await screen.findByText('The item could not be added. Please try again.')).toBeTruthy();
    expect(screen.getByTestId('catalog-item-form')).toBeTruthy();
  });

  it('a grocery item form offers pricing unit and quantity', async () => {
    const controller = new MerchantCatalogController({ repository: new FakeMerchantCatalogRepository(), vertical: 'grocery', storeId: 'g-1' });
    await renderScreen(controller);
    await screen.findByText('No items yet');

    await fireEvent.press(screen.getByTestId('catalog-add-fab'));
    await fireEvent.changeText(await screen.findByPlaceholderText('Name'), 'Bananas');
    await fireEvent.changeText(screen.getByPlaceholderText('Price (per unit, USD)'), '1.20');
    await fireEvent.press(screen.getByRole('radio', { name: 'Per kilogram' }));
    await fireEvent.changeText(screen.getByPlaceholderText('Available quantity'), '12.5');
    await fireEvent.press(screen.getByTestId('catalog-item-submit'));

    await waitFor(() => expect(controller.items).toHaveLength(1));
    expect(controller.items[0]).toMatchObject({ pricingUnit: 'kilogram', availableQuantity: 12.5, priceCents: 120, categoryId: null });
  });

  it('a pharmacy item form requires a category', async () => {
    const controller = new MerchantCatalogController({
      repository: new FakeMerchantCatalogRepository({ categories: [{ id: 'otc', name: 'Pain relief' }] }),
      vertical: 'pharmacy',
      storeId: 'p-1',
    });
    await renderScreen(controller);
    await screen.findByText('No items yet');

    await fireEvent.press(screen.getByTestId('catalog-add-fab'));
    await fireEvent.changeText(await screen.findByPlaceholderText('Name'), 'Paracetamol');
    await fireEvent.changeText(screen.getByPlaceholderText('Price (USD)'), '4');
    await fireEvent.press(screen.getByTestId('catalog-item-submit'));
    expect(screen.getByText('Choose a category.')).toBeTruthy();
    expect(controller.items).toHaveLength(0);

    await fireEvent.press(screen.getByRole('radio', { name: 'Pain relief' }));
    await fireEvent.changeText(screen.getByPlaceholderText('Stock quantity'), '30');
    await fireEvent.press(screen.getByTestId('catalog-item-submit'));

    await waitFor(() => expect(controller.items).toHaveLength(1));
    expect(controller.items[0]).toMatchObject({ categoryId: 'otc', stockQuantity: 30, priceCents: 400, pricingUnit: null });
  });

  it('a new item can be added as unavailable', async () => {
    const controller = foodController(new FakeMerchantCatalogRepository());
    await renderScreen(controller);
    await screen.findByText('No items yet');

    await fireEvent.press(screen.getByTestId('catalog-add-fab'));
    await fireEvent.changeText(await screen.findByPlaceholderText('Name'), 'Shaah');
    await fireEvent.changeText(screen.getByPlaceholderText('Price (USD)'), '1');
    await fireEvent(screen.getByLabelText('Available'), 'valueChange', false);
    await fireEvent.press(screen.getByTestId('catalog-item-submit'));

    await waitFor(() => expect(controller.items).toHaveLength(1));
    expect(controller.items[0].isAvailable).toBe(false);
  });

  it('resolves the merchant\'s own store when opened without store params', async () => {
    const storeController = new MerchantStoreController({
      repository: new FakeMerchantStoreRepository({
        initialStore: { id: 'store-1', vertical: 'food', name: 'Zivo Diner', location: '', isOpen: true, description: null, imageUrl: null },
      }),
    });
    await render(
      <CatalogScreen
        ownerId="merchant-1"
        storeController={storeController}
        catalogRepository={new FakeMerchantCatalogRepository({ initialItems: [item] })}
      />,
    );

    expect(await screen.findByText('Sambusa')).toBeTruthy();
    expect(screen.getByText('Zivo Diner')).toBeTruthy();
    expect(screen.getByTestId('catalog-add-fab')).toBeTruthy();
  });

  it('shows "Set up your store first" when the merchant has no store', async () => {
    const storeController = new MerchantStoreController({ repository: new FakeMerchantStoreRepository() });
    await render(<CatalogScreen ownerId="merchant-1" storeController={storeController} />);

    expect(await screen.findByText('Set up your store first')).toBeTruthy();
    expect(screen.queryByTestId('catalog-add-fab')).toBeNull();
  });

  it('shows "Set up your store first" with no signed-in merchant', async () => {
    await render(<CatalogScreen ownerId={null} />);

    expect(screen.getByText('Set up your store first')).toBeTruthy();
  });
});
