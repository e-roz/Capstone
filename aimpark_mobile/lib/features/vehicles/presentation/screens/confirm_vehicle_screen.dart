import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/data/models/scan_result.dart';
import '../../../auth/data/registration_preflight.dart';
import '../../../auth/presentation/widgets/plate_verdict_card.dart';
import '../../../auth/presentation/widgets/scanned_field.dart';
import '../../../auth/presentation/widgets/vehicle_color_picker.dart';
import '../providers/vehicles_provider.dart';

/// What the receipt said, plus the two things no document can tell us.
///
/// The same shape as the registration confirmation screen, and for the same
/// reason: the plate is read-only because it is what the gate matches on, and a
/// plate somebody could retype here would put back the exact hole this flow
/// exists to close.
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

  DateTime? _registrationExpiry;
  String? _vehicleType;
  String? _color;
  String? _vehicleTypeError;
  String? _colorError;
  bool _isSubmitting = false;

  ExtractedValues get _extracted => widget.result.extracted;

  @override
  void initState() {
    super.initState();
    _registrationExpiry = _extracted.registrationExpiry;
  }

  Future<void> _submit() async {
    setState(() {
      _vehicleTypeError = _vehicleType == null ? 'Choose one.' : null;
      _colorError = _color == null ? 'Choose one.' : null;
    });
    if (_vehicleTypeError != null || _colorError != null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(vehiclesRepositoryProvider).confirm({
        'verificationId': widget.result.verificationId,
        'vehicleType': _vehicleType,
        'color': _color,
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
          AppSectionHeader(
            title: 'Is this right?',
            subtitle: 'This is what we read from your receipt and plate photo.',
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          ),

          PlateVerdictCard(
            plate: _extracted.plateNumber,
            seenInPhoto: _extracted.platePhotoNumber,
            agreement: _extracted.plateAgreement,
            // Nowhere to send them back to from here — the capture screen is one
            // pop away and still holds both photos.
            onRetakePhoto: live ? () => Navigator.of(context).pop() : null,
          ),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(
            title: 'About this vehicle',
            subtitle: 'Neither of these is printed on the receipt.',
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
          VehicleColorPicker(
            selected: _color,
            errorText: _colorError,
            onSelected: live
                ? (name) => setState(() {
                      _color = name;
                      _colorError = null;
                    })
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),

          const AppSectionHeader(title: 'From your receipt'),
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
