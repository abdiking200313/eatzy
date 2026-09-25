import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/service_module.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Services',
      showBackButton: showBackButton,
      // A true one-column list rather than a fixed-aspect-ratio grid, so
      // each card sizes to its own content instead of overflowing at
      // narrow widths / large text scales.
      body: ListView.separated(
        padding: const EdgeInsets.all(TwSpacing.x5),
        itemCount:
            ServiceRegistry.modules.length + ServiceRegistry.comingSoon.length,
        separatorBuilder: (_, _) => const SizedBox(height: TwSpacing.x5),
        itemBuilder: (context, index) {
          if (index >= ServiceRegistry.modules.length) {
            return _ComingSoonCard(
              category: ServiceRegistry
                  .comingSoon[index - ServiceRegistry.modules.length],
            );
          }
          final module = ServiceRegistry.modules[index];
          final colors = ServiceThemes.forSlug(module.slug, module.id);
          return _ServicePhotoCard(
            cardKey: Key('services-${module.slug}'),
            title: module.title,
            description: module.description,
            icon: module.icon,
            photoUrl: module.photoUrl,
            accentColor: colors.accent,
            // `go`, not `push`: module.entryRoute belongs to its own shell
            // branch (see app_router.dart), so this switches branches
            // within the persistent bottom-nav shell instead of stacking a
            // full-screen route over it and hiding the nav bar (#67).
            onTap: () => context.go(module.entryRoute),
          );
        },
      ),
    );
  }
}

/// A placeholder category with no service behind it yet: same photo-card
/// shape as a real module (see [_ServicePhotoCard]), just desaturated and
/// tapping it only shows a "coming soon" snackbar.
class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.category});

  final ComingSoonCategory category;

  @override
  Widget build(BuildContext context) {
    const platform = ZivoServiceColors.platform;
    return _ServicePhotoCard(
      cardKey: Key('services-coming-soon-${category.id}'),
      title: category.title,
      description: category.description,
      icon: category.icon,
      photoUrl: category.photoUrl,
      accentColor: platform.accent,
      comingSoon: true,
      onTap: () =>
          showCartSnackBar(context, '${category.title} is coming soon'),
    );
  }
}

/// A full-bleed photo card for a service/category: a real photo (when
/// [photoUrl] is set) or a locally-drawn accent-gradient placeholder with a
/// large low-opacity icon watermark (when it isn't — e.g. Grocery, Delivery,
/// Deals, Electronics have no real photo), with a bottom gradient scrim and
/// white title/description text on top. [comingSoon] desaturates the whole
/// card so it reads as disabled, matching the home grid's coming-soon tiles.
class _ServicePhotoCard extends StatelessWidget {
  const _ServicePhotoCard({
    required this.cardKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.photoUrl,
    required this.accentColor,
    required this.onTap,
    this.comingSoon = false,
  });

  final Key cardKey;
  final String title;
  final String description;
  final IconData icon;
  final String? photoUrl;
  final Color accentColor;
  final VoidCallback onTap;
  final bool comingSoon;

  // Standard luminance-weighted saturation-0 matrix, used to gray out the
  // whole card for a coming-soon category (mirrors the home grid's tiles).
  static const List<double> _grayscaleMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    final background = photoUrl != null && photoUrl!.isNotEmpty
        ? _ServicePhoto(imageUrl: photoUrl!, accentColor: accentColor)
        : _ServicePhotoPlaceholder(icon: icon, accentColor: accentColor);

    Widget content = SizedBox(
      key: cardKey,
      height: 148,
      child: Stack(
        fit: StackFit.expand,
        children: [
          background,
          // Bottom gradient scrim so white text stays legible over any
          // photo or placeholder.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
                stops: [0.4, 1],
              ),
            ),
          ),
          Positioned(
            left: TwSpacing.x4,
            right: TwSpacing.x4,
            bottom: TwSpacing.x4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.fontBoldBase.copyWith(color: TwColors.white),
                ),
                const SizedBox(height: TwSpacing.rhythmTight),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.textSm.copyWith(
                    color: TwColors.white.withOpacityValue(0.85),
                  ),
                ),
                if (comingSoon) ...[
                  const SizedBox(height: TwSpacing.rhythmTight),
                  const StatusPill(
                    label: 'Coming soon',
                    backgroundColor: TwColors.white,
                    foregroundColor: TwColors.slate700,
                    fontSize: 11,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (comingSoon) {
      content = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
        child: content,
      );
    }

    return OutlinedCard(
      padding: EdgeInsets.zero,
      borderRadius: TwRadius.xl,
      borderColor: comingSoon ? TwColors.stone300 : TwColors.border,
      onTap: onTap,
      child: content,
    );
  }
}

class _ServicePhoto extends StatelessWidget {
  const _ServicePhoto({required this.imageUrl, required this.accentColor});

  final String imageUrl;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final cacheWidth = (MediaQuery.of(context).size.width * cacheScale).round();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      placeholder: (context, url) =>
          ColoredBox(color: accentColor.withOpacityValue(0.12)),
      errorWidget: (context, url, error) => _ServicePhotoPlaceholder(
        // A generic icon on error — the caller's own [icon] isn't available
        // here, so this falls back to a neutral photo glyph rather than
        // threading another parameter through just for the rare error case.
        icon: Icons.storefront_outlined,
        accentColor: accentColor,
      ),
    );
  }
}

/// A locally-drawn placeholder background for a category with no real photo
/// yet: a soft gradient in the category's own accent color with a large,
/// low-opacity watermark of its icon behind where the title/description sit.
class _ServicePhotoPlaceholder extends StatelessWidget {
  const _ServicePhotoPlaceholder({
    required this.icon,
    required this.accentColor,
  });

  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacityValue(0.55),
            accentColor.withOpacityValue(0.85),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: TwSpacing.x2),
          child: Icon(
            icon,
            size: 120,
            color: TwColors.white.withOpacityValue(0.18),
          ),
        ),
      ),
    );
  }
}
