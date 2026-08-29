import 'package:flutter/material.dart';
import '../config/theme.dart';

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
        hintStyle: TwText.textBase.copyWith(color: TwColors.textMuted),
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
      style: TwText.textBase,
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
