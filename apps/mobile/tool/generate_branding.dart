// Draws the app icon and splash images into assets/branding/:
//   dart run tool/generate_branding.dart
// then regenerate the platform files:
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
// The mark is three kanban columns of different heights in the brand dark
// (#14171F) on the brand orange (#FF7A45), a 6.9:1 contrast.
// A command-line tool, so printing is fine.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

final orange = img.ColorRgba8(0xFF, 0x7A, 0x45, 0xFF);
final dark = img.ColorRgba8(0x14, 0x17, 0x1F, 0xFF);
final white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 0xFF);

/// Drawn this many times larger, then averaged down: smooth edges.
const supersample = 4;

/// Column heights relative to the canvas, left to right.
const heights = [0.46, 0.30, 0.38];
const columnWidth = 0.14;
const gap = 0.07;

/// Draws the three columns, scaled by [scale] and centered on [canvas].
void drawMark(img.Image canvas, img.Color color, double scale) {
  final size = canvas.width;
  final width = (3 * columnWidth + 2 * gap) * scale;
  final height = heights.reduce(max) * scale;
  var left = (1 - width) / 2;
  final top = (1 - height) / 2;
  for (final h in heights) {
    img.fillRect(
      canvas,
      x1: (left * size).round(),
      y1: (top * size).round(),
      x2: ((left + columnWidth * scale) * size).round(),
      y2: ((top + h * scale) * size).round(),
      color: color,
      radius: 0.045 * scale * size,
    );
    left += (columnWidth + gap) * scale;
  }
}

img.Image canvas(int size, {img.Color? background, double cornerRadius = 0}) {
  final image = img.Image(
    width: size * supersample,
    height: size * supersample,
    numChannels: 4,
  );
  if (background != null) {
    img.fillRect(
      image,
      x1: 0,
      y1: 0,
      x2: image.width - 1,
      y2: image.height - 1,
      color: background,
      radius: cornerRadius * image.width,
    );
  }
  return image;
}

void save(String name, img.Image image, int size) {
  final file = File('assets/branding/$name')..createSync(recursive: true);
  final smooth = img.copyResize(
    image,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
  file.writeAsBytesSync(img.encodePng(smooth));
  print('wrote ${file.path}');
}

void main() {
  // iOS and legacy Android: full-bleed square, the OS rounds the corners.
  // No transparency (the App Store rejects it).
  final icon = canvas(1024, background: orange);
  drawMark(icon, dark, 1);
  save('icon.png', icon, 1024);

  // Android adaptive icon: flutter_launcher_icons insets this layer by
  // 16 %, which keeps the mark (53 dp across) inside the 66 dp safe circle
  // of the 108 dp canvas; the orange is the background layer.
  final foreground = canvas(1024);
  drawMark(foreground, dark, 1);
  save('icon_foreground.png', foreground, 1024);

  // Android 13 themed icons tint this silhouette.
  final monochrome = canvas(1024);
  drawMark(monochrome, white, 1);
  save('icon_monochrome.png', monochrome, 1024);

  // Splash logo (Android < 12, iOS): the rounded icon, 120 dp at 4x.
  final splash = canvas(480, background: orange, cornerRadius: 0.22);
  drawMark(splash, dark, 1);
  save('splash.png', splash, 480);

  // Android 12+ splash: the system draws the orange circle; the mark must
  // fit its inner two thirds.
  final android12 = canvas(1152);
  drawMark(android12, dark, 0.7);
  save('splash_android12.png', android12, 1152);
}
