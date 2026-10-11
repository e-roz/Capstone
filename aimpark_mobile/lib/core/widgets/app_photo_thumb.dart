import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_skeleton.dart';

/// A photo from the network as a square thumbnail that opens full size.
///
/// Used wherever the app shows evidence it has already sent — an incident
/// report's photos, an appeal's. It handles the two ways such a photo goes wrong,
/// since both happen in practice: still loading (a skeleton) and gone or
/// unreachable (a quiet broken-image icon rather than Flutter's grey exception
/// box).
class AppPhotoThumb extends StatelessWidget {
  const AppPhotoThumb({
    super.key,
    required this.url,
    required this.index,
    required this.total,
    required this.size,
    required this.onTap,
  });

  final String url;

  /// Zero-based position among [total], for the spoken label.
  final int index;
  final int total;
  final double size;
  final VoidCallback onTap;

  /// A row's worth of square thumbnails: three to a line whatever the width, in
  /// the same gap the photo strip uses on the way in.
  static Widget grid({
    required List<String> urls,
    required ValueChanged<int> onTap,
  }) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = AppSpacing.sm;
        final size = (box.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < urls.length; i++)
              AppPhotoThumb(
                url: urls[i],
                index: i,
                total: urls.length,
                size: size,
                onTap: () => onTap(i),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      label: 'Photo ${index + 1} of $total. Tap to see it full size.',
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: t.surface.muted,
          borderRadius: AppRadius.mdAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const AppSkeleton.block(height: 120),
              errorBuilder: (_, _, _) => Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: t.text.secondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
