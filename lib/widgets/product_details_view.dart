import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'app_misc.dart';

/// The shared full-screen "more info" page for a single food, grocery, or
/// pharmacy item: photo hero, name, price, optional stock pill, description,
/// a quantity picker and Add to cart. The per-vertical screens
/// (`MenuItemDetailsScreen`, `GroceryProductDetailsScreen`,
/// `PharmacyProductDetailsScreen`) map their own model onto these fields.
/// It's pushed directly from the item row rather than being a go_router
/// route.
class ProductDetailsView extends StatefulWidget {
  const ProductDetailsView({
    super.key,
    required this.imageUrl,
    required this.fallback,
    required this.name,
    required this.priceLabel,
    this.stockLabel,
    this.isInStock = true,
    required this.description,
    required this.maxSteps,
    required this.quantityLabel,
    required this.onAddToCart,
    this.eyebrow,
    this.facts = const [],
    this.unavailableLabel = 'Out of stock',
  });

  final String? imageUrl;

  /// Shown in the hero when there's no photo (or it fails to load).
  final Widget fallback;

  final String name;
  final String priceLabel;

  /// The stock pill's label, e.g. "In stock" or "Only 2 left". Hidden entirely
  /// when null (food items have no stock concept).
  final String? stockLabel;
  final bool isInStock;
  final String description;

  /// Small label above the name, e.g. the pharmacy category.
  final String? eyebrow;

  /// Short extra lines, e.g. "Sold by weight, in 0.5 kg steps".
  final List<String> facts;

  /// How many quantity steps can still be added (stock minus what's already
  /// in the cart). Below 1, Add to cart is disabled with [unavailableLabel].
  final int maxSteps;

  /// Renders a step count for the picker, e.g. `3` or `1.5 kg`.
  final String Function(int steps) quantityLabel;

  /// Called with the chosen number of steps after this page has closed, so
  /// any follow-up dialog/snackbar shows on the product list underneath.
  final ValueChanged<int> onAddToCart;

  final String unavailableLabel;

  @override
  State<ProductDetailsView> createState() => _ProductDetailsViewState();
}

class _ProductDetailsViewState extends State<ProductDetailsView> {
  int _steps = 1;

  void _add() {
    final steps = _steps;
    Navigator.of(context).pop();
    widget.onAddToCart(steps);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final canAdd = widget.maxSteps >= 1;
    // Product photos are uploaded square, so a square-ish hero shows them
    // whole on phones while staying reasonable on wide screens.
    final heroHeight = MediaQuery.sizeOf(context).width.clamp(0.0, 360.0);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: heroHeight,
            backgroundColor: TwColors.card,
            foregroundColor: TwColors.text,
            flexibleSpace: FlexibleSpaceBar(
              background: _Hero(
                imageUrl: widget.imageUrl,
                fallback: widget.fallback,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.eyebrow != null) ...[
                    Text(widget.eyebrow!, style: TwText.link),
                    const SizedBox(height: TwSpacing.x2),
                  ],
                  Text(widget.name, style: TwText.text2xl),
                  const SizedBox(height: TwSpacing.x2),
                  Text(
                    widget.priceLabel,
                    style: TwText.fontBoldBase.copyWith(color: palette.accent),
                  ),
                  if (widget.stockLabel case final stockLabel?) ...[
                    const SizedBox(height: TwSpacing.x3),
                    StatusPill(
                      label: stockLabel,
                      backgroundColor: widget.isInStock
                          ? TwColors.tertiary.withOpacityValue(0.14)
                          : TwColors.errorSoft,
                      foregroundColor: widget.isInStock
                          ? const Color(0xFF0F7A54)
                          : TwColors.error,
                    ),
                  ],
                  if (widget.description.trim().isNotEmpty) ...[
                    const SizedBox(height: TwSpacing.x4),
                    Text(widget.description, style: TwText.textSm),
                  ],
                  for (final fact in widget.facts) ...[
                    const SizedBox(height: TwSpacing.x2),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: TwColors.textMuted,
                        ),
                        const SizedBox(width: TwSpacing.x2),
                        Expanded(
                          child: Text(
                            fact,
                            style: TwText.textSm.copyWith(
                              color: TwColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TwSpacing.x5,
            TwSpacing.x3,
            TwSpacing.x5,
            TwSpacing.x3,
          ),
          child: Row(
            children: [
              if (canAdd) ...[
                IconButton.outlined(
                  tooltip: 'Decrease quantity',
                  onPressed: _steps > 1 ? () => setState(() => _steps--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 64),
                  child: Text(
                    widget.quantityLabel(_steps),
                    textAlign: TextAlign.center,
                    style: TwText.fontBoldBase,
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Increase quantity',
                  onPressed: _steps < widget.maxSteps
                      ? () => setState(() => _steps++)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
                const SizedBox(width: TwSpacing.x3),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: canAdd ? _add : null,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text(canAdd ? 'Add to cart' : widget.unavailableLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.imageUrl, required this.fallback});

  final String? imageUrl;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    // Only the width is capped -- capping both dimensions squashes photos
    // that aren't exactly the hero's shape.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final cacheWidth = (MediaQuery.sizeOf(context).width * cacheScale).round();
    final placeholder = ColoredBox(
      color: TwColors.card,
      child: Center(child: fallback),
    );
    if (url.isEmpty) return placeholder;
    return ColoredBox(
      color: TwColors.card,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        placeholder: (_, _) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}
