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
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x5,
          vertical: TwSpacing.x5,
        ),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(TwRadius.xl),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacityValue(0.18),
              blurRadius: 12,
              offset: const Offset(0, 5),
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
    final palette = context.serviceColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: useGlassmorphism
            ? TwColors.bg.withOpacityValue(0.7)
            : palette.card,
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
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x5,
          vertical: TwSpacing.x2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(TwRadius.full),
        ),
        child: Text(
          label,
          style: TwText.fontBoldSm().copyWith(
            color: isSelected ? scheme.onPrimary : scheme.primary,
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatefulWidget {
  final String hint;
  final String? label;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  const AppTextField({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.obscureText = false,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _obscureText = widget.obscureText;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      focusNode: _focusNode,
      obscureText: _obscureText,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        hintStyle: TwText.textBase().copyWith(color: TwColors.textMuted),
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: scheme.primary)
            : null,
        suffixIcon: widget.obscureText
            ? IconButton(
                tooltip: _obscureText ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureText = !_obscureText),
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: TwColors.textMuted,
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x4,
          vertical: TwSpacing.x5,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwRadius.xl),
          borderSide: const BorderSide(color: TwColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwRadius.xl),
          borderSide: const BorderSide(color: TwColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwRadius.xl),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: TwColors.white,
      ),
      style: TwText.textBase(),
    );
  }
}

class AuthPageBackground extends StatelessWidget {
  const AuthPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height,
        ),
        child: child,
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TwSpacing.x6),
      decoration: BoxDecoration(
        color: TwColors.white,
        borderRadius: BorderRadius.circular(TwRadius.xl),
        border: Border.all(color: TwColors.border),
        boxShadow: [
          BoxShadow(
            color: TwColors.slate900.withOpacityValue(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
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
