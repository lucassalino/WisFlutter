import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Cartão translúcido com borda subtil — replica `.dash-glass-card` /
/// `.events-dark-card` / `.auth-glass` do PWA (sem o custo de um blur
/// real, que a olho nu é indistinguível sobre um fundo já quase preto).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 18,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xD9161619), // rgba(22,22,26,0.85)
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: WisColors.cardBorder),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
