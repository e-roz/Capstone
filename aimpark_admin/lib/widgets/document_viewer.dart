import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/responsive.dart';
import '../theme/theme.dart';

const _imageExtensions = ['.jpg', '.jpeg', '.png'];

/// Opens a document for review: images are previewed inline, PDFs open in a
/// new browser tab (Flutter Web has no reliable in-app PDF renderer, but
/// browsers already handle PDFs well natively).
Future<void> viewDocument(
  BuildContext context, {
  required String title,
  required String fileName,
  required String url,
}) async {
  final ext = fileName.toLowerCase();
  final isImage = _imageExtensions.any(ext.endsWith);

  if (isImage) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(title,
                          style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              color: ctx.tokens.text.primary))),
                  IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ctx.dialogWidth(600),
                  maxHeight: ctx.dialogHeight(600),
                ),
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, error, stack) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Failed to load image.'),
                    ),
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  final launched =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Could not open document.')));
  }
}
