import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_button.dart';
import 'app_card.dart';

/// PDFs attached to a form, to sit beside the photo strip.
///
/// Photos and PDFs travel together as evidence and share the server's limits —
/// five files in all, none over [maxFileBytes] — so the form passes in how many
/// more it can take ([max], the five less the photos already chosen) and this
/// refuses a file the server would refuse, naming the file instead of leaving the
/// upload to fail without saying which one.
class AppPdfAttachments extends StatefulWidget {
  const AppPdfAttachments({
    super.key,
    required this.paths,
    required this.onChanged,
    required this.max,
    this.enabled = true,
    this.maxFileBytes = 5 * 1024 * 1024,
  });

  final List<String> paths;
  final ValueChanged<List<String>> onChanged;

  /// The most PDFs that may be attached, given what else is already chosen.
  final int max;

  final bool enabled;
  final int maxFileBytes;

  @override
  State<AppPdfAttachments> createState() => _AppPdfAttachmentsState();
}

class _AppPdfAttachmentsState extends State<AppPdfAttachments> {
  String? _error;

  Future<void> _attach() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final bytes = await File(path).length();
    if (bytes > widget.maxFileBytes) {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
      final limit = (widget.maxFileBytes / (1024 * 1024)).round();
      if (mounted) {
        setState(() => _error = 'That PDF is $mb MB. Each file can be at '
            'most $limit MB.');
      }
      return;
    }

    setState(() => _error = null);
    widget.onChanged([...widget.paths, path]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final canAdd = widget.enabled && widget.paths.length < widget.max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final path in widget.paths) ...[
          _PdfRow(
            path: path,
            enabled: widget.enabled,
            onRemove: () {
              setState(() => _error = null);
              widget.onChanged([...widget.paths]..remove(path));
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: 'Attach a PDF',
          style: AppButtonStyle.ghost,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: canAdd ? _attach : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error!,
            style: context.text.bodySmall?.copyWith(color: t.status.danger.fg),
          ),
        ],
      ],
    );
  }
}

/// An attached PDF: its name, its size, and a way to take it off again.
class _PdfRow extends StatelessWidget {
  const _PdfRow({
    required this.path,
    required this.onRemove,
    required this.enabled,
  });

  final String path;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = path.split(RegExp(r'[\\/]')).last;
    final kb = File(path).lengthSync() / 1024;
    final size = kb >= 1024
        ? '${(kb / 1024).toStringAsFixed(1)} MB'
        : '${kb.round()} KB';

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            color: t.status.danger.fg,
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(size, style: context.text.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove $name',
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
