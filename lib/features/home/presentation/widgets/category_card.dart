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
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isSelected ? palette.soft : palette.card,
              borderRadius: BorderRadius.circular(TwRadius.xl),
              border: Border.all(
                color: isSelected ? palette.accent : palette.border,
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

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.fill,
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
