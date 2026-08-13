import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ocr/document_scanner.dart';
import '../../../../core/ocr/ocr_payload.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_flushbar.dart';
import 'document_capture_screen.dart';

/// Capture a document and see exactly what recognition returned.
///
/// Not user-facing — reached only by typing the route. It exists to collect
/// payloads from real forms: the extraction rules are calibrated against a
/// single RAF, and the only way to widen that is to photograph more of them and
/// copy the JSON out. Feeding that JSON back into the server's tests is far
/// faster than re-photographing a document every time a rule changes.
class OcrDebugScreen extends StatefulWidget {
  const OcrDebugScreen({super.key});

  @override
  State<OcrDebugScreen> createState() => _OcrDebugScreenState();
}

class _OcrDebugScreenState extends State<OcrDebugScreen> {
  static const _specs = [
    DocumentSpec.raf,
    DocumentSpec.schoolId,
    DocumentSpec.license,
    DocumentSpec.officialReceipt,
    DocumentSpec.platePhoto,
  ];

  final DocumentScanner _scanner = DocumentScanner();

  DocumentSpec _spec = DocumentSpec.raf;
  CapturedDocument? _result;
  Duration? _elapsed;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final started = DateTime.now();
    final result = await Navigator.of(context).push<CapturedDocument>(
      MaterialPageRoute(
        builder: (_) => DocumentCaptureScreen(spec: _spec, scanner: _scanner),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _result = result;
      _elapsed = DateTime.now().difference(started);
    });
  }

  Future<void> _copyJson() async {
    final payload = _result?.payload;
    if (payload == null) return;

    await Clipboard.setData(ClipboardData(text: payload.toJsonString()));
    if (mounted) showAppMessage(context, 'Payload copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final payload = _result?.payload;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('OCR debug')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          DropdownButtonFormField<DocumentSpec>(
            initialValue: _spec,
            decoration: const InputDecoration(labelText: 'Document type'),
            items: [
              for (final spec in _specs)
                DropdownMenuItem(value: spec, child: Text(spec.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _spec = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _capture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture'),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_result == null)
            Text(
              'Capture a document to see its payload.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else if (payload == null)
            Text(
              'Recognition failed. The photo would still be submitted, with no '
              'values prefilled.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.errorDefault,
              ),
            )
          else ...[
            _Summary(payload: payload, elapsed: _elapsed),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _copyJson,
              icon: const Icon(Icons.copy),
              label: const Text('Copy payload JSON'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Lines, in the order sent', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            for (final line in payload.lines) _LineRow(line: line),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.payload, required this.elapsed});

  final OcrPayload payload;
  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    final confidences = payload.lines.map((l) => l.confidence);
    final average = confidences.isEmpty
        ? 0.0
        : confidences.reduce((a, b) => a + b) / payload.lines.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Image', '${payload.imageWidth} × ${payload.imageHeight}'),
          _row('Lines', '${payload.lines.length}'),
          _row('Mean confidence', average.toStringAsFixed(2)),
          if (elapsed != null)
            _row('Capture to result', '${elapsed!.inMilliseconds} ms'),
          if (!payload.boxesFitImage)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Boxes fall outside the image bounds — the photo and the boxes '
                'disagree about orientation. Every anchor rule will miss until '
                'this is resolved.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.errorDefault,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final OcrLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.text, style: AppTextStyles.bodyMedium),
          Text(
            'x=${line.x} y=${line.y} w=${line.width} h=${line.height} '
            'conf=${line.confidence.toStringAsFixed(2)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
