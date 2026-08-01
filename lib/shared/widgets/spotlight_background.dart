import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Fundo preto absoluto com um brilho radial subtil no canto superior
/// direito — replica `.auth-bg` / `.dash-purple-bg` do PWA.
class SpotlightBackground extends StatelessWidget {
  const SpotlightBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WisColors.background,
        gradient: WisColors.spotlight,
      ),
      child: child,
    );
  }
}
