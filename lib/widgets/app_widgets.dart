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
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.fireSunGradient,
          borderRadius: BorderRadius.circular(AppRadii.full),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacityValue(0.3),
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
              style: AppTextStyles.h3().copyWith(
                color: AppColors.onPrimary,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: AppSpacing.base),
              icon!,
            ],
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
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppRadii.lg,
    this.useGlassmorphism = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: useGlassmorphism
            ? AppColors.surface.withOpacityValue(0.7)
            : AppColors.surfaceContainer,
        border: useGlassmorphism
            ? Border.all(
                color: AppColors.onSurface.withOpacityValue(0.1),
                width: 1,
              )
            : null,
      ),
      child: child,
    );
  }
}

class ChowFlowChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const ChowFlowChip({
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
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.secondaryFixed,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelBold().copyWith(
            color: isSelected
                ? AppColors.onPrimary
                : AppColors.primary,
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
        hintStyle: AppTextStyles.bodyMd().copyWith(
          color: AppColors.outline,
        ),
        prefixIcon: widget.prefixIcon != null
            ? Icon(
                widget.prefixIcon,
                color: AppColors.outline,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
      ),
      style: AppTextStyles.bodyMd(),
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
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacityValue(0.7),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: AppColors.onSurface.withOpacityValue(0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
