/**
 * Ports `flutter_app/test/merchant_photo_upload_test.dart` (issue #411 /
 * P9-06): `ownedPathFromUrl`, `MerchantPhotoSession`'s cleanup rules, and
 * uploading a photo from My Store and the Catalog item form -- plus RN-only
 * cases for the Supabase-backed store's bucket paths, the crop helpers,
 * upload failure, removal, abandoning a form, and the catalog's delete
 * cleanup (the Dart `media.deleteIfOwned` after `deleteItem`).
 *
 * The Dart `_fakePicker` returning a 1x1 PNG becomes a picker returning a
 * few bytes and a fake preview URI (expo-image never decodes it under Jest).
 */
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { ImageManipulator } from 'expo-image-manipulator';
import * as ImagePicker from 'expo-image-picker';
import { Alert, type AlertButton } from 'react-native';

import { FakeMerchantCatalogRepository } from '@/test-utils/fake-merchant-catalog-repository';
import { FakeMerchantStoreRepository } from '@/test-utils/fake-merchant-store-repository';

import type { MerchantCatalogItem } from '../catalog/api/merchant-catalog-item';
import { CatalogScreen } from '../catalog/catalog-screen';
import { MerchantCatalogController } from '../catalog/merchant-catalog-controller';
import type { MerchantStore } from '../store/api/merchant-store';
import { MerchantStoreController } from '../store/merchant-store-controller';
import { MyStoreScreen } from '../store/my-store-screen';
import {
  extensionFor,
  MERCHANT_MEDIA_FOLDER_CONFIG,
  MerchantPhotoSession,
  ownedPathFromUrl,
  SIGN_IN_TO_MANAGE_PHOTOS_MESSAGE,
  SupabaseMerchantMediaStore,
  type MerchantMediaClient,
  type MerchantMediaFolder,
  type MerchantMediaStore,
  type MerchantMediaUpload,
} from './merchant-media-store';
import { UPLOAD_FAILED_MESSAGE } from './merchant-photo-field';
import { base64ToBytes, centerCropRect, pickAndCropMerchantPhoto, type PickedMerchantPhoto } from './pick-merchant-photo';

jest.mock('expo-router', () => ({ router: { push: jest.fn(), back: jest.fn(), canGoBack: jest.fn(() => true), replace: jest.fn() } }));
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));
jest.mock('@/platform/error-reporting/error-reporter', () => ({ ErrorReporting: { instance: { reportError: jest.fn() } } }));
jest.mock('expo-image-picker', () => ({ launchImageLibraryAsync: jest.fn() }));
jest.mock('expo-image-manipulator', () => ({
  ImageManipulator: { manipulate: jest.fn() },
  SaveFormat: { JPEG: 'jpeg', PNG: 'png', WEBP: 'webp' },
}));

const PHOTO_BYTES = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);

/** Mirrors the Dart `_FakeMediaStore`. */
class FakeMediaStore implements MerchantMediaStore {
  readonly uploadedTo: MerchantMediaFolder[] = [];
  readonly deleted: string[] = [];
  uploadError: unknown = null;

  async upload({ folder }: MerchantMediaUpload): Promise<string> {
    if (this.uploadError != null) throw this.uploadError;
    this.uploadedTo.push(folder);
    return `https://cdn.test/${MERCHANT_MEDIA_FOLDER_CONFIG[folder].pathSegment}/${this.uploadedTo.length}.jpg`;
  }

  async deleteIfOwned(url: string): Promise<void> {
    this.deleted.push(url);
  }
}

let pickedFor: MerchantMediaFolder[] = [];

/** Mirrors the Dart `_fakePicker`. */
async function fakePicker(folder: MerchantMediaFolder): Promise<PickedMerchantPhoto | null> {
  pickedFor.push(folder);
  return { bytes: PHOTO_BYTES, contentType: 'image/png', previewUri: 'file:///picked.png' };
}

const greenBasket: MerchantStore = {
  id: 'grocery-1',
  vertical: 'grocery',
  name: 'Green Basket',
  location: 'Hodan',
  isOpen: true,
  description: null,
  imageUrl: 'https://cdn.test/store/old.jpg',
};

/** Lets the fire-and-forget `deleteIfOwned` calls land (the Dart `Future.delayed(Duration.zero)`). */
const flush = () => act(async () => {});

