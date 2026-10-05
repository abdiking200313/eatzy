import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../config/theme.dart';

/// Fixed height of the photo hero atop a single store/restaurant screen —
/// shared by `RestaurantScreen`, `GroceryStoreScreen`, and
/// `PharmacyCatalogScreen` so the three read as visually consistent
/// (issue #250).
const double kStoreHeroAppBarHeight = 230;

/// The pinned, photo-hero `SliverAppBar` at the top of a single
/// store/restaurant screen: an accent-colored bar with the store's name, a
/// full-bleed photo (or a fallback icon tile when there's none/it fails to
/// load) darkened by a gradient so the title stays legible, and optional
/// trailing [actions] (e.g. the cart badge). Shared by `RestaurantScreen`,
/// `GroceryStoreScreen`, and `PharmacyCatalogScreen`.
class StoreHeroAppBar extends StatelessWidget {
  const StoreHeroAppBar({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.fallbackIcon,
    this.imageFit = BoxFit.cover,
    this.actions,
    this.showBackButton = false,
  });

  final String title;
  final String? imageUrl;

  /// Shown in a plain tile when there's no photo (or it fails to load).
  final IconData fallbackIcon;

  /// Food's restaurant logo is letterboxed (`BoxFit.contain`) rather than
  /// cropped, unlike grocery's/pharmacy's store photos (`BoxFit.cover`).
  final BoxFit imageFit;

  final List<Widget>? actions;

  /// Adds an explicit back button that falls back to the main app shell
  /// when there's nothing to pop (e.g. a bare deep link straight to this
  /// screen). `RestaurantScreen` leaves this false and relies on the
  /// default automatic back button instead.
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return SliverAppBar(
      pinned: true,
      expandedHeight: kStoreHeroAppBarHeight,
      backgroundColor: palette.accent,
      foregroundColor: palette.onAccent,
      leading: showBackButton
          ? IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.mainApp);
                }
              },
            )
          : null,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TwText.fontBoldBase.copyWith(color: palette.onAccent),
      ),
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        background: _StoreHero(
          imageUrl: imageUrl ?? '',
          fallbackIcon: fallbackIcon,
          fit: imageFit,
        ),
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({
    required this.imageUrl,
    required this.fallbackIcon,
    required this.fit,
  });

  final String imageUrl;
  final IconData fallbackIcon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    // The hero fills the SliverAppBar's expandedHeight at full screen
    // width; there's no fixed logical width available here, so the screen
    // width is used as the practical upper bound for the decoded width. It
    // is scaled for device pixel density and capped at 3x since a wider cap
    // buys no visible sharpness while still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    // Only the width is capped: capping both dimensions decodes to that
    // exact box and squashes (stretches) any photo of a different shape.
    final cacheWidth = (MediaQuery.of(context).size.width * cacheScale).round();
    final image = trimmedUrl.isEmpty
        ? _StoreHeroFallback(icon: fallbackIcon)
        : CachedNetworkImage(
            imageUrl: trimmedUrl,
            fit: fit,
            alignment: Alignment.center,
            memCacheWidth: cacheWidth,
            placeholder: (_, _) =>
                _StoreHeroFallback(icon: fallbackIcon, showLoader: true),
            errorWidget: (_, _, _) => _StoreHeroFallback(icon: fallbackIcon),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        // A plain white base under the photo: a logo/photo with transparent
        // pixels (common for uploaded restaurant/store logos) would
        // otherwise reveal whatever sits behind this in the widget tree —
        // the app bar's own accent color — which would read as a stray
        // color bleed-through around/through the image rather than a clean
        // background.
        const ColoredBox(color: TwColors.card),
        image,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                TwColors.slate900.withOpacityValue(85 / 255),
                TwColors.slate900.withOpacityValue(34 / 255),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreHeroFallback extends StatelessWidget {
  const _StoreHeroFallback({required this.icon, this.showLoader = false});

  final IconData icon;
  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return ColoredBox(
      color: TwColors.card,
      child: Center(
        child: showLoader
            ? CircularProgressIndicator(color: palette.accent)
            : Icon(icon, color: palette.accent, size: 72),
      ),
    );
  }
}
