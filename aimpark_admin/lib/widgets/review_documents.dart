import 'package:flutter/material.dart';

import '../models/registration_checks.dart';
import '../models/registration_detail.dart';
import '../theme/theme.dart';
import 'document_viewer.dart';
import 'ui/ui.dart';

/// One tab of the review screen's document viewer.
class ReviewDocumentTab {
  const ReviewDocumentTab({
    required this.type,
    required this.label,
    this.document,
    this.reading,
  });

  /// `Raf`, `SchoolId`, `License` or `OfficialReceipt`.
  final String type;
  final String label;

  /// Null when the applicant has not uploaded this one.
  final DocumentInfo? document;
  final DocumentReading? reading;

  /// The tabs for one application, in the order the applicant took them.
  ///
  /// Follows the affiliation, not the upload list: faculty and staff file a
  /// school ID, not a registration form, and a missing document still gets a
  /// tab so its absence is visible rather than silently skipped.
  static List<ReviewDocumentTab> forDetail(RegistrationDetail detail) {
    final identity = detail.affiliation == 'Student' ? 'Raf' : 'SchoolId';
    // An e-bike has no receipt, so no tab for one to be missing from.
    final expected = [identity, 'License', if (!detail.isEBike) 'OfficialReceipt'];
    final readings = detail.checks?.readings ?? const <DocumentReading>[];

    final types = <String>{
      ...expected,
      // Anything else on file — an older upload under the other identity
      // slot — is still evidence and still gets a tab.
      for (final d in detail.documents) d.type,
    }.toList();

    final tabs = <ReviewDocumentTab>[];
    for (final type in types) {
      final docs = detail.documents.where((d) => d.type == type).toList();
      final reads = readings.where((r) => r.document == type).toList();
      final count = docs.length > reads.length ? docs.length : reads.length;

      if (count == 0) {
        tabs.add(ReviewDocumentTab(type: type, label: documentLabel(type)));
        continue;
      }

      for (var i = 0; i < count; i++) {
        tabs.add(ReviewDocumentTab(
          type: type,
          label: count > 1
              ? '${documentLabel(type)} ${i + 1}'
              : documentLabel(type),
          document: i < docs.length ? docs[i] : null,
          reading: i < reads.length ? reads[i] : null,
        ));
      }
    }
    return tabs;
  }
}

/// The evidence, side by side with the findings: one document at a time, shown
/// inline, with what the phone read off it underneath.
///
/// It used to be a list of "View" buttons at the foot of the page, which made
/// comparing two documents a matter of opening and closing dialogs.
class ReviewDocuments extends StatelessWidget {
  const ReviewDocuments({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<ReviewDocumentTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tab = tabs[selected.clamp(0, tabs.length - 1)];

    return AppSectionCard(
      title: 'Documents',
      icon: Icons.folder_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              for (final (i, t) in tabs.indexed)
                ChoiceChip(
                  label: Text(t.label),
                  selected: i == selected,
                  showCheckmark: false,
                  onSelected: (_) => onSelect(i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          _Preview(tab: tab),
          const SizedBox(height: AppSpacing.x4),
          _Readings(tab: tab),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.tab});

  final ReviewDocumentTab tab;

  static const double _height = 360;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final doc = tab.document;

    Widget well(Widget child) => Container(
          height: _height,
          decoration: BoxDecoration(
            color: t.surface.muted,
            borderRadius: AppRadii.mdAll,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: child,
        );

    if (doc == null) {
      return well(Text(
        'Not uploaded.',
        style: text.bodyMedium?.copyWith(color: t.text.secondary),
      ));
    }

    void open() => viewDocument(
          context,
          title: tab.label,
          fileName: doc.fileName,
          url: doc.filePath,
        );

    if (!isImageDocument(doc.fileName)) {
      // Flutter Web has no reliable in-app PDF renderer; the browser does.
      return well(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.picture_as_pdf_outlined,
              size: AppSizes.iconLg, color: t.text.secondary),
          const SizedBox(height: AppSpacing.x2),
          Text(doc.fileName, style: text.bodySmall),
          const SizedBox(height: AppSpacing.x3),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: AppSizes.iconSm),
            label: const Text('Open in a new tab'),
            onPressed: open,
          ),
        ],
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: AppRadii.mdAll,
          child: Container(
            height: _height,
            color: t.surface.muted,
            child: MouseRegion(
              cursor: SystemMouseCursors.zoomIn,
              child: GestureDetector(
                onTap: open,
                child: Image.network(
                  doc.filePath,
                  key: ValueKey(doc.id),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, error, stack) => Center(
                    child: Text(
                      'Could not load the image.',
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ),
                  loadingBuilder: (ctx, child, progress) => progress == null
                      ? child
                      : const SkeletonBlock(height: _height),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          'Click the image to zoom.',
          style: text.labelSmall?.copyWith(color: t.text.tertiary),
        ),
      ],
    );
  }
}

class _Readings extends StatelessWidget {
  const _Readings({required this.tab});

  final ReviewDocumentTab tab;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final values = tab.reading?.values ?? const <ReadingValue>[];

    final body = tab.type == 'SchoolId'
        ? Text(
            'The phone does not read School IDs. Compare the image with the '
            'account yourself.',
            style: text.bodyMedium?.copyWith(color: t.text.secondary),
          )
        : values.isEmpty
            ? Text(
                'Nothing was read from this document.',
                style: text.bodyMedium?.copyWith(color: t.text.secondary),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final v in values) _ReadingRow(value: v),
                ],
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What the phone read', style: text.titleSmall),
        const SizedBox(height: AppSpacing.x2),
        body,
      ],
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.value});

  final ReadingValue value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final read = value.read;
    final submitted = value.submitted;

    // Where the value on file came from, as a tag: read and kept, changed
    // after reading, or typed with nothing read at all.
    final (tag, intent) = switch ((read, submitted)) {
      (_?, null) => ('Read', StatusIntent.info),
      (_?, _?) => ('Changed', StatusIntent.warning),
      (null, _?) => ('Typed', StatusIntent.warning),
      (null, null) => (null, StatusIntent.neutral),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border.subtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSizes.checkLabelWidth,
            child: Text(
              value.label,
              style: text.bodyMedium?.copyWith(color: t.text.secondary),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  read ?? 'Nothing read',
                  style: read == null
                      ? text.bodyMedium?.copyWith(color: t.text.tertiary)
                      : text.titleSmall?.copyWith(
                          // A reading the applicant overrode is struck through,
                          // so what is on file is the line below it.
                          decoration:
                              submitted == null ? null : TextDecoration.lineThrough,
                          color: submitted == null ? null : t.text.secondary,
                        ),
                ),
                if (submitted != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.subdirectory_arrow_right,
                            size: AppSizes.iconSm, color: t.status.warning.fg),
                        const SizedBox(width: AppSpacing.x1),
                        Flexible(
                          child: Text(
                            submitted,
                            style: text.titleSmall
                                ?.copyWith(color: t.status.warning.fg),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        Text(
                          'applicant',
                          style: text.bodyMedium
                              ?.copyWith(color: t.status.warning.fg),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (tag != null)
            StatusPill(label: tag, intent: intent, dense: true, showDot: false),
        ],
      ),
    );
  }
}
