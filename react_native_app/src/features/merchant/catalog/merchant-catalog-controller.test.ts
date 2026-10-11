/**
 * Ports `flutter_app/test/merchant_catalog_controller_test.dart` (issue #410
 * / P9-05): `MerchantCatalogController`'s CRUD + availability-toggle
 * bookkeeping against the in-memory `FakeMerchantCatalogRepository`, plus
 * RN-only cases (update, sorting, failure messages, subscriptions).
 */
import { FakeMerchantCatalogRepository } from '@/test-utils/fake-merchant-catalog-repository';

import type { MerchantCatalogItem } from './api/merchant-catalog-item';
import {
  CATALOG_AVAILABILITY_FAILURE_MESSAGE,
  CATALOG_CREATE_FAILURE_MESSAGE,
  CATALOG_DELETE_FAILURE_MESSAGE,
  CATALOG_LOAD_FAILURE_MESSAGE,
  CATALOG_SAVE_FAILURE_MESSAGE,
  MerchantCatalogController,
} from './merchant-catalog-controller';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));
jest.mock('@/platform/error-reporting/error-reporter', () => ({ ErrorReporting: { instance: { reportError: jest.fn() } } }));

const item: MerchantCatalogItem = {
  id: 'item-1',
  storeId: 'store-1',
  vertical: 'food',
  name: 'Sambusa',
  description: null,
  priceCents: 250,
  isAvailable: true,
  imageUrl: null,
  pricingUnit: null,
  availableQuantity: null,
  categoryId: null,
  stockQuantity: null,
};

function foodController(repository: FakeMerchantCatalogRepository) {
  return new MerchantCatalogController({ repository, vertical: 'food', storeId: 'store-1' });
}

describe('MerchantCatalogController (merchant_catalog_controller_test.dart)', () => {
  describe('load', () => {
    it('populates items and hasLoaded on success', async () => {
      const controller = foodController(new FakeMerchantCatalogRepository({ initialItems: [item] }));

      expect(controller.hasLoaded).toBe(false);
      await controller.load();

      expect(controller.hasLoaded).toBe(true);
      expect(controller.items).toEqual([item]);
      expect(controller.loadError).toBeNull();
    });

    it('hasLoaded is true with an empty catalog', async () => {
      const controller = foodController(new FakeMerchantCatalogRepository());

      await controller.load();

      expect(controller.hasLoaded).toBe(true);
      expect(controller.items).toHaveLength(0);
    });

    it('sets loadError on failure', async () => {
      const repository = new FakeMerchantCatalogRepository();
      repository.failureToThrow = new Error('network down');
      const controller = foodController(repository);

      await controller.load();

      expect(controller.loadError).toBe(CATALOG_LOAD_FAILURE_MESSAGE);
      expect(controller.items).toHaveLength(0);
    });

    it('also loads pharmacy categories for the pharmacy vertical', async () => {
      const controller = new MerchantCatalogController({
        repository: new FakeMerchantCatalogRepository({ categories: [{ id: 'otc', name: 'OTC' }] }),
        vertical: 'pharmacy',
        storeId: 'pharmacy-1',
      });

      await controller.load();

      expect(controller.pharmacyCategories).toHaveLength(1);
      expect(controller.pharmacyCategories[0].id).toBe('otc');
    });
  });

  describe('createItem', () => {
    it('adds the created item to the list', async () => {
      const controller = foodController(new FakeMerchantCatalogRepository());

      const succeeded = await controller.createItem(item);

      expect(succeeded).toBe(true);
      expect(controller.items).toHaveLength(1);
      expect(controller.items[0].name).toBe('Sambusa');
    });

    it('returns false and sets saveError on failure', async () => {
      const repository = new FakeMerchantCatalogRepository();
      repository.failureToThrow = new Error('insert failed');
      const controller = foodController(repository);

      const succeeded = await controller.createItem(item);

      expect(succeeded).toBe(false);
      expect(controller.items).toHaveLength(0);
      expect(controller.saveError).toBe(CATALOG_CREATE_FAILURE_MESSAGE);
    });
  });

  describe('deleteItem', () => {
    it('removes the item from the list', async () => {
      const controller = foodController(new FakeMerchantCatalogRepository({ initialItems: [item] }));
      await controller.load();

      const succeeded = await controller.deleteItem(item);

      expect(succeeded).toBe(true);
      expect(controller.items).toHaveLength(0);
    });
  });

  describe('toggleAvailability', () => {
    it('flips isAvailable on the matching item', async () => {
      const controller = foodController(new FakeMerchantCatalogRepository({ initialItems: [item] }));
      await controller.load();

      const succeeded = await controller.toggleAvailability(item);

      expect(succeeded).toBe(true);
      expect(controller.items[0].isAvailable).toBe(false);
    });
  });
});

describe('MerchantCatalogController (RN-only cases)', () => {
  it('does not fetch pharmacy categories for other verticals', async () => {
    const repository = new FakeMerchantCatalogRepository({ categories: [{ id: 'otc', name: 'OTC' }] });
    const fetchCategories = jest.spyOn(repository, 'fetchPharmacyCategories');

    await foodController(repository).load();

    expect(fetchCategories).not.toHaveBeenCalled();
  });

  it('keeps items sorted by name after create and update', async () => {
    const repository = new FakeMerchantCatalogRepository({ initialItems: [item] });
    const controller = foodController(repository);
    await controller.load();

    await controller.createItem({ ...item, id: '', name: 'Anjero' });
    expect(controller.items.map((i) => i.name)).toEqual(['Anjero', 'Sambusa']);

    await controller.updateItem({ ...item, name: 'Bariis' });
    expect(controller.items.map((i) => i.name)).toEqual(['Anjero', 'Bariis']);
  });

  it('updateItem replaces the matching item', async () => {
    const controller = foodController(new FakeMerchantCatalogRepository({ initialItems: [item] }));
    await controller.load();

    expect(await controller.updateItem({ ...item, priceCents: 300 })).toBe(true);

    expect(controller.items).toHaveLength(1);
    expect(controller.items[0].priceCents).toBe(300);
    expect(controller.saveError).toBeNull();
  });

  it.each([
    ['updateItem', CATALOG_SAVE_FAILURE_MESSAGE],
    ['deleteItem', CATALOG_DELETE_FAILURE_MESSAGE],
    ['toggleAvailability', CATALOG_AVAILABILITY_FAILURE_MESSAGE],
  ] as const)('%s returns false, keeps the items and sets its saveError on failure', async (method, message) => {
    const repository = new FakeMerchantCatalogRepository({ initialItems: [item] });
    const controller = foodController(repository);
    await controller.load();
    repository.failureToThrow = new Error('nope');

    expect(await controller[method](item)).toBe(false);

    expect(controller.items).toEqual([item]);
    expect(controller.saveError).toBe(message);
    expect(controller.isSaving).toBe(false);
  });

  it('notifies subscribers and exposes isSaving while a mutation runs', async () => {
    const controller = foodController(new FakeMerchantCatalogRepository());
    const savingStates: boolean[] = [];
    const unsubscribe = controller.subscribe(() => savingStates.push(controller.isSaving));

    await controller.createItem(item);
    unsubscribe();
    await controller.createItem({ ...item, name: 'Other' });

    expect(savingStates).toEqual([true, false]);
  });
});
