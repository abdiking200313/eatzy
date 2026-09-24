import 'package:chowflow/features/merchant/catalog/presentation/catalog_screen.dart';
import 'package:chowflow/features/merchant/catalog/presentation/merchant_catalog_controller.dart';
import 'package:chowflow/features/merchant/shared/merchant_media_store.dart';
import 'package:chowflow/features/merchant/shared/merchant_photo_field.dart';
import 'package:chowflow/features/merchant/store/models/merchant_store.dart';
import 'package:chowflow/features/merchant/store/models/merchant_vertical.dart';
import 'package:chowflow/features/merchant/store/presentation/merchant_store_controller.dart';
import 'package:chowflow/features/merchant/store/presentation/my_store_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_merchant_repositories.dart';

/// A valid 1x1 PNG so `Image.memory` can decode the upload preview.
final Uint8List _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeMediaStore implements MerchantMediaStore {
  final List<MerchantMediaFolder> uploadedTo = [];
  final List<String> deleted = [];

  @override
  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
    required MerchantMediaFolder folder,
  }) async {
    uploadedTo.add(folder);
    return 'https://cdn.test/${folder.pathSegment}/${uploadedTo.length}.jpg';
  }

  @override
  Future<void> deleteIfOwned(String url) async => deleted.add(url);
}

final List<MerchantMediaFolder> _pickedFor = [];

Future<PickedMerchantPhoto?> _fakePicker(
  BuildContext context,
  MerchantMediaFolder folder,
) async {
  _pickedFor.add(folder);
  return PickedMerchantPhoto(bytes: _onePixelPng, contentType: 'image/png');
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(_pickedFor.clear);

  test(
    'ownedPathFromUrl only accepts the user\'s own merchant_media files',
    () {
      const base =
          'https://abc.supabase.co/storage/v1/object/public/merchant_media';
      expect(
        SupabaseMerchantMediaStore.ownedPathFromUrl(
          '$base/u1/items/1.jpg',
          userId: 'u1',
        ),
        'u1/items/1.jpg',
      );
      expect(
        SupabaseMerchantMediaStore.ownedPathFromUrl(
          '$base/u2/items/1.jpg',
          userId: 'u1',
        ),
        isNull,
      );
      expect(
        SupabaseMerchantMediaStore.ownedPathFromUrl(
          'https://example.com/logo.png',
          userId: 'u1',
        ),
        isNull,
      );
    },
  );

  test('photo session deletes replaced and abandoned uploads only', () async {
    final media = _FakeMediaStore();
    final session = MerchantPhotoSession(media: media, savedUrl: 'old.jpg');
    final first = await session.upload(
      bytes: _onePixelPng,
      contentType: 'image/png',
      folder: MerchantMediaFolder.items,
    );
    final second = await session.upload(
      bytes: _onePixelPng,
      contentType: 'image/png',
      folder: MerchantMediaFolder.items,
    );

    session.commit(second);
    await Future<void>.delayed(Duration.zero);
    expect(media.deleted, unorderedEquals([first, 'old.jpg']));

    final abandoned = await session.upload(
      bytes: _onePixelPng,
      contentType: 'image/png',
      folder: MerchantMediaFolder.items,
    );
    session.discard();
    await Future<void>.delayed(Duration.zero);
    expect(media.deleted, contains(abandoned));
    expect(media.deleted, isNot(contains(second)));
  });

  testWidgets('a store photo is uploaded as a banner and saved on the store', (
    tester,
  ) async {
    _useTallSurface(tester);
    final media = _FakeMediaStore();
    const store = MerchantStore(
      id: 'grocery-1',
      vertical: MerchantVertical.grocery,
      name: 'Green Basket',
      location: 'Hodan',
      isOpen: true,
      imageUrl: 'https://cdn.test/store/old.jpg',
    );
    final controller = MerchantStoreController(
      repository: FakeMerchantStoreRepository(initialStore: store),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyStoreScreen(
            ownerId: 'merchant-1',
            controller: controller,
            media: media,
            photoPicker: _fakePicker,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(_pickedFor, [MerchantMediaFolder.store]);
    expect(MerchantMediaFolder.store.aspectX, 16);
    expect(controller.store!.imageUrl, 'https://cdn.test/store/1.jpg');
    expect(media.deleted, ['https://cdn.test/store/old.jpg']);
  });

  testWidgets('a grocery item can be added with an uploaded photo', (
    tester,
  ) async {
    _useTallSurface(tester);
    final media = _FakeMediaStore();
    final controller = MerchantCatalogController(
      repository: FakeMerchantCatalogRepository(),
      vertical: MerchantVertical.grocery,
      storeId: 'grocery-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CatalogScreen(
          vertical: MerchantVertical.grocery,
          storeId: 'grocery-1',
          storeName: 'Green Basket',
          controller: controller,
          media: media,
          photoPicker: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Mango');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price (per unit, USD)'),
      '1.20',
    );
    await tester.tap(find.text('Upload photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add item').last);
    await tester.pumpAndSettle();

    expect(_pickedFor, [MerchantMediaFolder.items]);
    expect(controller.items.single.imageUrl, 'https://cdn.test/items/1.jpg');
    expect(media.deleted, isEmpty);
  });
}
