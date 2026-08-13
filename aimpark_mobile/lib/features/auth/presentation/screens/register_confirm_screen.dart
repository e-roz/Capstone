import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/celebration_dialog.dart';
import '../../data/models/scan_result.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';

/// Shows what was read and lets the user correct any of it before submitting.
///
/// This screen is why extraction accuracy is not load-bearing: a field the
/// rules missed is typed once here rather than chased through retake after
/// retake. Both readings are kept server-side, so a reviewer can always see
/// where the person disagreed with the machine.
class RegisterConfirmScreen extends ConsumerStatefulWidget {
  const RegisterConfirmScreen({super.key, required this.result});

  final ScanResult result;

  @override
  ConsumerState<RegisterConfirmScreen> createState() =>
      _RegisterConfirmScreenState();
}

class _RegisterConfirmScreenState extends ConsumerState<RegisterConfirmScreen> {
  late final TextEditingController _studentNumber;
  late final TextEditingController _studentName;
  late final TextEditingController _section;
  late final TextEditingController _semester;
  late final TextEditingController _licenseName;
  late final TextEditingController _plateNumber;

  DateTime? _licenseExpiry;
  DateTime? _registrationExpiry;
  bool _isSubmitting = false;

  ExtractedValues get _extracted => widget.result.extracted;

  @override
  void initState() {
    super.initState();
    _studentNumber = TextEditingController(text: _extracted.studentNumber);
    _studentName = TextEditingController(text: _extracted.studentName);
    _section = TextEditingController(text: _extracted.section);
    _semester = TextEditingController(text: _extracted.semester);
    _licenseName = TextEditingController(text: _extracted.licenseName);
    _plateNumber = TextEditingController(text: _extracted.plateNumber);
    _licenseExpiry = _extracted.licenseExpiry;
    _registrationExpiry = _extracted.registrationExpiry;
  }

  @override
  void dispose() {
    _studentNumber.dispose();
    _studentName.dispose();
    _section.dispose();
    _semester.dispose();
    _licenseName.dispose();
    _plateNumber.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      // Wide enough for a licence renewed years ago and one valid for years yet.
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _submit(bool isStudent) async {
    final plate = _plateNumber.text.trim();
    if (plate.isEmpty) {
      showAppMessage(
        context,
        'The plate number is needed — it is what the gate camera looks for.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.confirmDocuments({
        'verificationId': widget.result.verificationId,
        if (isStudent) 'studentNumber': _studentNumber.text.trim(),
        'studentName': _studentName.text.trim(),
        if (isStudent) 'section': _section.text.trim(),
        if (isStudent) 'semester': _semester.text.trim(),
        'licenseName': _licenseName.text.trim(),
        'licenseExpiry': _licenseExpiry?.toIso8601String(),
        'plateNumber': plate,
        'registrationExpiry': _registrationExpiry?.toIso8601String(),
      });

      if (!mounted) return;
      await CelebrationDialog.show(
        context,
        title: "You're all set!",
        message: 'Registration submitted — your account is pending review.',
      );
      if (mounted) context.go('/login/sign-in');
    } catch (e) {
      if (mounted) showAppMessage(context, apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent =
        ref.watch(registrationNotifierProvider.select((s) => s.affiliation)) ==
        Affiliation.student;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Check your details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Is this right?', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This is what we read from your documents. Fix anything that looks '
            'wrong — it goes to the admin exactly as you leave it.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (isStudent) ...[
            Text('From your registration form', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              label: 'Student number',
              controller: _studentNumber,
              flag: _extracted.flagFor('StudentNumber'),
            ),
            _Field(
              label: 'Full name',
              controller: _studentName,
              flag: _extracted.flagFor('StudentName'),
            ),
            _Field(
              label: 'Section',
              controller: _section,
              flag: _extracted.flagFor('Section'),
            ),
            _Field(
              label: 'Term',
              controller: _semester,
              flag: _extracted.flagFor('Semester'),
            ),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            Text('Your name', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              label: 'Full name',
              controller: _studentName,
              flag: _extracted.flagFor('StudentName'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          Text('From your licence', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          _Field(
            label: 'Name on licence',
            controller: _licenseName,
            flag: _extracted.flagFor('LicenseName'),
          ),
          _DateField(
            label: 'Licence expiry',
            value: _licenseExpiry,
            flag: _extracted.flagFor('LicenseExpiry'),
            onTap: () => _pickDate(
              current: _licenseExpiry,
              onPicked: (d) => setState(() => _licenseExpiry = d),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Text('From your receipt', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          _Field(
            label: 'Plate number',
            controller: _plateNumber,
            flag: _extracted.flagFor('PlateNumber'),
          ),
          _DateField(
            label: 'Registration expiry',
            value: _registrationExpiry,
            flag: _extracted.flagFor('RegistrationExpiry'),
            onTap: () => _pickDate(
              current: _registrationExpiry,
              onPicked: (d) => setState(() => _registrationExpiry = d),
            ),
          ),

          if (_extracted.platePhotoNumber != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'The plate in your photo read as '
                '${_extracted.platePhotoNumber}.',
                style: AppTextStyles.bodySmall,
              ),
            ),

          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Submit registration',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : () => _submit(isStudent),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Plain-language note under a field explaining why it wants a look.
///
/// A confidence score would mean nothing to someone holding a receipt, and
/// there is no different action to take at 0.62 than at 0.71 — so the two
/// reasons get different sentences instead of a number.
String? _flagText(FieldFlag? flag) => switch (flag) {
  FieldFlag.notFound => "We couldn't read this one — please type it in.",
  FieldFlag.derived =>
    'Worked out from your plate number rather than read. Check it.',
  null => null,
};

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, this.flag});

  final String label;
  final TextEditingController controller;
  final FieldFlag? flag;

  @override
  Widget build(BuildContext context) {
    final note = _flagText(flag);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(label: label, controller: controller),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                note,
                style: AppTextStyles.bodySmall.copyWith(
                  color: flag == FieldFlag.notFound
                      ? AppColors.errorDefault
                      : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.flag,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final FieldFlag? flag;

  @override
  Widget build(BuildContext context) {
    final note = _flagText(flag);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: InkWell(
              onTap: onTap,
              child: Text(
                value == null
                    ? 'Tap to choose'
                    : '${value!.day.toString().padLeft(2, '0')}/'
                          '${value!.month.toString().padLeft(2, '0')}/'
                          '${value!.year}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: value == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                note,
                style: AppTextStyles.bodySmall.copyWith(
                  color: flag == FieldFlag.notFound
                      ? AppColors.errorDefault
                      : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
