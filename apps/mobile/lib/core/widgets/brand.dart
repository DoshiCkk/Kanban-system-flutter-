import 'package:flutter/material.dart';

/// The product name; a brand, so it is not translated.
const appName = 'FlowBoard';

/// The app icon (assets/branding/logo.png, drawn by
/// tool/generate_branding.dart): the same mark as the launcher icon and
/// the native splash.
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.size = 96, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/logo.png',
    width: size,
    height: size,
    semanticLabel: appName,
  );
}
