import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

/// A standard [Scaffold] with the Zivo surface background, an
/// opinionated [AppBar] title, and an optional back button.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBackButton = false,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
  });

  final String title;
  final Widget body;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.bg,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        backgroundColor: TwColors.bg,
        elevation: 0,
        centerTitle: false,
        title: Text(title, style: TwText.text3xl()),
        foregroundColor: TwColors.text,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: TwColors.text),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
              )
            : null,
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// A small heading used to introduce a new section of content.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.color, this.fontSize});

  final String title;
  final Color? color;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TwText.textXl().copyWith(
        color: color ?? TwColors.text,
        fontSize: fontSize,
      ),
    );
  }
}
