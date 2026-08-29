// Regenerates the icon/splash source images under assets/icon/ from the
// same ZivoMarkPainter shape used in-app, so brand-mark and app-icon stay
// in sync. Run with `flutter test tool/generate_brand_assets.dart` after
// changing ZivoMarkPainter, then re-run:
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chowflow/widgets/zivo_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _capture(
  WidgetTester tester, {
  required String path,
  required double canvasSize,
  required double markSize,
  Color? backgroundColor,
}) async {
  final boundaryKey = GlobalKey();
  tester.view.physicalSize = Size(canvasSize, canvasSize);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: canvasSize,
          height: canvasSize,
          color: backgroundColor ?? Colors.transparent,
          alignment: Alignment.center,
          child: SizedBox(
            width: markSize,
            height: markSize,
            child: const CustomPaint(painter: ZivoMarkPainter()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path)..createSync(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('generate brand assets', (tester) async {
    // Base app icon (iOS/macOS/Windows/Linux/web): mark on white, no
    // safe-zone padding needed since these platforms don't crop to a mask.
    await _capture(
      tester,
      path: 'assets/icon/app_icon.png',
      canvasSize: 1024,
      markSize: 1024 * 0.72,
      backgroundColor: Colors.white,
    );

    // Android adaptive icon foreground layer: transparent background, mark
    // sized to fit Android's ~66% center safe zone so it isn't clipped by
    // the system mask shape.
    await _capture(
      tester,
      path: 'assets/icon/app_icon_foreground.png',
      canvasSize: 1024,
      markSize: 1024 * 0.5,
    );

    // Splash screen mark: transparent background, centered by
    // flutter_native_splash over the configured background color.
    await _capture(
      tester,
      path: 'assets/icon/splash_logo.png',
      canvasSize: 640,
      markSize: 640 * 0.6,
    );
  });
}
