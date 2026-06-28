import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
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

  static const _vehicleTypes = ['Car', 'Motorcycle', 'Van', 'Truck'];

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
          Text(
            'Register your vehicle',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _plateController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Plate Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _makeController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Vehicle Make',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modelController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Vehicle Model',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _colorController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Vehicle Color',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _vehicleType,
            decoration: const InputDecoration(
              labelText: 'Vehicle Type',
              border: OutlineInputBorder(),
            ),
            items: _vehicleTypes
                .map(
                  (type) => DropdownMenuItem(value: type, child: Text(type)),
                )
                .toList(),
            onChanged: _isLoading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _vehicleType = value);
                    }
                  },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
