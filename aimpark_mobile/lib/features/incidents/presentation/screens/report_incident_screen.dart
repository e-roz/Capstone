import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/celebration_dialog.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../auth/presentation/widgets/image_picker_box.dart';
import '../providers/incidents_provider.dart';

const _kCategories = ['Vandalism', 'Theft', 'Accident', 'Blocked Slot', 'Other'];

class ReportIncidentScreen extends ConsumerStatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  ConsumerState<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String _category = _kCategories.first;
  String? _photo1;
  String? _photo2;
  String? _photo3;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      showAppMessage(context, 'Please describe what happened.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(incidentsRepositoryProvider).create(
            category: _category,
            description: description,
            location: _locationController.text.trim(),
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
      if (mounted) showAppMessage(context, apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('Report an Incident', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Category', style: AppTextStyles.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final category in _kCategories)
                  SelectableChip(
                    label: category,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'What happened?',
              controller: _descriptionController,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Location (optional)',
              controller: _locationController,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Photo Evidence (optional)', style: AppTextStyles.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            ImagePickerBox(
              label: 'Photo 1',
              imagePath: _photo1,
              onImageSelected: (path) => setState(() => _photo1 = path),
            ),
            const SizedBox(height: AppSpacing.sm),
            ImagePickerBox(
              label: 'Photo 2',
              imagePath: _photo2,
              onImageSelected: (path) => setState(() => _photo2 = path),
            ),
            const SizedBox(height: AppSpacing.sm),
            ImagePickerBox(
              label: 'Photo 3',
              imagePath: _photo3,
              onImageSelected: (path) => setState(() => _photo3 = path),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Submit Report',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
