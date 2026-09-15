import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/data/models/scan_result.dart';
import '../../../auth/data/registration_preflight.dart';
import '../../../auth/presentation/widgets/scanned_field.dart';
import '../providers/vehicles_provider.dart';

/// What the receipt said, plus the two things no document can tell us.
///
/// The same shape as the registration confirmation screen: the plate is
/// pre-filled from the receipt's OCR reading and editable, same as every
/// other field, with no photo left to corroborate it.
class ConfirmVehicleScreen extends ConsumerStatefulWidget {
  const ConfirmVehicleScreen({super.key, required this.result});

  final ScanResult result;

  @override
  ConsumerState<ConfirmVehicleScreen> createState() =>
      _ConfirmVehicleScreenState();
}

class _ConfirmVehicleScreenState extends ConsumerState<ConfirmVehicleScreen> {
  static const _vehicleTypes = <String, String>{
    'Car': 'Car',
    'Motorcycle': 'Motorcycle',
  };

  static const _vehicleIcons = <String, IconData>{
    'Car': Icons.directions_car_rounded,
    'Motorcycle': Icons.two_wheeler_rounded,
  };

  late final TextEditingController _plateNumber;
  late final TextEditingController _color;
  DateTime? _registrationExpiry;
  String? _vehicleType;
  String? _vehicleTypeError;
  bool _isSubmitting = false;

  ExtractedValues get _extracted => widget.result.extracted;

  @override
  void initState() {
    super.initState();
    _plateNumber = TextEditingController(text: _extracted.plateNumber);
    _color = TextEditingController(text: _extracted.color);
    _registrationExpiry = _extracted.registrationExpiry;
    _vehicleType = _vehicleTypes.containsKey(_extracted.vehicleType)
        ? _extracted.vehicleType
        : null;
  }

  @override
  void dispose() {
    _plateNumber.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _vehicleTypeError = _vehicleType == null ? 'Choose one.' : null;
    });
    if (_vehicleTypeError != null) return;

    if (fieldStillMissing(
      _extracted.flagFor('PlateNumber'),
      _plateNumber.text.trim().isEmpty,
    )) {
      showAppMessage(
        context,
        "We couldn't read a plate number — type it in before submitting.",
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(vehiclesRepositoryProvider).confirm({
        'verificationId': widget.result.verificationId,
        'plateNumber': _plateNumber.text.trim(),
        'vehicleType': _vehicleType,
        'color': _color.text.trim(),
        'registrationExpiry': _registrationExpiry?.toIso8601String(),
      });

      // The list is now wrong by exactly one vehicle.
      ref.invalidate(myVehiclesProvider);

      if (!mounted) return;

      await CelebrationDialog.show(
        context,
        title: 'Vehicle added',
        message: 'The gate will now open for this plate too.',
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = !_isSubmitting;

    // Only the registration expiry is worth checking here. The licence belongs
    // to the person, and this submission never claimed to describe them.
    final findings = registrationPreflight(
      licenseExpiry: null,
      registrationExpiry: _registrationExpiry,
      documentName: null,
      licenseName: null,
    );

    return AppScreen(
      title: 'Check the vehicle',
      body: ListView(
        padding: kScreenListPadding,
        children: [
          AppNotice(
            title: 'Is this right?',
            message: 'This is what we read from your receipt.',
            intent: StatusIntent.info,
          ),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(
            title: 'About this vehicle',
            subtitle: 'Read from your receipt — check they match before you '
                'submit.',
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
          ),
          AppChipGroup<String>(
            label: 'Type',
            options: _vehicleTypes,
            icons: _vehicleIcons,
            value: _vehicleType,
            enabled: live,
            errorText: _vehicleTypeError,
            onChanged: (value) => setState(() {
              _vehicleType = value;
              _vehicleTypeError = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          ScannedField(
            label: 'Colour',
            controller: _color,
            flag: _extracted.flagFor('Color'),
            enabled: live,
          ),
          const SizedBox(height: AppSpacing.lg),

          const AppSectionHeader(title: 'From your receipt'),
          ScannedField(
            label: 'Plate number',
            controller: _plateNumber,
            flag: _extracted.flagFor('PlateNumber'),
            enabled: live,
            textCapitalization: TextCapitalization.characters,
          ),
          ScannedDateField(
            label: 'Registration expiry',
            value: _registrationExpiry,
            flag: _extracted.flagFor('RegistrationExpiry'),
            enabled: live,
            onChanged: (d) => setState(() => _registrationExpiry = d),
          ),

          for (final finding in findings) ...[
            AppNotice(message: finding.message, intent: finding.intent),
            const SizedBox(height: AppSpacing.sm),
          ],

          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Add this vehicle',
            isLoading: _isSubmitting,
            onPressed: live ? _submit : null,
          ),
        ],
      ),
    );
  }
}
