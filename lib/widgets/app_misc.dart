import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

/// Shows a brief, floating confirmation snackbar for cart/quantity updates
/// (e.g. "added to cart", "quantity increased", "maximum reached") with a
/// consistent look, position, and duration across food, grocery, and
/// pharmacy. Kept short-lived and non-blocking so it reads as a quick
/// acknowledgement rather than a banner sitting over other bottom content
/// (a cart FAB, bottom nav, etc.) — Scaffold already lifts a floating
/// SnackBar above a visible FAB/bottom nav automatically, independent of
/// this margin, which only controls its inset within that slot.
///
/// Clears any snackbar already in flight first so rapid taps don't queue up
/// a backlog of stale confirmations.
void showCartSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TwText.textSm.copyWith(color: TwColors.white),
        ),
        backgroundColor: TwColors.slate900,
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
          TwSpacing.x4,
          0,
          TwSpacing.x4,
          TwSpacing.x4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwRadius.md),
        ),
      ),
    );
}

/// A circular avatar that loads an image from the network with a graceful
/// fallback while loading / on error.
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({super.key, required this.imageUrl, this.radius = 25});

  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // Decode at roughly the rendered diameter (radius * 2) scaled for
    // device pixel density, not at the source image's native resolution.
    // Capped at 3x since a wider cap buys no visible sharpness on a
    // circle this small while still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    // Only the width is capped: capping both dimensions decodes to that
    // exact box and squashes any photo that isn't already square. Doubled so
    // a wide photo still decodes tall enough to fill the circle sharply.
    final cacheWidth = (radius * 2 * 2 * cacheScale).round();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      memCacheWidth: cacheWidth,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(backgroundImage: imageProvider, radius: radius),
      placeholder: (context, url) => CircleAvatar(radius: radius),
      errorWidget: (context, url, error) => CircleAvatar(radius: radius),
    );
  }
}

/// The one place a per-service accent color is allowed to appear outside a
/// button: a fixed 48x48 rounded chip holding an icon, or its photo
/// counterpart [ServicePhotoChip]. Cards, list rows, and section headers
/// must stay on the neutral tokens and use one of these chips (with a
/// [ZivoServiceColors] accent, or an explicit override) instead of tinting
/// their own background/border.
class ServiceIconChip extends StatelessWidget {
  const ServiceIconChip({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
    this.borderRadius = TwRadius.lg,
    this.iconSize = 24,
  });

  static const double size = 48;

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? palette.accent,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, size: iconSize, color: foreground ?? palette.onAccent),
    );
  }
}

/// The photo counterpart of [ServiceIconChip]: same 48x48 circular slot, a
/// cropped photo instead of an icon, ringed in the per-service accent so it
/// reads as the same category-chip language.
class ServicePhotoChip extends StatelessWidget {
  const ServicePhotoChip({
    super.key,
    required this.imageUrl,
    this.ringColor,
    this.size = ServiceIconChip.size,
  });

  final String imageUrl;
  final Color? ringColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    const ringWidth = 2.0;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor ?? palette.accent,
          width: ringWidth,
        ),
      ),
      child: NetworkAvatar(
        imageUrl: imageUrl,
        radius: (size - ringWidth * 4) / 2,
      ),
    );
  }
}

/// A photo as a small rounded-square thumbnail: the store "logo" on the
/// food/grocery/pharmacy store-list rows, and the product photo on grocery
/// and pharmacy product rows. Shows [fallback] (typically a
/// [ServiceIconChip]) when there is no photo or it fails to load. Photos are
/// cover-cropped to the square, so a 16:9 store banner shows its centre.
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.size = 56,
  });

  final String? imageUrl;
  final Widget fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) return SizedBox.square(dimension: size, child: fallback);

    // Only the width is capped (capping both dimensions squashes the photo
    // into the box's shape). A 16:9 banner cover-cropped to a square needs
    // ~1.8x the box width in decoded pixels to stay sharp, hence the 2x.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(TwRadius.lg),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 2 * cacheScale).round(),
        placeholder: (_, _) => SizedBox.square(dimension: size),
        errorWidget: (_, _, _) =>
            SizedBox.square(dimension: size, child: fallback),
      ),
    );
  }
}

/// A small pill-shaped status indicator (e.g. "On the way", "Delivered").
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize = 12,
    this.icon,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? TwColors.primaryAccent;
    final fg = foregroundColor ?? TwColors.blue900;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x3,
        vertical: TwSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TwRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: fontSize + 2),
            const SizedBox(width: TwSpacing.x1),
          ],
          // Flexible + ellipsis lets the pill shrink gracefully instead of
          // overflowing when its parent gives it a tight width (e.g. a
          // narrow screen at a large text scale).
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TwText.textXs.copyWith(color: fg, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small label/value row used in order summary blocks.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    // The bold/total row intentionally uses the fixed platform primary
    // rather than `Theme.of(context).colorScheme.primary` — under a
    // `ZivoServiceTheme` that scheme slot resolves to the per-service
    // accent, which would break the "accent confined to the 48px icon
    // chip" redesign rule for every cart/checkout summary using this row.
    final labelStyle = isBold ? TwText.fontBoldBase : TwText.textSm;
    final valueStyle = isBold
        ? TwText.fontBoldBase.copyWith(color: TwColors.primary)
        : TwText.fontBoldSm;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: TwSpacing.x3),
        Text(value, style: valueStyle),
      ],
    );
  }
}
