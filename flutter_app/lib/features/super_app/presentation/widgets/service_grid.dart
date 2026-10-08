import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/service_module.dart';
import '../../../../config/theme.dart';

/// Category section: a three-column grid of photo tiles, the live service
/// modules then a trailing "More" tile that opens the full Services list
/// (which is also where the coming-soon categories are listed).
class ServiceGrid extends StatelessWidget {
  const ServiceGrid({super.key, required this.modules, required this.onMore});

  final List<ServiceDescriptor> modules;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Without an explicit padding a vertical GridView adds the phone's
      // safe-area insets (status bar / home indicator) around itself.
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: TwSpacing.gridGap,
        mainAxisSpacing: TwSpacing.gridGap,
      ),
      itemBuilder: (context, index) {
        if (index < modules.length) {
          final module = modules[index];
          return _CategoryTile(
            tileKey: Key('service-${module.slug}'),
            icon: module.icon,
            photoUrl: module.photoUrl,
            label: module.title,
            // `go`, not `push`: module.entryRoute belongs to its own shell
            // branch (see app_router.dart), so this switches branches within
            // the persistent bottom-nav shell instead of stacking a
            // full-screen route over it and hiding the nav bar (issue #67).
            onTap: () => context.go(module.entryRoute),
          );
        }
        return _CategoryTile(
          tileKey: const Key('service-more'),
          icon: Icons.grid_view_rounded,
          label: 'More',
          onTap: onMore,
        );
      },
    );
  }
}

/// A square category tile: the service photo fills the whole tile with the
/// label bottom-left in white over a dark fade. Without a photo (or when it
/// fails to load) it falls back to a large icon on a light neutral tile.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.tileKey,
    required this.icon,
    this.photoUrl,
    required this.label,
    required this.onTap,
  });

  /// Applied to the tile's [Material], which tests inspect directly.
  final Key tileKey;
  final IconData icon;
  final String? photoUrl;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        key: tileKey,
        color: TwColors.stone100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwRadius.tile),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null)
              _IconTileContent(icon: icon, label: label)
            else
              _PhotoTileContent(imageUrl: url, icon: icon, label: label),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTileContent extends StatelessWidget {
  const _PhotoTileContent({
    required this.imageUrl,
    required this.icon,
    required this.label,
  });

  final String imageUrl;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The label and fade below are drawn whether or not the photo has
        // loaded, so a slow or failed load never leaves a blank tile.
        LayoutBuilder(
          builder: (context, constraints) {
            final dpr = MediaQuery.devicePixelRatioOf(context);
            return CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: (constraints.maxWidth * dpr).round(),
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => Align(
                alignment: const Alignment(0, -0.3),
                child: Icon(icon, size: 28, color: TwColors.slate700),
              ),
            );
          },
        ),
        // Darkens only the bottom of the photo so the white label stays
        // readable on any image.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.45, 1],
              colors: [
                TwColors.slate900.withOpacityValue(0),
                TwColors.slate900.withOpacityValue(0.65),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(TwSpacing.x2_5),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _TileLabel(label: label, color: TwColors.white),
          ),
        ),
      ],
    );
  }
}

class _IconTileContent extends StatelessWidget {
  const _IconTileContent({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TwSpacing.x2_5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: TwColors.slate700),
          const Spacer(),
          _TileLabel(label: label, color: TwColors.text),
        ],
      ),
    );
  }
}

class _TileLabel extends StatelessWidget {
  const _TileLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Shrinks a long label ("Electronics") on narrow tiles or at a large
    // text scale rather than ellipsizing or wrapping it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomLeft,
      child: Text(
        label,
        maxLines: 1,
        style: TwText.fontBoldSm.copyWith(fontSize: 14, color: color),
      ),
    );
  }
}
