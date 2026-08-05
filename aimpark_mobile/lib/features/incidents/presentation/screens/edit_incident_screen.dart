import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../data/models/incident.dart';
import '../providers/incidents_provider.dart';

/// Same category vocabulary as the report screen — keys are the API's
/// `IncidentCategory` names, values are what the chips display.
const _kCategories = <String, String>{
  'Vandalism': 'Vandalism',
  'Theft': 'Theft',
  'Accident': 'Accident',
  'BlockedSlot': 'Blocked Slot',
  'SuspiciousActivity': 'Suspicious Activity',
  'Other': 'Other',
};

/// Corrects a report the user already filed. Evidence is deliberately absent:
/// attachments are append-only server-side, so photos cannot be removed after
/// submission to weaken a report someone else may be relying on.
class EditIncidentScreen extends ConsumerStatefulWidget {
  const EditIncidentScreen({super.key, required this.incident});

  final IncidentDetail incident;

  @override
  ConsumerState<EditIncidentScreen> createState() => _EditIncidentScreenState();
}

class _EditIncidentScreenState extends ConsumerState<EditIncidentScreen> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late String _category;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.incident.description);
    _locationController =
        TextEditingController(text: widget.incident.location ?? '');
    // Fall back to Other if the stored category predates the current list,
    // so an old report still opens instead of throwing.
    _category = _kCategories.containsKey(widget.incident.category)
        ? widget.incident.category
        : 'Other';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      showAppMessage(context, 'Please describe what happened.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(incidentsRepositoryProvider).update(
            incidentId: widget.incident.incidentId,
            category: _category,
            description: description,
            location: _locationController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showAppMessage(context, apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('Edit Report', style: AppTextStyles.h3),
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
                for (final entry in _kCategories.entries)
                  SelectableChip(
                    label: entry.value,
                    selected: _category == entry.key,
                    onTap: () => setState(() => _category = entry.key),
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
            Text(
              'Photos already attached cannot be changed.',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save Changes',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
