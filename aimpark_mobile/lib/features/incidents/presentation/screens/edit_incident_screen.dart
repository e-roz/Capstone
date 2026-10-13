import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/incident.dart';
import '../incident_categories.dart';
import '../providers/incidents_provider.dart';

/// Corrects a report the user already filed. Evidence is deliberately absent:
/// attachments are append-only server-side, so photos cannot be removed after
/// submission to weaken a report someone else may be relying on.
///
/// The category vocabulary comes from [kIncidentCategories] rather than a
/// second copy — the two lists were duplicated verbatim, which is one edit away
/// from this screen offering a category the report screen cannot create.
class EditIncidentScreen extends ConsumerStatefulWidget {
  const EditIncidentScreen({super.key, required this.incident});

  final IncidentDetail incident;

  @override
  ConsumerState<EditIncidentScreen> createState() => _EditIncidentScreenState();
}

class _EditIncidentScreenState extends ConsumerState<EditIncidentScreen> {
  late final TextEditingController _description;
  late final TextEditingController _location;
  late String _category;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.incident.description);
    _location = TextEditingController(text: widget.incident.location ?? '');
    // Fall back to Other if the stored category predates the current list, so
    // an old report still opens instead of throwing.
    _category = kIncidentCategories.containsKey(widget.incident.category)
        ? widget.incident.category
        : 'Other';
  }

  @override
  void dispose() {
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final description = _description.text.trim();
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
            location: _location.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Edit Report',
      body: ListView(
        padding: kScreenListPadding,
        children: [
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
            enabled: !_isSaving,
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppFormSectionHeader(number: 2, title: 'Details'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'What happened?',
            requirement: FieldRequirement.required,
            controller: _description,
            maxLines: 5,
            maxLength: 500,
            showCounter: true,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Location',
            requirement: FieldRequirement.optional,
            controller: _location,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            helperText: 'Photos already attached cannot be changed.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Save Changes',
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }
}
