import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/widgets/image_picker_box.dart';
import '../providers/incidents_provider.dart';

/// Maps the API's `IncidentCategory` names to the labels shown on the chips.
/// The key is what gets sent — sending the label instead is what made every
/// category except "Other" fail server-side validation.
const kIncidentCategories = <String, String>{
  'Vandalism': 'Vandalism',
  'Theft': 'Theft',
  'Accident': 'Accident',
  'BlockedSlot': 'Blocked Slot',
  'SuspiciousActivity': 'Suspicious Activity',
  'Other': 'Other',
};

class ReportIncidentScreen extends ConsumerStatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  ConsumerState<ReportIncidentScreen> createState() =>
      _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  final _description = TextEditingController();
  final _location = TextEditingController();
  /// Nothing is chosen until the user chooses. It defaulted to the first chip,
  /// which is "Vandalism" — a serious accusation the form was making on their
  /// behalf, and one a hurried report would send unread.
  String? _category;
  String? _photo1;
  String? _photo2;
  String? _photo3;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final category = _category;
    if (category == null) {
      showAppMessage(context, 'Pick a category first.', isError: true);
      return;
    }

    final description = _description.text.trim();
    if (description.isEmpty) {
      showAppMessage(context, 'Please describe what happened.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(incidentsRepositoryProvider).create(
            category: category,
            description: description,
            location: _location.text.trim(),
            evidencePaths: [?_photo1, ?_photo2, ?_photo3],
          );
      ref.invalidate(incidentsNotifierProvider);
      if (mounted) {
        await CelebrationDialog.show(
          context,
          title: 'Report Submitted',
          message: "Thanks for flagging this — we'll take a look.",
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Report an Incident',
      // Pinned rather than the last thing in the list. The form is a category
      // grid, three fields and three photo slots long, so the button that ends
      // it was a scroll away from wherever the user finished typing.
      bottomBar: AppBottomBar(
        child: AppButton(
          label: 'Submit Report',
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ),
      body: ListView(
        padding: kScreenListPadding,
        children: [
          AppChipGroup<String>(
            label: 'Category',
            options: kIncidentCategories,
            value: _category,
            enabled: !_isSubmitting,
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'What happened?',
            controller: _description,
            // Four lines, not one: this is the field the whole report hangs on
            // and it was a single-line box you could not read your own answer
            // in.
            maxLines: 4,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Location (optional)',
            controller: _location,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            helperText: 'A slot code or a landmark helps us find it.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Photo Evidence (optional)', style: context.text.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          // Three across, not three stacked. Stacked, each box was a tall
          // portrait rectangle — the wrong shape for a photograph — and the
          // three of them made the form twice as long as it needed to be.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ImagePickerBox(
                  label: 'Photo 1',
                  height: 96,
                  imagePath: _photo1,
                  onImageSelected: (path) => setState(() => _photo1 = path),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ImagePickerBox(
                  label: 'Photo 2',
                  height: 96,
                  imagePath: _photo2,
                  onImageSelected: (path) => setState(() => _photo2 = path),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ImagePickerBox(
                  label: 'Photo 3',
                  height: 96,
                  imagePath: _photo3,
                  onImageSelected: (path) => setState(() => _photo3 = path),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
