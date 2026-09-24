import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'merchant_media_store.dart';

/// A photo chosen (and, where supported, cropped) on-device, ready to upload.
class PickedMerchantPhoto {
  const PickedMerchantPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Picks a photo for [folder]; `null` when the merchant cancels.
typedef MerchantPhotoPicker =
    Future<PickedMerchantPhoto?> Function(
      BuildContext context,
      MerchantMediaFolder folder,
    );

/// Photo field for the merchant store and item forms: choose a photo from
/// the device (gallery on phones, a file picker on web/desktop), crop it to
/// the folder's shape where cropping is supported, upload it through
/// [session], and report the new URL through [onChanged].
class MerchantPhotoField extends StatefulWidget {
  const MerchantPhotoField({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.folder,
    required this.session,
    required this.onChanged,
    this.onUploadingChanged,
    this.picker,
  });

  final String label;
  final String? imageUrl;
  final MerchantMediaFolder folder;
  final MerchantPhotoSession session;

  /// Called with the uploaded URL, or `null` when the photo is removed.
  final ValueChanged<String?> onChanged;

  /// Called when an upload starts/finishes, so the form can hold off saving
  /// until the URL is known.
  final ValueChanged<bool>? onUploadingChanged;

  /// Overridable for tests; defaults to [pickAndCropMerchantPhoto].
  final MerchantPhotoPicker? picker;

  @override
  State<MerchantPhotoField> createState() => _MerchantPhotoFieldState();
}

class _MerchantPhotoFieldState extends State<MerchantPhotoField> {
  Uint8List? _pendingBytes;
  bool _isUploading = false;
  String? _error;

  Future<void> _chooseAndUpload() async {
    setState(() => _error = null);
    final PickedMerchantPhoto? picked;
    try {
      picked = await (widget.picker ?? pickAndCropMerchantPhoto)(
        context,
        widget.folder,
      );
    } catch (error, stackTrace) {
      debugPrint('MerchantPhotoField pick failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = 'Could not open your photos. Try again.');
      }
      return;
    }
    if (picked == null || !mounted) return;

    setState(() {
      _pendingBytes = picked!.bytes;
      _isUploading = true;
    });
    widget.onUploadingChanged?.call(true);
    try {
      final url = await widget.session.upload(
        bytes: picked.bytes,
        contentType: picked.contentType,
        folder: widget.folder,
      );
      widget.onChanged(url);
    } catch (error, stackTrace) {
      debugPrint('MerchantPhotoField upload failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _pendingBytes = null;
          _error = 'Upload failed. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
      widget.onUploadingChanged?.call(false);
    }
  }

  void _remove() {
    setState(() {
      _pendingBytes = null;
      _error = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = widget.imageUrl?.trim() ?? '';
    final hasPhoto = _pendingBytes != null || url.isNotEmpty;
    final folder = widget.folder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ConstrainedBox(
          // Keep the square item preview thumbnail-sized; let the store
          // banner use the full width.
          constraints: BoxConstraints(
            maxWidth: folder.aspectX == folder.aspectY ? 160 : double.infinity,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: folder.aspectX / folder.aspectY,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _preview(theme, url),
                  if (_isUploading)
                    const ColoredBox(
                      color: Colors.black38,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isUploading
                  ? null
                  : () => unawaited(_chooseAndUpload()),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(hasPhoto ? 'Change photo' : 'Upload photo'),
            ),
            if (hasPhoto)
              TextButton(
                onPressed: _isUploading ? null : _remove,
                child: const Text('Remove'),
              ),
          ],
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      ],
    );
  }

  Widget _preview(ThemeData theme, String url) {
    final pending = _pendingBytes;
    if (pending != null) return Image.memory(pending, fit: BoxFit.cover);
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _placeholder(theme, Icons.broken_image_outlined),
      );
    }
    return _placeholder(theme, Icons.add_photo_alternate_outlined);
  }

  Widget _placeholder(ThemeData theme, IconData icon) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(icon, size: 36, color: theme.disabledColor),
    );
  }
}

/// `image_cropper` only has Android, iOS and web implementations; on
/// desktop the picked photo is uploaded uncropped.
bool get _canCrop =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Default [MerchantPhotoPicker]: gallery (or file picker on web/desktop),
/// then a crop step locked to [folder]'s shape.
Future<PickedMerchantPhoto?> pickAndCropMerchantPhoto(
  BuildContext context,
  MerchantMediaFolder folder,
) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2000,
    maxHeight: 2000,
  );
  if (file == null) return null;

  if (!_canCrop || !context.mounted) {
    return PickedMerchantPhoto(
      bytes: await file.readAsBytes(),
      contentType: file.mimeType ?? _contentTypeFromName(file.name),
    );
  }

  final cropped = await ImageCropper().cropImage(
    sourcePath: file.path,
    aspectRatio: CropAspectRatio(
      ratioX: folder.aspectX.toDouble(),
      ratioY: folder.aspectY.toDouble(),
    ),
    maxWidth: folder == MerchantMediaFolder.store ? 1600 : 1000,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 85,
    uiSettings: [
      AndroidUiSettings(toolbarTitle: 'Crop photo', lockAspectRatio: true),
      IOSUiSettings(
        title: 'Crop photo',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
      ),
      WebUiSettings(context: context),
    ],
  );
  if (cropped == null) return null;
  return PickedMerchantPhoto(
    bytes: await cropped.readAsBytes(),
    contentType: 'image/jpeg',
  );
}

String _contentTypeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
