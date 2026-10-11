import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/theme.dart';

/// A row of attached photos with an "add" tile at the end — up to [max], none
/// required.
///
/// Each photo is a square thumbnail with its own remove button; the add tile
/// goes away once the limit is reached. The count ("2 of 5") is always shown, so
/// nobody has to discover the limit by hitting it.
///
/// Photos are chosen from the gallery (several at once, up to the room left) or
/// taken with the camera, and are shrunk as they are picked — 1600px, 80%
/// quality. That is deliberate and not only for speed: the server refuses any
/// request over 10 MB in total, so five straight-from-the-camera photos could
/// fail the whole report.
///
/// Holds no state of its own. The caller owns [paths] and gets the new list
/// back through [onChanged].
class AppPhotoStrip extends StatelessWidget {
  const AppPhotoStrip({
    super.key,
    this.label,
    required this.paths,
    required this.onChanged,
    this.max = 5,
    this.enabled = true,
    this.errorText,
  });

  /// A heading above the strip. Null when the screen already has one — a form
  /// section header — in which case only the count is shown, and only once there
  /// is something to count.
  final String? label;
  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final int max;

  /// False while the form is being sent: nothing can be added or removed.
  final bool enabled;

  /// Shown under the strip, with an icon, when the photos are the problem.
  final String? errorText;

  static const double _gap = AppSpacing.sm;
  static const int _perRow = 3;

  Future<void> _showSourceSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final room = max - paths.length;
    final picker = ImagePicker();
    final picked = <String>[];

    if (source == ImageSource.gallery && room > 1) {
      final files = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1600,
        limit: room,
      );
      picked.addAll(files.map((f) => f.path));
    } else {
      final file = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (file != null) picked.add(file.path);
    }

    if (picked.isEmpty) return;
    onChanged([...paths, ...picked].take(max).toList());
  }

  void _remove(int index) {
    HapticFeedback.selectionClick();
    onChanged([...paths]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasError = errorText != null && errorText!.isNotEmpty;
    final canAdd = enabled && paths.length < max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || paths.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: label == null
                    ? const SizedBox.shrink()
                    : Text(label!, style: context.text.labelSmall),
              ),
              if (paths.isNotEmpty)
                Text(
                  '${paths.length} of $max',
                  style: AppTypography.tabular(context.text.labelLarge!)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        // Nothing attached yet: one short, wide bar rather than a lone square
        // tile, which was a hundred points of height spent on an optional extra.
        if (paths.isEmpty)
          _EmptyBar(
            max: max,
            onTap: canAdd ? () => _showSourceSheet(context) : null,
          )
        else
        LayoutBuilder(
          builder: (context, constraints) {
            // Three to a row, whatever the width, so the tiles stay square and
            // the fourth and fifth wrap onto a second line rather than shrinking.
            final size =
                (constraints.maxWidth - _gap * (_perRow - 1)) / _perRow;

            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (var i = 0; i < paths.length; i++)
                  _Thumb(
                    path: paths[i],
                    index: i,
                    size: size,
                    onRemove: enabled ? () => _remove(i) : null,
                  ),
                if (paths.length < max)
                  _AddTile(
                    size: size,
                    remaining: max - paths.length,
                    onTap: canAdd ? () => _showSourceSheet(context) : null,
                  ),
              ],
            );
          },
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: AppSizes.iconSm,
                  color: t.status.danger.fg,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: context.text.labelSmall
                      ?.copyWith(color: t.status.danger.fg),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The invitation to add photos, shown while there are none.
class _EmptyBar extends StatelessWidget {
  const _EmptyBar({required this.max, required this.onTap});

  final int max;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    final fg = enabled ? t.brand.subtleText : t.text.disabled;

    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: 'Add photos, up to $max',
      onTap: onTap,
      child: Material(
        color: enabled ? t.brand.subtle : t.surface.muted,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: t.border.control, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, size: AppSizes.iconLg, color: fg),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Flexible(
                    child: Text(
                      'Add photos',
                      style: context.text.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'up to $max',
                    style: context.text.bodySmall?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One attached photo, with a remove button in the corner.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.path,
    required this.index,
    required this.size,
    required this.onRemove,
  });

  final String path;
  final int index;
  final double size;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              image: true,
              label: 'Photo ${index + 1}',
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: t.surface.muted,
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: t.text.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (onRemove != null)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: Semantics(
                button: true,
                label: 'Remove photo ${index + 1}',
                excludeSemantics: true,
                onTap: onRemove,
                // The visible disc is 26dp; the tappable square around it is
                // 44dp, so a thumb that lands near it still removes the photo
                // and not the one beside it.
                child: InkResponse(
                  onTap: onRemove,
                  radius: 22,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: t.surface.inverse.withValues(alpha: 0.78),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: AppSizes.iconSm,
                          color: t.text.inverse,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The "add a photo" tile, shown while there is still room.
class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.size,
    required this.remaining,
    required this.onTap,
  });

  final double size;
  final int remaining;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    final fg = enabled ? t.brand.primary : t.text.disabled;

    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: 'Add photo, $remaining more allowed',
      onTap: onTap,
      child: Material(
        color: t.surface.card,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: t.border.control, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: SizedBox(
            width: size,
            height: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, size: AppSizes.iconLg, color: fg),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add photo',
                  style: context.text.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
