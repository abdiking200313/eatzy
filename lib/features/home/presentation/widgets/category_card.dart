import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../models/category.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onPressed,
  });

  final Category category;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    // The base tile stays on the neutral white/border tokens (list-style
    // content, not the icon chip) — the per-service accent is only allowed
    // to appear here as a selection indicator (fill + border), the same
    // narrow, interactive-state exception used for selected nav items.
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isSelected ? palette.soft : TwColors.card,
              borderRadius: BorderRadius.circular(TwRadius.xl),
              border: Border.all(
                color: isSelected ? palette.accent : TwColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TwRadius.xl - 2),
              child: _CategoryImage(imageUrl: category.iconUrl),
            ),
          ),
        ),
        const SizedBox(height: TwSpacing.x2),
        Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TwText.textXs.copyWith(
            color: isSelected ? palette.accent : TwColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const _ImageFallback();
    }

    // Decode at roughly the rendered 90x90 box scaled for device pixel
    // density, not at the source image's native resolution. Capped at 3x
    // since a wider cap buys no visible sharpness on a chip this small
    // while still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final cacheSize = (90 * cacheScale).round();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.fill,
      memCacheWidth: cacheSize,
      memCacheHeight: cacheSize,
      placeholder: (context, url) => const _ImageLoading(),
      errorWidget: (context, url, error) => const _ImageFallback(),
    );
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.broken_image_outlined,
      size: 34,
      color: context.serviceColors.accent,
    );
  }
}
