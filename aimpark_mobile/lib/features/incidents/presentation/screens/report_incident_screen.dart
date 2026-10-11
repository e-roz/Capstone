import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../incident_categories.dart';
import '../providers/incidents_provider.dart';

class ReportIncidentScreen extends ConsumerStatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  ConsumerState<ReportIncidentScreen> createState() =>
      _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  /// How much a person can write. The server sets no limit, so this is the app's
  /// own, and a generous one: enough for a paragraph, short enough that a report
  /// stays a report and not an essay.
  static const _maxDescription = 500;

  /// The most the photos may weigh together. The server refuses any request over
  /// 10 MB in total, form fields included, so this stops a little short of it.
  static const _maxPhotoBytes = 9 * 1024 * 1024;

  final _description = TextEditingController();
  final _location = TextEditingController();

  /// Nothing is chosen until the user chooses. It defaulted to the first chip,
  /// which is "Vandalism" — a serious accusation the form was making on their
  /// behalf, and one a hurried report would send unread.
  String? _category;
  List<String> _photos = const [];
  List<String> _pdfs = const [];
  bool _isSubmitting = false;

  /// The server takes five evidence files in all, photos and PDFs together.
  static const int _maxFiles = 5;

  // Each problem is shown on the thing it is about, and cleared the moment the
  // person fixes it. These used to be a message that floated over the form and
  // disappeared before it could be acted on.
  String? _categoryError;
  String? _descriptionError;
  String? _photosError;

  @override
  void dispose() {
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final category = _category;
    final description = _description.text.trim();

    setState(() {
      _categoryError =
          category == null ? 'Pick what kind of incident it was.' : null;
      _descriptionError = description.isEmpty ? 'Tell us what happened.' : null;
    });
    if (category == null || description.isEmpty) return;

    // Checked here, with the numbers, because the alternative is the server
    // refusing the whole upload and the person learning of it from an error that
    // does not say which photo to drop.
    final files = [..._photos, ..._pdfs];
    final sizes = await Future.wait(files.map((p) => File(p).length()));
    final totalBytes = sizes.fold<int>(0, (sum, b) => sum + b);
    if (totalBytes > _maxPhotoBytes) {
      final mb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      if (mounted) {
        setState(() {
          _photosError = 'Your files add up to $mb MB, and the limit is 9 MB '
              'together. Remove one or two.';
        });
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final id = await ref.read(incidentsRepositoryProvider).create(
            category: category,
            description: description,
            location: _location.text.trim(),
            evidencePaths: files,
          );
      ref.invalidate(incidentsNotifierProvider);
      if (!mounted) return;

      await CelebrationDialog.show(
        context,
        title: 'Report Submitted',
        message: "Thanks for flagging this — we'll take a look.",
      );
      if (!mounted) return;

      // Straight to the report, so its status — "Submitted", then whatever the
      // parking office does with it — is the first thing seen, rather than
      // dropping the person back where they started with no sign it went
      // anywhere. Replaces this screen, so Back returns to where they came from.
      if (id != null) {
        context.pushReplacement('/home/user/incidents/$id');
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppScreen(
      title: 'Report an Incident',
      // Pinned rather than the last thing in the list. The form is three steps
      // long, so the button that ends it was a scroll away from wherever the
      // user finished typing.
      bottomBar: AppBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // What happens next, said before the button is pressed rather than
            // after: the question a person has when they hand something over.
            Text(
              "We'll notify you when the status changes.",
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Submit Report',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: kScreenListPadding,
        children: [
          Text.rich(
            TextSpan(
              style: context.text.bodyMedium
                  ?.copyWith(color: t.text.secondary),
              children: [
                const TextSpan(text: "Tell us what happened and we'll "),
                TextSpan(
                  text: 'look into it',
                  style: TextStyle(
                    color: t.text.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── 1 · Category ────────────────────────────────────────────────
          const AppFormSectionHeader(
            number: 1,
            title: 'What kind of incident?',
            requirement: FieldRequirement.required,
          ),
          const SizedBox(height: AppSpacing.md),
          AppChoiceTiles<String>(
            options: kIncidentCategories,
            icons: kIncidentCategoryIcons,
            intents: kIncidentCategoryIntents,
            value: _category,
            enabled: !_isSubmitting,
            errorText: _categoryError,
            onChanged: (value) => setState(() {
              _category = value;
              _categoryError = null;
            }),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── 2 · Details ─────────────────────────────────────────────────
          const AppFormSectionHeader(number: 2, title: 'Details'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'What happened?',
            requirement: FieldRequirement.required,
            controller: _description,
            hintText: 'What did you see? When did it happen, and which '
                'vehicle or slot was involved?',
            // Five lines, not one: this is the field the whole report hangs on
            // and it was once a single-line box you could not read your own
            // answer in.
            maxLines: 5,
            maxLength: _maxDescription,
            showCounter: true,
            enabled: !_isSubmitting,
            errorText: _descriptionError,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            onChanged: (_) {
              if (_descriptionError != null) {
                setState(() => _descriptionError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Location',
            requirement: FieldRequirement.optional,
            controller: _location,
            hintText: 'Slot C2 or near the gate',
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── 3 · Photos ──────────────────────────────────────────────────
          const AppFormSectionHeader(
            number: 3,
            title: 'Photos and PDFs',
            requirement: FieldRequirement.optional,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPhotoStrip(
            paths: _photos,
            // Photos and PDFs share the server's five-file limit.
            max: _maxFiles - _pdfs.length,
            enabled: !_isSubmitting,
            errorText: _photosError,
            onChanged: (paths) => setState(() {
              _photos = paths;
              _photosError = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPdfAttachments(
            paths: _pdfs,
            max: _maxFiles - _photos.length,
            enabled: !_isSubmitting,
            onChanged: (paths) => setState(() {
              _pdfs = paths;
              _photosError = null;
            }),
          ),
        ],
      ),
    );
  }
}
