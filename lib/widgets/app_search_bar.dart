import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The app's one search bar: a soft grey-filled, borderless pill used by
/// every customer-facing search (explore, food, grocery, pharmacy).
///
/// Two modes:
/// - **Editable** (pass [controller]): a real `TextField` with a clear
///   button that appears while there is text. [onChanged] fires on every
///   keystroke; [onClear] replaces the default clear behaviour (clearing
///   [controller] and reporting `''` through [onChanged]).
/// - **Tap-to-open** (pass [onTap], no [controller]): a read-only stand-in
///   that looks identical and navigates somewhere when tapped, e.g. the
///   home header opening Explore.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.onClear,
    this.onTap,
    this.backgroundColor = TwColors.searchFill,
  }) : assert(
         (controller == null) != (onTap == null),
         'Pass either controller (editable) or onTap (tap-to-open).',
       );

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onTap;

  /// Override only where the default grey would vanish into the background
  /// (e.g. on a coloured header).
  final Color backgroundColor;

  static const double height = 48;

  static const _hintStyle = TextStyle(color: TwColors.textMuted);

  void _clear() {
    if (onClear != null) {
      onClear!();
      return;
    }
    controller!.clear();
    onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TwRadius.input);
    return Material(
      color: backgroundColor,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(left: TwSpacing.x4),
            child: Row(
              children: [
                const Icon(Icons.search, size: 22, color: TwColors.textMuted),
                const SizedBox(width: TwSpacing.x3),
                Expanded(
                  child: controller == null
                      ? Text(
                          hintText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TwText.textBase.merge(_hintStyle),
                        )
                      : TextField(
                          controller: controller,
                          onChanged: onChanged,
                          textInputAction: TextInputAction.search,
                          style: TwText.textBase,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: hintText,
                            hintStyle: _hintStyle,
                          ),
                        ),
                ),
                if (controller == null)
                  const SizedBox(width: TwSpacing.x4)
                else
                  ListenableBuilder(
                    listenable: controller!,
                    builder: (context, _) => controller!.text.isEmpty
                        ? const SizedBox(width: TwSpacing.x4)
                        : SizedBox.square(
                            dimension: height,
                            child: IconButton(
                              tooltip: 'Clear',
                              onPressed: _clear,
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.clear,
                                size: 20,
                                color: TwColors.textMuted,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
