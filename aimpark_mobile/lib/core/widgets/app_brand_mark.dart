import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The app's mark: a solid circle carrying a single glyph.
///
/// Replaces the previous identity's illustrated owl mascot on the splash
/// screen and the auth/registration headers — the reference's register is
/// flat and iconographic, not an illustrated character, so a small glyph
/// mark fits where a mascot no longer does.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 64, this.color, this.iconColor});

  final double size;

  /// Defaults to `t.brand.primary`. Pass [AppFixedColors]-derived white for
  /// use on the indigo splash canvas, where the token would be invisible.
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? t.brand.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.local_parking_rounded,
        color: iconColor ?? t.brand.onSolid,
        size: size * 0.56,
      ),
    );
  }
}
