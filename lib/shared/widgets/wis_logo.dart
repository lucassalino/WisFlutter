import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';

/// O "adorador" — símbolo da marca WIS sobre o degradê navy/petróleo.
class WisLogo extends StatelessWidget {
  const WisLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.22),
      decoration: const BoxDecoration(
        gradient: WisColors.gradient,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset('assets/brand/wis-symbol-white.svg'),
    );
  }
}
