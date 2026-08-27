import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Circular avatar with an initials fallback — used in the dashboard header
/// and anywhere a profile photo may not be set yet.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
  });

  final String name;
  final String? imageUrl;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.brand.subtle,
        border: Border.all(color: t.brand.primary, width: 2),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl == null
          ? Text(
              _initials,
              style: context.text.labelLarge?.copyWith(
                color: t.brand.subtleText,
                fontSize: size * 0.35,
              ),
            )
          : null,
    );
  }
}
