import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../platform/localization/app_money.dart';
import 'app_cards.dart';
import 'app_misc.dart';
import 'app_scaffold.dart';
import 'checkout_view.dart';

/// One row of a [CartView]. Amounts are integer cents.
class CartLine {
  const CartLine({
    required this.id,
    required this.name,
    required this.total,
    required this.quantityLabel,
    required this.onRemove,
    this.unitPrice,
    this.imageUrl,
    this.onDecrease,
    this.onIncrease,
  });

  /// Stable id, used in widget keys (`increase-cart-item-<id>`, ...).
  final String id;
  final String name;
  final int total;

  /// "2", or "1.5 kg" for weighed grocery products.
  final String quantityLabel;

  /// Shown as "$X each" when set.
  final int? unitPrice;
  final String? imageUrl;

  /// `null` disables the button (e.g. at the stock ceiling).
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback onRemove;
}

/// The cart screen shared by food, grocery (incl. Fresh Meat and
/// Electronics) and pharmacy: one card of lines with quantity steppers, a
/// totals card, and a sticky "Continue to checkout" button.
class CartView extends StatelessWidget {
  const CartView({
    super.key,
    required this.isEmpty,
    required this.emptyMessage,
    required this.browseLabel,
    required this.onBrowse,
    required this.lines,
    required this.feeLines,
    required this.total,
    required this.onCheckout,
    required this.fallbackIcon,
    this.title = 'Cart',
    this.showBackButton = true,
    this.isLoading = false,
    this.storeName,
    this.notice,
    this.onClear,
  });

  final String title;
  final bool showBackButton;
  final bool isLoading;
  final bool isEmpty;
  final String emptyMessage;
  final String browseLabel;
  final VoidCallback onBrowse;
  final List<CartLine> lines;

  /// Subtotal, tax, delivery fee — whatever this vertical charges.
  final List<CheckoutLine> feeLines;
  final int total;
  final VoidCallback onCheckout;

  /// Shown in a line's thumbnail when it has no photo.
  final IconData fallbackIcon;

  /// The store the whole cart belongs to, shown above the lines.
  final String? storeName;

  /// Optional one-line note under the store name (e.g. pharmacy's OTC note).
  final String? notice;

  /// When set, a "Clear" action (with a confirmation) empties the cart.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final showCart = !isLoading && !isEmpty;
    return AppScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: showCart && onClear != null
          ? [
              TextButton(
                onPressed: () => _confirmClear(context),
                child: const Text('Clear'),
              ),
              const SizedBox(width: TwSpacing.x2),
            ]
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
          ? CheckoutEmptyState(
              message: emptyMessage,
              browseLabel: browseLabel,
              onBrowse: onBrowse,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                TwSpacing.x5,
                TwSpacing.x2,
                TwSpacing.x5,
                TwSpacing.x8,
              ),
              children: [
                if (storeName case final name?) ...[
                  Text(name, style: TwText.textXl),
                  const SizedBox(height: TwSpacing.x1),
                ],
                if (notice case final text?) ...[
                  Text(text, style: TwText.textSm),
                  const SizedBox(height: TwSpacing.x1),
                ],
                const SizedBox(height: TwSpacing.x3),
                _CartLinesCard(lines: lines, fallbackIcon: fallbackIcon),
                const SizedBox(height: TwSpacing.x5),
                _CartTotalsCard(feeLines: feeLines, total: total),
              ],
            ),
      bottomNavigationBar: showCart
          ? SafeArea(
              minimum: const EdgeInsets.all(TwSpacing.x4),
              child: GradientActionButton(
                key: const Key('cart-checkout'),
                label: 'Continue to checkout • ${AppMoney.formatCents(total)}',
                onPressed: onCheckout,
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: TwColors.onPrimary,
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear your cart?'),
        content: const Text('This will remove every item from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear cart'),
          ),
        ],
      ),
    );
    if (shouldClear == true) {
      onClear?.call();
    }
  }
}

/// One card holding every cart line with internal dividers between rows,
/// per the redesign's "one card per list" rule — never a separate card per
/// line item.
class _CartLinesCard extends StatelessWidget {
  const _CartLinesCard({required this.lines, required this.fallbackIcon});

