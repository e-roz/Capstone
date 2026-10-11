import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A set of photos, one at a time and full screen — a report's evidence, an
/// appeal's supporting photos.
///
/// Swipe between them, pinch to zoom, tap the cross to go back. The thumbnails on
/// the report are far too small to tell whether a photo shows what it was meant
/// to — and it is the evidence the whole report may turn on.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  /// Already resolved to full addresses.
  final List<String> urls;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      // The near-black of the theme rather than a hard black, and its matching
      // text colour: this is the one screen that is dark by design.
      backgroundColor: t.surface.inverse,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Semantics(
                  image: true,
                  label: 'Photo ${i + 1} of ${widget.urls.length}',
                  child: Image.network(
                    widget.urls[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) => progress ==
                            null
                        ? child
                        : Center(
                            child: CircularProgressIndicator(
                              color: t.text.inverse,
                            ),
                          ),
                    errorBuilder: (_, _, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            size: AppSizes.iconHero, color: t.text.inverse),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          "This photo can't be opened right now.",
                          style: context.text.bodyMedium
                              ?.copyWith(color: t.text.inverse),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: t.text.inverse),
                  ),
                  const Spacer(),
                  if (widget.urls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: t.text.inverse.withValues(alpha: 0.16),
                        borderRadius: AppRadius.fullAll,
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.urls.length}',
                        style: AppTypography.tabular(context.text.labelLarge!)
                            .copyWith(color: t.text.inverse),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
