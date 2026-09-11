import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/gate_device.dart';
import '../providers/gate_device_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

/// Every RFID reader and ALPR camera registered to a gate, with the key
/// each one authenticates as. A key is only ever shown once, right after
/// it's created — this screen otherwise only shows its first 12 characters,
/// enough to tell two devices apart without being able to reuse either.
class GateDevicesScreen extends ConsumerWidget {
  const GateDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Gate Devices',
      subtitle: 'The RFID readers and ALPR cameras allowed to talk to the '
          'gate API, and the keys they use to prove it.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppToolbar(
            trailing: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(gateDeviceListProvider),
              ),
              const SizedBox(width: AppSpacing.x2),
              FilledButton.icon(
                onPressed: () => _showRegisterDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Register a device'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.headingGap),
          Expanded(
            child: AsyncView(
              value: ref.watch(gateDeviceListProvider),
              onRetry: () => ref.invalidate(gateDeviceListProvider),
              loading: const SkeletonTable(),
              isEmpty: (devices) => devices.isEmpty,
              empty: AppEmptyState(
                icon: Icons.sensors_outlined,
                title: 'No gate devices yet',
                message: 'Register the RFID reader or ALPR camera at a gate '
                    'to give it a key.',
                action: FilledButton.icon(
                  onPressed: () => _showRegisterDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Register a device'),
                ),
              ),
              data: (devices) => AppDataTable(
                minWidth: 760,
                columns: const [
                  DataColumn(label: Text('Device')),
                  DataColumn(label: Text('Gate')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Key')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Last seen')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final device in devices) _rowFor(context, ref, device),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _rowFor(BuildContext context, WidgetRef ref, GateDevice device) {
    return DataRow(cells: [
      DataCell(AppPrimaryCell(title: device.name)),
      DataCell(Text(device.gateLabel)),
      DataCell(Text(device.deviceType.label)),
      DataCell(Text('${device.apiKeyPrefix}…')),
      DataCell(
        StatusPill(
          label: device.isRevoked ? 'Revoked' : 'Active',
          intent: device.isRevoked ? StatusIntent.danger : StatusIntent.success,
          dense: true,
        ),
      ),
      DataCell(Text(
        device.lastSeenAt == null
            ? 'Never'
            : DateFormat('MMM d, HH:mm').format(device.lastSeenAt!.toLocal()),
      )),
      DataCell(
        device.isRevoked
            ? const SizedBox.shrink()
            : AppRowAction(
                label: 'Revoke',
                icon: Icons.block,
                intent: StatusIntent.danger,
                onPressed: () => _confirmRevoke(context, ref, device),
              ),
      ),
    ]);
  }

  Future<void> _confirmRevoke(
      BuildContext context, WidgetRef ref, GateDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke ${device.name}?'),
        content: Text(
          'Its key stops working immediately. ${device.deviceType.label} '
          'hardware at ${device.gateLabel} will need a new one to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: ctx.tokens.status.danger.solid),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final msg =
        await ref.read(gateDeviceActionsProvider.notifier).revoke(device.deviceId);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Device revoked.')));
    ref.invalidate(gateDeviceListProvider);
  }

  Future<void> _showRegisterDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final gateCtrl = TextEditingController();
    var deviceType = GateDeviceType.rfidReader;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Register a Gate Device'),
          content: SizedBox(
            width: ctx.dialogWidth(420),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppRequiredNote(),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Device name', isRequired: true),
                        helperText: 'Something recognizable, e.g. "North gate '
                            'ALPR camera."',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'A name is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: gateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Gate number', isRequired: true),
                        helperText: 'Use 0 for the enrollment desk reader.',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        return (n == null || n < 0)
                            ? 'Enter a gate number of 0 or more'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    DropdownButtonFormField<GateDeviceType>(
                      initialValue: deviceType,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Device type', isRequired: true),
                      ),
                      items: [
                        for (final t in GateDeviceType.values)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: (v) => setState(() => deviceType = v!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(gateDeviceActionsProvider.notifier).register(
          name: nameCtrl.text.trim(),
          gate: int.parse(gateCtrl.text.trim()),
          deviceType: deviceType,
        );

    if (!context.mounted) return;

    if (result.device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not register device.')),
      );
      return;
    }

    ref.invalidate(gateDeviceListProvider);
    await _showKeyRevealDialog(context, result.device!);
  }

  Future<void> _showKeyRevealDialog(
      BuildContext context, CreatedGateDevice device) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('${device.name} is registered'),
        content: SizedBox(
          width: ctx.dialogWidth(440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.x3),
                decoration: BoxDecoration(
                  color: ctx.tokens.status.danger.bg,
                  borderRadius: AppRadii.mdAll,
                ),
                child: Text(
                  device.warning,
                  style: TextStyle(
                    fontSize: 12,
                    color: ctx.tokens.status.danger.fg,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              const Text('Paste this into the device\'s config exactly as shown:'),
              const SizedBox(height: AppSpacing.x2),
              SelectableText(
                device.apiKey,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.x3),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy key'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: device.apiKey));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Key copied.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