  final List<CartLine> lines;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Column(
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            _CartLineRow(line: lines[index], fallbackIcon: fallbackIcon),
            if (index != lines.length - 1) ...[
              const SizedBox(height: TwSpacing.rhythmDefault),
              const Divider(),
              const SizedBox(height: TwSpacing.rhythmDefault),
            ],
          ],
        ],
      ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({required this.line, required this.fallbackIcon});

  final CartLine line;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CartThumbnail(imageUrl: line.imageUrl, fallbackIcon: fallbackIcon),
        const SizedBox(width: TwSpacing.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TwText.fontBoldBase,
                    ),
                  ),
                  SizedBox.square(
                    dimension: 32,
                    child: IconButton(
                      key: ValueKey('remove-cart-item-${line.id}'),
                      tooltip: 'Remove ${line.name}',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: TwColors.textMuted,
                      ),
                      onPressed: line.onRemove,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TwSpacing.rhythmTight),
              Text(
                AppMoney.formatCents(line.total),
                style: TwText.fontBoldSm.copyWith(color: TwColors.primary),
              ),
              const SizedBox(height: TwSpacing.rhythmDefault),
              // A `Wrap` rather than a `Row` so the "$X each" note drops to
              // its own line instead of overflowing on a narrow screen with
              // enlarged text.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: TwSpacing.x3,
                runSpacing: TwSpacing.x1,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QuantityButton(
                        key: ValueKey('decrease-cart-item-${line.id}'),
                        tooltip: 'Decrease ${line.name}',
                        icon: Icons.remove_rounded,
                        onPressed: line.onDecrease,
                      ),
                      // Flexible so a long label ("1.5 kg" at a large text
                      // scale) wraps instead of overflowing the stepper.
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 40),
                          child: Text(
                            line.quantityLabel,
                            textAlign: TextAlign.center,
                            style: TwText.fontBoldSm,
                          ),
                        ),
                      ),
                      _QuantityButton(
                        key: ValueKey('increase-cart-item-${line.id}'),
                        tooltip: 'Increase ${line.name}',
                        icon: Icons.add_rounded,
                        onPressed: line.onIncrease,
                      ),
                    ],
                  ),
                  if (line.unitPrice case final unitPrice?)
                    Text(
                      '${AppMoney.formatCents(unitPrice)} each',
                      style: TwText.textXs.copyWith(color: TwColors.textMuted),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An 82×82 product photo, or a tinted [fallbackIcon] tile when there is no
/// photo (or it fails to load).
class CartThumbnail extends StatelessWidget {
  const CartThumbnail({super.key, this.imageUrl, required this.fallbackIcon});

  static const double size = 82;

  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: palette.soft,
      ),
      child: Icon(fallbackIcon, color: palette.accent, size: 32),
    );

    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) {
      return fallback;
    }

    // Decode at roughly the rendered box scaled for device pixel density,
    // not at the source image's native resolution. Capped at 3x since a
    // wider cap buys no visible sharpness on a thumbnail this small. Only
    // the width is capped (doubled, so a wide photo still decodes tall
    // enough to cover-crop sharply): capping both would squash non-square
    // photos.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        memCacheWidth: (size * 2 * cacheScale).round(),
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: IconButton.outlined(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _CartTotalsCard extends StatelessWidget {
  const _CartTotalsCard({required this.feeLines, required this.total});

  final List<CheckoutLine> feeLines;
  final int total;

  @override
  Widget build(BuildContext context) {
    // White card only — OutlinedCard's default fill/border are already the
    // neutral tokens.
    return OutlinedCard(
      child: Column(
        children: [
          for (final line in feeLines) ...[
            SummaryRow(
              label: line.label,
              value: AppMoney.formatCents(line.amount),
            ),
            const SizedBox(height: TwSpacing.x3),
          ],
          const Divider(),
          const SizedBox(height: TwSpacing.x3),
          SummaryRow(
            label: 'Total',
            value: AppMoney.formatCents(total),
            isBold: true,
          ),
        ],
      ),
    );
  }
}
