import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A neutral, white card used across screens ("white cards only" — never a
/// tinted/service-colored background; pass [backgroundColor]/[borderColor]
/// explicitly for the rare case a caller intentionally wants something
/// else, such as the 48px icon chip's own accent fill).
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TwSpacing.x5),
    this.borderRadius = TwRadius.lg,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius = BorderRadius.circular(borderRadius);
    final content = Padding(padding: padding, child: child);

    return Material(
      color: backgroundColor ?? TwColors.card,
      elevation: 0.6,
      shadowColor: TwColors.slate900.withOpacityValue(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: resolvedBorderRadius,
        side: BorderSide(
          color: borderColor ?? TwColors.border,
          width: borderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: resolvedBorderRadius,
              child: content,
            ),
    );
  }
}

/// A large, pill-shaped, gradient action button with optional icon and
/// label. Used for primary CTAs such as "Get Started" or "Checkout".
class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.padding = const EdgeInsets.symmetric(
      vertical: TwSpacing.x5,
      horizontal: TwSpacing.x5,
    ),
    this.borderRadius = 50,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool fullWidth;
  final EdgeInsets padding;
  final double borderRadius;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Container(
      width: fullWidth ? double.infinity : null,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacityValue(0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TwText.button.copyWith(
                color: scheme.onPrimary,
                fontSize: fontSize,
              ),
            ),
          ),
          if (icon != null) ...[const SizedBox(width: TwSpacing.x2), icon!],
        ],
      ),
    );

    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: button,
        ),
      ),
    );
  }
}

/// A rounded solid-color primary button (used for less prominent actions).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.foregroundColor = Colors.white,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  final Color? color;
  final Color foregroundColor;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? scheme.primary;
    final resolvedForeground = color == null
        ? scheme.onPrimary
        : foregroundColor;
    final button = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: TwSpacing.x5),
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(TwRadius.xl),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TwText.button.copyWith(color: resolvedForeground)),
          if (icon != null) ...[const SizedBox(width: TwSpacing.x2), icon!],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(TwRadius.lg),
        child: button,
      ),
    );
  }
}

/// A photo-header list card for a single store, used across verticals (food
/// restaurants, grocery stores, pharmacy stores) in mixed-vertical contexts:
/// the home screen's "Popular Stores" strip and the rebuilt Explore tab feed.
/// Distinct from the existing `RestaurantCard`/`GroceryStoreCard`, which stay
/// as-is for their own single-vertical screens.
class StoreListCard extends StatelessWidget {
  const StoreListCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    required this.accentColor,
    required this.onTap,
  });

  final String name;
  final String subtitle;

  /// Null/empty renders a "No picture available" placeholder rather than a
  /// generic icon substitute — an explicit product requirement, not a
  /// fallback to skip visually.
  final String? imageUrl;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: TwColors.card,
      borderRadius: TwRadius.xl,
      borderColor: TwColors.border,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(TwRadius.xl),
            ),
            child: _StoreListImage(
              imageUrl: imageUrl,
              accentColor: accentColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TwSpacing.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.fontBoldSm,
                ),
                const SizedBox(height: TwSpacing.rhythmTight),
                Row(
                  children: [
                    // The one accent touch this neutral white card allows —
                    // a small service-colored dot next to the subtitle,
                    // mirroring how the accent stays confined to a small
                    // element elsewhere (e.g. the 48px icon chip).
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: TwSpacing.x1),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TwText.textXs.copyWith(
                          color: TwColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreListImage extends StatelessWidget {
  const _StoreListImage({required this.imageUrl, required this.accentColor});

  static const double height = 110;

  final String? imageUrl;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) {
      return const _NoPicturePlaceholder();
    }

    // Decode at roughly the rendered width (this card's own width varies by
    // context — a fixed 150 in the home strip, full row width in the
    // Explore feed — so the device screen width is used as a practical
    // upper bound) scaled for device pixel density. Capped at 3x since a
    // wider cap buys no visible sharpness on a card image this small while
    // still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    // Only the width is capped: capping both dimensions decodes to that
    // exact box and squashes (stretches) any photo of a different shape.
    final cacheWidth = (MediaQuery.of(context).size.width * cacheScale).round();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        placeholder: (context, url) => ColoredBox(
          color: accentColor.withOpacityValue(0.08),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accentColor,
            ),
          ),
        ),
        errorWidget: (context, url, error) => const _NoPicturePlaceholder(),
      ),
    );
  }
}

/// The explicit "no photo" state for [StoreListCard] — a neutral gray box
/// with a broken-image icon and a small muted caption, never a generic
/// service icon standing in for a missing photo.
class _NoPicturePlaceholder extends StatelessWidget {
  const _NoPicturePlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _StoreListImage.height,
      width: double.infinity,
      child: ColoredBox(
        color: TwColors.stone100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                color: TwColors.textMuted,
                size: 28,
              ),
              const SizedBox(height: TwSpacing.rhythmTight),
              Text(
                'No picture available',
                style: TwText.textXs.copyWith(color: TwColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
