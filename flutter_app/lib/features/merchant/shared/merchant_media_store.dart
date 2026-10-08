import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which of the merchant's media folders an upload belongs to. Also fixes
/// the crop shape: store photos are shown to customers as wide hero banners,
/// item photos as square thumbnails.
enum MerchantMediaFolder {
  store(pathSegment: 'store', aspectX: 16, aspectY: 9),
  items(pathSegment: 'items', aspectX: 1, aspectY: 1);

  const MerchantMediaFolder({
    required this.pathSegment,
    required this.aspectX,
    required this.aspectY,
  });

  final String pathSegment;
  final int aspectX;
  final int aspectY;
}

/// Uploads merchant photos and deletes ones that are no longer used.
abstract interface class MerchantMediaStore {
  /// Uploads [bytes] and returns the public URL to save on the row.
  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
    required MerchantMediaFolder folder,
  });

  /// Deletes the file behind [url] if it is one of the signed-in merchant's
  /// own uploads; any other URL (a legacy hosted link, someone else's file)
  /// is left alone.
  Future<void> deleteIfOwned(String url);
}

/// Stores photos in the `merchant_media` bucket under the signed-in user's
/// own folder -- the only place the storage policies in
/// `supabase/migrations/20260925000000_add_merchant_media_uploads.sql` let
/// a merchant write or delete.
class SupabaseMerchantMediaStore implements MerchantMediaStore {
  /// [client] defaults to `Supabase.instance.client`, resolved only when a
  /// photo is actually uploaded or deleted -- so screens can build one
  /// eagerly without touching Supabase (e.g. in widget tests).
  SupabaseMerchantMediaStore({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static const String bucket = 'merchant_media';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to manage photos.');
    return id;
  }

  @override
  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
    required MerchantMediaFolder folder,
  }) async {
    final path =
        '$_userId/${folder.pathSegment}/'
        '${DateTime.now().millisecondsSinceEpoch}.'
        '${_extensionFor(contentType)}';
    final storage = _client.storage.from(bucket);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    return storage.getPublicUrl(path);
  }

  @override
  Future<void> deleteIfOwned(String url) async {
    final path = ownedPathFromUrl(url, userId: _userId);
    if (path == null) return;
    await _client.storage.from(bucket).remove([path]);
  }

  /// The object path inside [bucket] for a public URL of one of [userId]'s
  /// own files, or `null` if [url] is anything else.
  @visibleForTesting
  static String? ownedPathFromUrl(String url, {required String userId}) {
    const marker = '/storage/v1/object/public/$bucket/';
    final index = url.indexOf(marker);
    if (index == -1) return null;
    final path = Uri.decodeComponent(
      url.substring(index + marker.length).split('?').first,
    );
    return path.startsWith('$userId/') ? path : null;
  }

  static String _extensionFor(String contentType) => switch (contentType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}

/// Tracks the photos uploaded while one store/item form is open, so files
/// that end up unused are deleted instead of piling up in storage:
///   * after a save, every upload except the saved one, plus the row's
///     previous photo if it was replaced or removed ([commit]);
///   * when the form closes without saving, every upload ([discard]).
/// Cleanup is best-effort -- a failed delete never blocks the merchant.
class MerchantPhotoSession {
  MerchantPhotoSession({required this.media, String? savedUrl})
    : _savedUrl = _blankToNull(savedUrl);

  final MerchantMediaStore media;
  String? _savedUrl;
  final Set<String> _uploads = {};

  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
    required MerchantMediaFolder folder,
  }) async {
    final url = await media.upload(
      bytes: bytes,
      contentType: contentType,
      folder: folder,
    );
    _uploads.add(url);
    return url;
  }

  /// The row was saved with [url] as its photo.
  void commit(String? url) {
    final saved = _blankToNull(url);
    final stale = {..._uploads, ?_savedUrl}..remove(saved);
    _uploads.clear();
    _savedUrl = saved;
    _deleteAll(stale);
  }

  /// The form closed without saving.
  void discard() {
    final stale = {..._uploads};
    _uploads.clear();
    _deleteAll(stale);
  }

  void _deleteAll(Iterable<String> urls) {
    for (final url in urls) {
      media.deleteIfOwned(url).catchError((Object error) {
        debugPrint('MerchantPhotoSession: could not delete $url: $error');
      });
    }
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
