import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../providers/auth_provider.dart';
import '../widgets/registration_step_scaffold.dart';

class RegisterVehicleScreen extends ConsumerStatefulWidget {
  const RegisterVehicleScreen({super.key});

  @override
  ConsumerState<RegisterVehicleScreen> createState() =>
      _RegisterVehicleScreenState();
}

class _RegisterVehicleScreenState extends ConsumerState<RegisterVehicleScreen> {
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  String _vehicleType = 'Car';
  bool _isLoading = false;

  /// Keys must match the API's `VehicleType` enum names exactly — slot
  /// allocation matches a user's vehicle against a slot's type. The facility
  /// only has two-wheel and four-wheel bays, so Van and Truck were removed
  /// rather than given a slot class they could never be allocated to.
  static const _vehicleTypes = <String, IconData>{
    'Car': Icons.directions_car_rounded,
    'Motorcycle': Icons.two_wheeler_rounded,
  };

  @override
  void dispose() {
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_plateController.text.trim().isEmpty ||
        _makeController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty ||
        _colorController.text.trim().isEmpty) {
      return 'All vehicle fields are required.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      showAppMessage(context, error, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.registerVehicle({
        'plateNumber': _plateController.text.trim(),
        'brand': _makeController.text.trim(),
        'model': _modelController.text.trim(),
        'color': _colorController.text.trim(),
        'vehicleType': _vehicleType,
      });

      if (mounted) {
        context.go('/register/documents');
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context, apiErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationStepScaffold(
      step: 4,
      title: 'Vehicle Info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Register your vehicle', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Plate Number',
            controller: _plateController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Vehicle Make',
            controller: _makeController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Vehicle Model',
            controller: _modelController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Vehicle Color',
            controller: _colorController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Vehicle Type', style: AppTextStyles.labelSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _vehicleTypes.entries.map((entry) {
              return SelectableChip(
                label: entry.key,
                icon: entry.value,
                selected: _vehicleType == entry.key,
                onTap: _isLoading
                    ? () {}
                    : () => setState(() => _vehicleType = entry.key),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Continue',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
