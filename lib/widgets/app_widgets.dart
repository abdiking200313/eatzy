import 'package:flutter/material.dart';
import '../config/theme.dart';

class FireSunGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isFullWidth;
  final Widget? icon;

  const FireSunGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isFullWidth = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x5,
          vertical: TwSpacing.x5,
        ),
        decoration: BoxDecoration(
          gradient: TwColors.primaryGradient,
          borderRadius: BorderRadius.circular(TwRadius.full),
          boxShadow: [
            BoxShadow(
              color: TwColors.primary.withOpacityValue(0.3),
              blurRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TwText.text2xl().copyWith(color: TwColors.onPrimary),
            ),
            if (icon != null) ...[const SizedBox(width: TwSpacing.x2), icon!],
          ],
        ),
      ),
    );
  }
}

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final bool useGlassmorphism;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TwSpacing.x5),
    this.borderRadius = TwRadius.lg,
    this.useGlassmorphism = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: useGlassmorphism
            ? TwColors.bg.withOpacityValue(0.7)
            : TwColors.cardMuted,
        border: useGlassmorphism
            ? Border.all(color: TwColors.text.withOpacityValue(0.1), width: 1)
            : null,
      ),
      child: child,
    );
  }
}

class ZivoChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const ZivoChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x5,
          vertical: TwSpacing.x2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? TwColors.primary : TwColors.secondarySoft,
          borderRadius: BorderRadius.circular(TwRadius.full),
        ),
        child: Text(
          label,
          style: TwText.fontBoldSm().copyWith(
            color: isSelected ? TwColors.onPrimary : TwColors.primary,
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatefulWidget {
  final String hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final bool obscureText;

  const AppTextField({
    super.key,
    required this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.obscureText = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TwText.textBase().copyWith(color: TwColors.textMuted),
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: TwColors.textMuted)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwRadius.lg),
          borderSide: const BorderSide(color: TwColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwRadius.lg),
          borderSide: const BorderSide(color: TwColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwRadius.lg),
          borderSide: const BorderSide(color: TwColors.primary, width: 2),
        ),
        filled: true,
        fillColor: TwColors.cardMuted,
      ),
      style: TwText.textBase(),
    );
  }
}

class GlassmorphContainer extends StatelessWidget {
  final Widget child;
  final double blurAmount;
  final EdgeInsets padding;

  const GlassmorphContainer({
    super.key,
    required this.child,
    this.blurAmount = 20.0,
    this.padding = const EdgeInsets.all(TwSpacing.x5),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: TwColors.bg.withOpacityValue(0.7),
        borderRadius: BorderRadius.circular(TwRadius.lg),
        border: Border.all(
          color: TwColors.text.withOpacityValue(0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
