import 'package:flutter/material.dart';

import '../config/theme.dart';

class ZivoBrand {
  const ZivoBrand._();

  static const String name = 'Zivo';
}

class ZivoLogo extends StatelessWidget {
  const ZivoLogo({
    super.key,
    this.height = 38,
    this.showWordmark = true,
    this.wordmarkColor = TwColors.text,
  });

  final double height;
  final bool showWordmark;
  final Color wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final markSize = height;
    return Semantics(
      image: true,
      label: ZivoBrand.name,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(markSize, markSize),
            painter: const ZivoMarkPainter(),
          ),
          if (showWordmark) ...[
            SizedBox(height: height * 0.06),
            Text(
              'zivo',
              style: TwText.text2xl.copyWith(
                color: wordmarkColor,
                fontSize: height * 0.42,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints the Zivo brand mark: a gradient "Z" glyph.
///
/// Public so it can be reused outside [ZivoLogo], e.g. by
/// `tool/generate_brand_assets.dart` to rasterize app icon and splash
/// screen source images from the same shape used in-app.
class ZivoMarkPainter extends CustomPainter {
  const ZivoMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [TwColors.blue400, TwColors.blue700],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.13)
      ..quadraticBezierTo(
        size.width * 0.20,
        size.height * 0.05,
        size.width * 0.30,
        size.height * 0.05,
      )
      ..lineTo(size.width * 0.79, size.height * 0.05)
      ..quadraticBezierTo(
        size.width * 0.94,
        size.height * 0.05,
        size.width * 0.94,
        size.height * 0.20,
      )
      ..quadraticBezierTo(
        size.width * 0.94,
        size.height * 0.28,
        size.width * 0.86,
        size.height * 0.34,
      )
      ..lineTo(size.width * 0.34, size.height * 0.72)
      ..lineTo(size.width * 0.80, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.91,
        size.height * 0.72,
        size.width * 0.86,
        size.height * 0.82,
      )
      ..lineTo(size.width * 0.81, size.height * 0.91)
      ..lineTo(size.width * 0.29, size.height * 0.91)
      ..quadraticBezierTo(
        size.width * 0.08,
        size.height * 0.91,
        size.width * 0.08,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.08,
        size.height * 0.61,
        size.width * 0.19,
        size.height * 0.53,
      )
      ..lineTo(size.width * 0.68, size.height * 0.18)
      ..lineTo(size.width * 0.20, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.14,
        size.height * 0.18,
        size.width * 0.18,
        size.height * 0.13,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
