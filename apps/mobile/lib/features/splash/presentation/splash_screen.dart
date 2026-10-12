import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/widgets/brand.dart';
import 'package:flutter/material.dart';

/// Logo and name while the app starts. Continues the native splash (same
/// background and mark), then hands over to sign-in or the home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({this.failed = false, super.key});

  /// Start-up failed: say so instead of spinning forever.
  final bool failed;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else if (_intro.isDismissed) {
      _intro.forward().ignore();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final curve = CurvedAnimation(parent: _intro, curve: Curves.easeOutBack);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(curve),
              child: const BrandLogo(size: 120),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _intro,
              child: Text(
                appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _intro,
              child: Text(
                l10n.splashTagline,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (widget.failed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  l10n.splashFailed,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              )
            else
              Semantics(
                label: l10n.commonLoading,
                child: const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
