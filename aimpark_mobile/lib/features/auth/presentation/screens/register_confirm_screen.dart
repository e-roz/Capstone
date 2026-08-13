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
import '../../../../core/widgets/selectable_chip.dart';
import '../../data/models/scan_result.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import 'register_document_step_screen.dart';

/// The last screen: what was read, plus the two things no document can say.
///
/// Most of this is still editable, which is why extraction accuracy is not
/// load-bearing — a field the rules missed is typed once here rather than
/// chased through retake after retake, and both readings are kept so a reviewer
/// can see where the person disagreed with the machine.
///
/// The plate is the exception. It is what the gate camera matches on, so it is
/// shown read-only and comes from the receipt: a hand-typed plate proves
/// nothing about the vehicle, while the receipt and the photograph of the metal
/// agreeing does. Where they disagree the fix offered is another photograph,
/// not a keyboard.
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

  DateTime? _licenseExpiry;
  DateTime? _registrationExpiry;

  /// Keys match the API's `VehicleType` enum names exactly — slot allocation
  /// matches a user's vehicle against a slot's type. The facility only has
  /// two-wheel and four-wheel bays, so Van and Truck were never offered.
  static const _vehicleTypes = <String, IconData>{
    'Car': Icons.directions_car_rounded,
    'Motorcycle': Icons.two_wheeler_rounded,
  };

  /// Colours a guard could actually name at a gate. Free text would produce
  /// "pearl white", "off-white" and "White" for one vehicle, none of which help
  /// anybody pick it out of a car park.
  static const _colors = <String, Color>{
    'White': Color(0xFFFFFFFF),
    'Silver': Color(0xFFC0C0C0),
    'Grey': Color(0xFF808080),
    'Black': Color(0xFF1A1A1A),
    'Red': Color(0xFFDC2626),
    'Blue': Color(0xFF2563EB),
    'Green': Color(0xFF16A34A),
    'Yellow': Color(0xFFEAB308),
    'Orange': Color(0xFFEA580C),
    'Brown': Color(0xFF78350F),
  };

  String _vehicleType = 'Car';
  String? _color;
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

  /// Back to the plate photo, keeping the other three photographs.
  void _retakePlatePhoto() {
    final specs = documentSpecsFor(
      ref.read(registrationNotifierProvider).affiliation,
    );
    context.go('/register/documents/${specs.length - 1}');
  }

  Future<void> _submit(bool isStudent) async {
    if (_color == null) {
      showAppMessage(context, "Choose the vehicle's colour.", isError: true);
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
        // Echoed back exactly as read. The server compares it against its own
        // stored reading, so altering it here would be recorded as an edit
        // rather than quietly accepted.
        'plateNumber': _extracted.plateNumber,
        'registrationExpiry': _registrationExpiry?.toIso8601String(),
        'vehicleType': _vehicleType,
        'color': _color,
      });

      if (!mounted) return;

      // The photos have done their job. Holding them would mean a second pass
      // through the flow re-uploading this attempt's images.
      ref.read(registrationNotifierProvider.notifier).clearCaptured();

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

          _PlateCard(
            plate: _extracted.plateNumber,
            seenInPhoto: _extracted.platePhotoNumber,
            agreement: _extracted.plateAgreement,
            onRetakePhoto: _isSubmitting ? null : _retakePlatePhoto,
          ),
          const SizedBox(height: AppSpacing.lg),

          Text('Your vehicle', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Neither of these is printed on the receipt, so they are the only '
            'two things left to tell us.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Type', style: AppTextStyles.labelSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _vehicleTypes.entries.map((entry) {
              return SelectableChip(
                label: entry.key,
                icon: entry.value,
                selected: _vehicleType == entry.key,
                onTap: _isSubmitting
                    ? () {}
                    : () => setState(() => _vehicleType = entry.key),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Colour', style: AppTextStyles.labelSmall),
          const SizedBox(height: 6),
          _ColorPicker(
            colors: _colors,
            selected: _color,
            onSelected: _isSubmitting
                ? null
                : (name) => setState(() => _color = name),
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
          _DateField(
            label: 'Registration expiry',
            value: _registrationExpiry,
            flag: _extracted.flagFor('RegistrationExpiry'),
            onTap: () => _pickDate(
              current: _registrationExpiry,
              onPicked: (d) => setState(() => _registrationExpiry = d),
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

/// The plate, and how much confidence there is in it.
///
/// Given its own card because it is the one value nobody typed and the one the
/// gate depends on. The three outcomes read differently on purpose: agreement
/// needs no action, a disagreement asks for a photograph, and a missing reading
/// says an admin will finish the job — none of them is a dead end.
class _PlateCard extends StatelessWidget {
  const _PlateCard({
    required this.plate,
    required this.seenInPhoto,
    required this.agreement,
    required this.onRetakePhoto,
  });

  final String? plate;
  final String? seenInPhoto;
  final PlateAgreement agreement;
  final VoidCallback? onRetakePhoto;

  @override
  Widget build(BuildContext context) {
    final hasPlate = plate != null && plate!.isNotEmpty;

    final (Color tint, IconData icon, String note) = switch (agreement) {
      PlateAgreement.agreed => (
        AppColors.successDefault,
        Icons.verified_outlined,
        'The plate on your receipt and the plate in your photo match.',
      ),
      PlateAgreement.differs => (
        AppColors.errorDefault,
        Icons.report_problem_outlined,
        'Your photo reads $seenInPhoto, which is not what the receipt says. '
            'Retake the plate photo, or an admin will check it by hand.',
      ),
      PlateAgreement.notChecked => (
        AppColors.textSecondary,
        Icons.help_outline,
        hasPlate
            ? "We couldn't read the plate in your photo, so this is from the "
                  'receipt alone. An admin will confirm it.'
            : "We couldn't read a plate from your receipt. An admin will add it "
                  'before your account goes live.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plate number', style: AppTextStyles.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasPlate ? plate! : 'Not read',
            style: AppTextStyles.h1.copyWith(
              letterSpacing: 2,
              color: hasPlate ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  note,
                  style: AppTextStyles.bodySmall.copyWith(color: tint),
                ),
              ),
            ],
          ),
          if (agreement == PlateAgreement.differs ||
              (agreement == PlateAgreement.notChecked && hasPlate))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetakePhoto,
                child: const Text('Retake the plate photo'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final Map<String, Color> colors;
  final String? selected;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: colors.entries.map((entry) {
        final isSelected = selected == entry.key;

        return GestureDetector(
          onTap: onSelected == null ? null : () => onSelected!(entry.key),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: entry.value,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandPressed
                        : AppColors.borderDefault,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 20,
                        // White and yellow need a dark tick; everything else
                        // needs a light one.
                        color: entry.value.computeLuminance() > 0.6
                            ? Colors.black87
                            : Colors.white,
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                entry.key,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
