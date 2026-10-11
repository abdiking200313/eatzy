/**
 * Ports `flutter_app/test/merchant_store_controller_test.dart` (issue #407 /
 * P9-02) against the in-memory `FakeMerchantStoreRepository`, plus RN-only
 * cases for listener notification, the update failure path, and error
 * reporting.
 */
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { FakeMerchantStoreRepository } from '@/test-utils/fake-merchant-store-repository';

import type { MerchantStore } from './api/merchant-store';
import { MerchantStoreController, SAVE_FAILURE_MESSAGE } from './merchant-store-controller';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

const store: MerchantStore = {
  id: 'restaurant-1',
  vertical: 'food',
  name: 'Zivo Diner',
  location: '123 Main St',
  isOpen: true,
  description: null,
  imageUrl: null,
};

let originalReporter: ErrorReporter;
let reportError: jest.Mock;

beforeEach(() => {
  originalReporter = ErrorReporting.instance;
  reportError = jest.fn();
  ErrorReporting.instance = { reportError };
});

afterEach(() => {
  ErrorReporting.instance = originalReporter;
});

describe('load', () => {
  it('populates store and hasLoaded on success', async () => {
    const controller = new MerchantStoreController({ repository: new FakeMerchantStoreRepository({ initialStore: store }) });

    expect(controller.hasLoaded).toBe(false);
    await controller.load('merchant-1');

    expect(controller.hasLoaded).toBe(true);
    expect(controller.isLoading).toBe(false);
    expect(controller.loadError).toBeNull();
    expect(controller.store).toEqual(store);
  });

  it('hasLoaded is true with a null store (empty state)', async () => {
    const controller = new MerchantStoreController({ repository: new FakeMerchantStoreRepository() });

    await controller.load('merchant-1');

    expect(controller.hasLoaded).toBe(true);
    expect(controller.store).toBeNull();
    expect(controller.loadError).toBeNull();
  });

  it('sets loadError and leaves store null on failure', async () => {
    const repository = new FakeMerchantStoreRepository();
    repository.failureToThrow = new Error('network down');
    const controller = new MerchantStoreController({ repository });

    await controller.load('merchant-1');

    expect(controller.isLoading).toBe(false);
    expect(controller.loadError).not.toBeNull();
    expect(controller.store).toBeNull();
    expect(reportError).toHaveBeenCalledWith(repository.failureToThrow, expect.any(String), 'MerchantStoreController.load');
  });
});

describe('createStore', () => {
  it('sets store and returns true on success', async () => {
    const controller = new MerchantStoreController({ repository: new FakeMerchantStoreRepository() });

    const succeeded = await controller.createStore({
      vertical: 'grocery',
      ownerId: 'merchant-1',
      name: 'Bakaal Fresh',
      location: 'Hodan',
    });

    expect(succeeded).toBe(true);
    expect(controller.store).not.toBeNull();
    expect(controller.store!.name).toBe('Bakaal Fresh');
    expect(controller.saveError).toBeNull();
  });

  it('returns false and sets saveError on failure', async () => {
    const repository = new FakeMerchantStoreRepository();
    repository.failureToThrow = new Error('insert failed');
    const controller = new MerchantStoreController({ repository });

    const succeeded = await controller.createStore({
      vertical: 'food',
      ownerId: 'merchant-1',
      name: 'Zivo Diner',
      location: '123 Main St',
    });

    expect(succeeded).toBe(false);
    expect(controller.store).toBeNull();
    expect(controller.saveError).not.toBeNull();
  });
});

describe('updateStore', () => {
  it('returns false with no store loaded', async () => {
    const controller = new MerchantStoreController({ repository: new FakeMerchantStoreRepository() });

    const succeeded = await controller.updateStore({
      ownerId: 'merchant-1',
      name: 'New name',
      location: 'New location',
      isOpen: false,
    });

    expect(succeeded).toBe(false);
  });

  it('updates the loaded store on success', async () => {
    const controller = new MerchantStoreController({ repository: new FakeMerchantStoreRepository({ initialStore: store }) });
    await controller.load('merchant-1');

    const succeeded = await controller.updateStore({
      ownerId: 'merchant-1',
      name: 'Zivo Diner 2',
      location: '456 Side St',
      isOpen: false,
    });

    expect(succeeded).toBe(true);
    expect(controller.store!.name).toBe('Zivo Diner 2');
    expect(controller.store!.location).toBe('456 Side St');
    expect(controller.store!.isOpen).toBe(false);
  });
});

describe('RN-only cases', () => {
  it('keeps the loaded store and sets saveError when an update fails', async () => {
    const repository = new FakeMerchantStoreRepository({ initialStore: store });
    const controller = new MerchantStoreController({ repository });
    await controller.load('merchant-1');
    repository.failureToThrow = new Error('update failed');

    const succeeded = await controller.updateStore({ ownerId: 'merchant-1', name: 'X', location: 'Y', isOpen: true });

    expect(succeeded).toBe(false);
    expect(controller.saveError).toBe(SAVE_FAILURE_MESSAGE);
    expect(controller.isSaving).toBe(false);
    expect(controller.store).toEqual(store);
  });

  it('notifies subscribers with isLoading while a load is in flight', async () => {
    const controller = new MerchantStoreController({ repository: new FakeMerchantStoreRepository({ initialStore: store }) });
    const snapshots: boolean[] = [];
    const unsubscribe = controller.subscribe(() => snapshots.push(controller.getSnapshot().isLoading));

    await controller.load('merchant-1');
    unsubscribe();
    await controller.load('merchant-1');

    expect(snapshots).toEqual([true, false]);
  });
});