beforeEach(() => {
  pickedFor = [];
  jest.clearAllMocks();
  jest.spyOn(console, 'warn').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('merchant photo upload (merchant_photo_upload_test.dart)', () => {
  it("ownedPathFromUrl only accepts the user's own merchant_media files", () => {
    const base = 'https://abc.supabase.co/storage/v1/object/public/merchant_media';
    expect(ownedPathFromUrl(`${base}/u1/items/1.jpg`, 'u1')).toBe('u1/items/1.jpg');
    expect(ownedPathFromUrl(`${base}/u2/items/1.jpg`, 'u1')).toBeNull();
    expect(ownedPathFromUrl('https://example.com/logo.png', 'u1')).toBeNull();
  });

  it('photo session deletes replaced and abandoned uploads only', async () => {
    const media = new FakeMediaStore();
    const session = new MerchantPhotoSession(media, 'old.jpg');
    const first = await session.upload({ bytes: PHOTO_BYTES, contentType: 'image/png', folder: 'items' });
    const second = await session.upload({ bytes: PHOTO_BYTES, contentType: 'image/png', folder: 'items' });

    session.commit(second);
    await flush();
    expect([...media.deleted].sort()).toEqual([first, 'old.jpg'].sort());

    const abandoned = await session.upload({ bytes: PHOTO_BYTES, contentType: 'image/png', folder: 'items' });
    session.discard();
    await flush();
    expect(media.deleted).toContain(abandoned);
    expect(media.deleted).not.toContain(second);
  });

  it('a store photo is uploaded as a banner and saved on the store', async () => {
    const media = new FakeMediaStore();
    const controller = new MerchantStoreController({ repository: new FakeMerchantStoreRepository({ initialStore: greenBasket }) });
    await render(<MyStoreScreen ownerId="merchant-1" controller={controller} media={media} photoPicker={fakePicker} />);

    await fireEvent.press(await screen.findByRole('button', { name: 'Change photo' }));
    await waitFor(() => expect(media.uploadedTo).toHaveLength(1));
    await fireEvent.press(screen.getByRole('button', { name: 'Save changes' }));
    await waitFor(() => expect(controller.store?.imageUrl).toBe('https://cdn.test/store/1.jpg'));
    await flush();

    expect(pickedFor).toEqual(['store']);
    expect(MERCHANT_MEDIA_FOLDER_CONFIG.store.aspectX).toBe(16);
    expect(media.deleted).toEqual(['https://cdn.test/store/old.jpg']);
  });

  it('a grocery item can be added with an uploaded photo', async () => {
    const media = new FakeMediaStore();
    const controller = new MerchantCatalogController({
      repository: new FakeMerchantCatalogRepository(),
      vertical: 'grocery',
      storeId: 'grocery-1',
    });
    await render(
      <CatalogScreen
        vertical="grocery"
        storeId="grocery-1"
        storeName="Green Basket"
        controller={controller}
        media={media}
        photoPicker={fakePicker}
      />,
    );
    await screen.findByText('No items yet');

    await fireEvent.press(screen.getByTestId('catalog-add-fab'));
    await fireEvent.changeText(await screen.findByPlaceholderText('Name'), 'Mango');
    await fireEvent.changeText(screen.getByPlaceholderText('Price (per unit, USD)'), '1.20');
    await fireEvent.press(screen.getByRole('button', { name: 'Upload photo' }));
    await waitFor(() => expect(media.uploadedTo).toHaveLength(1));
    await fireEvent.press(screen.getByTestId('catalog-item-submit'));
    await waitFor(() => expect(controller.items).toHaveLength(1));
    await flush();

    expect(pickedFor).toEqual(['items']);
    expect(controller.items[0].imageUrl).toBe('https://cdn.test/items/1.jpg');
    expect(media.deleted).toEqual([]);
  });
});

describe('merchant photo upload (RN-only cases)', () => {
  function fakeClient({ userId = 'u1' }: { userId?: string | null } = {}) {
    const upload = jest.fn(async () => ({ error: null }));
    const remove = jest.fn(async () => ({ error: null }));
    const from = jest.fn(() => ({
      upload,
      remove,
      getPublicUrl: (path: string) => ({
        data: { publicUrl: `https://abc.supabase.co/storage/v1/object/public/merchant_media/${path}` },
      }),
    }));
    const client: MerchantMediaClient = {
      auth: { getSession: async () => ({ data: { session: userId == null ? null : { user: { id: userId } } } }) },
      storage: { from },
    };
    return { client, upload, remove, from };
  }

  it("uploads into the merchant's own folder with the content type's extension", async () => {
    const { client, upload, from } = fakeClient();
    const store = new SupabaseMerchantMediaStore(client, () => 1700000000000);

    const url = await store.upload({ bytes: PHOTO_BYTES, contentType: 'image/png', folder: 'items' });

    expect(from).toHaveBeenCalledWith('merchant_media');
    expect(upload).toHaveBeenCalledWith('u1/items/1700000000000.png', expect.any(ArrayBuffer), { contentType: 'image/png' });
    expect(new Uint8Array((upload.mock.calls[0] as unknown[])[1] as ArrayBuffer)).toEqual(PHOTO_BYTES);
    expect(url).toBe('https://abc.supabase.co/storage/v1/object/public/merchant_media/u1/items/1700000000000.png');
  });

  it('maps content types to extensions, defaulting to jpg', () => {
    expect(extensionFor('image/png')).toBe('png');
    expect(extensionFor('image/webp')).toBe('webp');
    expect(extensionFor('image/jpeg')).toBe('jpg');
    expect(extensionFor('image/heic')).toBe('jpg');
  });

  it("deleteIfOwned removes only the signed-in merchant's own files", async () => {
    const { client, remove } = fakeClient();
    const store = new SupabaseMerchantMediaStore(client);
    const base = 'https://abc.supabase.co/storage/v1/object/public/merchant_media';

    await store.deleteIfOwned(`${base}/u1/store/1.jpg?t=1`);
    await store.deleteIfOwned(`${base}/u2/store/1.jpg`);
    await store.deleteIfOwned('https://example.com/logo.png');

    expect(remove).toHaveBeenCalledTimes(1);
    expect(remove).toHaveBeenCalledWith(['u1/store/1.jpg']);
  });

  it('requires a signed-in user to upload', async () => {
    const { client, upload } = fakeClient({ userId: null });
    const store = new SupabaseMerchantMediaStore(client);

    await expect(store.upload({ bytes: PHOTO_BYTES, contentType: 'image/jpeg', folder: 'store' })).rejects.toThrow(
      SIGN_IN_TO_MANAGE_PHOTOS_MESSAGE,
    );
    expect(upload).not.toHaveBeenCalled();
  });

  it('surfaces a storage upload error', async () => {
    const { client, upload } = fakeClient();
    upload.mockResolvedValueOnce({ error: new Error('Payload too large') } as never);
    const store = new SupabaseMerchantMediaStore(client);

    await expect(store.upload({ bytes: PHOTO_BYTES, contentType: 'image/jpeg', folder: 'store' })).rejects.toThrow(
      'Payload too large',
    );
  });

  it('centre-crops to the folder aspect', () => {
    expect(centerCropRect(2000, 1000, 16, 9)).toEqual({ originX: 111, originY: 0, width: 1778, height: 1000 });
    expect(centerCropRect(1000, 2000, 16, 9)).toEqual({ originX: 0, originY: 718, width: 1000, height: 563 });
    expect(centerCropRect(800, 600, 1, 1)).toEqual({ originX: 100, originY: 0, width: 600, height: 600 });
    expect(centerCropRect(500, 500, 1, 1)).toEqual({ originX: 0, originY: 0, width: 500, height: 500 });
  });

  it('decodes base64 into bytes', () => {
    expect(base64ToBytes('iVBORw==')).toEqual(PHOTO_BYTES);
    expect(base64ToBytes('aGk')).toEqual(new Uint8Array([0x68, 0x69]));
    expect(base64ToBytes('')).toEqual(new Uint8Array([]));
  });

  it('picks with a locked aspect, crops to it, and re-encodes as JPEG', async () => {
    jest.mocked(ImagePicker.launchImageLibraryAsync).mockResolvedValue({
      canceled: false,
      assets: [{ uri: 'file:///raw.jpg', width: 3000, height: 3000 }],
    } as never);
    const saveAsync = jest.fn(async () => ({ uri: 'file:///cropped.jpg', width: 1600, height: 900, base64: 'iVBORw==' }));
    const context: { resize: jest.Mock; crop: jest.Mock; renderAsync: jest.Mock } = {
      resize: jest.fn(() => context),
      crop: jest.fn(() => context),
      renderAsync: jest.fn(async () => ({ saveAsync })),
    };
    jest.mocked(ImageManipulator.manipulate).mockReturnValue(context as never);

    const picked = await pickAndCropMerchantPhoto('store');

    expect(ImagePicker.launchImageLibraryAsync).toHaveBeenCalledWith(
      expect.objectContaining({ allowsEditing: true, aspect: [16, 9], mediaTypes: ['images'] }),
    );
    expect(context.resize).toHaveBeenNthCalledWith(1, { width: 2000, height: 2000 });
    expect(context.crop).toHaveBeenCalledWith({ originX: 0, originY: 437, width: 2000, height: 1125 });
    expect(context.resize).toHaveBeenNthCalledWith(2, { width: 1600 });
    expect(saveAsync).toHaveBeenCalledWith({ format: 'jpeg', compress: 0.85, base64: true });
    expect(picked).toEqual({ bytes: PHOTO_BYTES, contentType: 'image/jpeg', previewUri: 'file:///cropped.jpg' });
  });

  it('resolves null when the merchant cancels the picker', async () => {
    jest.mocked(ImagePicker.launchImageLibraryAsync).mockResolvedValue({ canceled: true, assets: null } as never);

    expect(await pickAndCropMerchantPhoto('items')).toBeNull();
    expect(ImageManipulator.manipulate).not.toHaveBeenCalled();
  });

  it('a failed upload shows an error and keeps the saved photo', async () => {
    const media = new FakeMediaStore();
    media.uploadError = new Error('offline');
    const repository = new FakeMerchantStoreRepository({ initialStore: greenBasket });
    const update = jest.spyOn(repository, 'updateStore');
    const controller = new MerchantStoreController({ repository });
    await render(<MyStoreScreen ownerId="merchant-1" controller={controller} media={media} photoPicker={fakePicker} />);

    await fireEvent.press(await screen.findByRole('button', { name: 'Change photo' }));
    expect(await screen.findByText(UPLOAD_FAILED_MESSAGE)).toBeTruthy();
    expect([screen.getByTestId('store-photo').props.source].flat()).toContainEqual({ uri: 'https://cdn.test/store/old.jpg' });

    await fireEvent.press(screen.getByRole('button', { name: 'Save changes' }));
    await waitFor(() => expect(update).toHaveBeenCalled());
    expect(update.mock.calls[0][1]).toMatchObject({ imageUrl: 'https://cdn.test/store/old.jpg' });
  });

  it('removing the store photo saves no photo and deletes the old one', async () => {
    const media = new FakeMediaStore();
    const repository = new FakeMerchantStoreRepository({ initialStore: greenBasket });
    const update = jest.spyOn(repository, 'updateStore');
    await render(
      <MyStoreScreen
        ownerId="merchant-1"
        controller={new MerchantStoreController({ repository })}
        media={media}
        photoPicker={fakePicker}
      />,
    );

    await fireEvent.press(await screen.findByRole('button', { name: 'Remove' }));
    expect(screen.getByTestId('store-photo-placeholder')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Upload photo' })).toBeTruthy();
    await fireEvent.press(screen.getByRole('button', { name: 'Save changes' }));
    await waitFor(() => expect(update).toHaveBeenCalled());
    await flush();

    expect(update.mock.calls[0][1]).toMatchObject({ imageUrl: null });
    expect(media.deleted).toEqual(['https://cdn.test/store/old.jpg']);
  });

  it('a new store can be created with an uploaded photo', async () => {
    const media = new FakeMediaStore();
    const controller = new MerchantStoreController({ repository: new FakeMerchantStoreRepository() });
    await render(<MyStoreScreen ownerId="merchant-1" controller={controller} media={media} photoPicker={fakePicker} />);

    await fireEvent.changeText(await screen.findByPlaceholderText('Store name'), 'Zivo Diner');
    await fireEvent.press(screen.getByRole('button', { name: 'Upload photo' }));
    await waitFor(() => expect(media.uploadedTo).toEqual(['store']));
    await fireEvent.press(screen.getByRole('button', { name: 'Create store' }));

    await waitFor(() => expect(controller.store?.imageUrl).toBe('https://cdn.test/store/1.jpg'));
    await flush();
    expect(media.deleted).toEqual([]);
  });

  it('holds off saving while a photo is uploading', async () => {
    let finishUpload!: (url: string) => void;
    const media: MerchantMediaStore = {
      upload: () => new Promise<string>((resolve) => (finishUpload = resolve)),
      deleteIfOwned: jest.fn(async () => {}),
    };
    await render(
      <MyStoreScreen
        ownerId="merchant-1"
        controller={new MerchantStoreController({ repository: new FakeMerchantStoreRepository({ initialStore: greenBasket }) })}
        media={media}
        photoPicker={fakePicker}
      />,
    );

    await fireEvent.press(await screen.findByRole('button', { name: 'Change photo' }));
    expect(await screen.findByTestId('store-photo-uploading')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Save changes' }).props.accessibilityState).toMatchObject({ disabled: true });
    expect(screen.getByRole('button', { name: 'Change photo' }).props.accessibilityState).toMatchObject({ disabled: true });

    await act(async () => finishUpload('https://cdn.test/store/new.jpg'));
    await waitFor(() => expect(screen.queryByTestId('store-photo-uploading')).toBeNull());
    expect(screen.getByRole('button', { name: 'Save changes' }).props.accessibilityState).toMatchObject({ disabled: false });
  });

  it('closing the item form without saving deletes its uploads', async () => {
    const media = new FakeMediaStore();
    const controller = new MerchantCatalogController({
      repository: new FakeMerchantCatalogRepository(),
      vertical: 'grocery',
      storeId: 'grocery-1',
    });
    const view = await render(
      <CatalogScreen vertical="grocery" storeId="grocery-1" controller={controller} media={media} photoPicker={fakePicker} />,
    );
    await screen.findByText('No items yet');

    await fireEvent.press(screen.getByTestId('catalog-add-fab'));
    await fireEvent.press(await screen.findByRole('button', { name: 'Upload photo' }));
    await waitFor(() => expect(media.uploadedTo).toHaveLength(1));
    await view.unmount();
    await flush();

    expect(media.deleted).toEqual(['https://cdn.test/items/1.jpg']);
    expect(controller.items).toHaveLength(0);
  });

  it('deleting an item also deletes its photo', async () => {
    const media = new FakeMediaStore();
    const mango: MerchantCatalogItem = {
      id: 'mango',
      storeId: 'grocery-1',
      vertical: 'grocery',
      name: 'Mango',
      description: null,
      priceCents: 120,
      isAvailable: true,
      imageUrl: 'https://cdn.test/items/mango.jpg',
      pricingUnit: 'each',
      availableQuantity: 5,
      categoryId: null,
      stockQuantity: null,
    };
    const controller = new MerchantCatalogController({
      repository: new FakeMerchantCatalogRepository({ initialItems: [mango] }),
      vertical: 'grocery',
      storeId: 'grocery-1',
    });
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
    await render(<CatalogScreen vertical="grocery" storeId="grocery-1" controller={controller} media={media} />);

    await fireEvent.press(await screen.findByRole('button', { name: 'Delete' }));
    const buttons = alertSpy.mock.calls[0][2] as AlertButton[];
    await act(async () => buttons.find((button) => button.text === 'Delete')?.onPress?.());
    await waitFor(() => expect(controller.items).toHaveLength(0));
    await flush();

    expect(media.deleted).toEqual(['https://cdn.test/items/mango.jpg']);
  });
});

describe('MerchantPhotoSession.save (RN-only)', () => {
  it('defers a discard that arrives mid-save until the save settles', async () => {
    const media = new FakeMediaStore();
    const session = new MerchantPhotoSession(media, null);
    const saved = await session.upload({ bytes: PHOTO_BYTES, contentType: 'image/png', folder: 'store' });

    const succeeded = await session.save(saved, async () => {
      session.discard(); // the form unmounted because the save succeeded
      return true;
    });
    await flush();

    expect(succeeded).toBe(true);
    expect(media.deleted).toEqual([]);
  });

  it('a failed save still honours a discard requested meanwhile', async () => {
    const media = new FakeMediaStore();
    const session = new MerchantPhotoSession(media, 'old.jpg');
    const upload = await session.upload({ bytes: PHOTO_BYTES, contentType: 'image/png', folder: 'items' });

    const succeeded = await session.save(upload, async () => {
      session.discard();
      return false;
    });
    await flush();

    expect(succeeded).toBe(false);
    expect(media.deleted).toEqual([upload]);
  });
});
