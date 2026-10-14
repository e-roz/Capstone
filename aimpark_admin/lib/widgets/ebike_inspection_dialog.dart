import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/browser_files.dart';
import '../core/utils/responsive.dart';
import '../models/registration_detail.dart';
import '../providers/registrations_provider.dart';
import '../theme/theme.dart';

/// Records the in-person inspection of an e-bike and approves its owner.
///
/// An e-bike has no LTO plate and no receipt, so what identifies it is what is
/// written down here: photos, brand, colour and any distinguishing marks. The
/// size class decides which bays it parks in. The temporary plate is issued by
/// the server when this is submitted, so two admins cannot hand out the same one.
///
/// Returns the sentence to show once it has gone through, or null if the admin
/// closed the dialog.
Future<String?> showEBikeInspectionDialog(
  BuildContext context,
  RegistrationDetail detail,
) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EBikeInspectionDialog(detail: detail),
  );
}

const _minPhotos = 3;
const _maxPhotos = 6;

class _EBikeInspectionDialog extends ConsumerStatefulWidget {
  const _EBikeInspectionDialog({required this.detail});

  final RegistrationDetail detail;

  @override
  ConsumerState<_EBikeInspectionDialog> createState() =>
      _EBikeInspectionDialogState();
}

class _EBikeInspectionDialogState
    extends ConsumerState<_EBikeInspectionDialog> {
  final _brand = TextEditingController();
  final _color = TextEditingController();
  final _marks = TextEditingController();
  final _note = TextEditingController();

  final _photos = <PickedFile>[];
  String? _sizeClass;

  var _licenseMatches = false;
  var _seenInPerson = false;
  var _noLtoPlate = false;

  var _busy = false;
  String? _error;

  /// The checks panel can still need a look even though an e-bike has no
  /// receipt: the name on the licence, an expired licence. Approving over that
  /// needs a reason, exactly as it does for any other application.
  bool get _needsNote {
    final checks = widget.detail.checks;
    return checks != null && checks.verdict != 'Clear';
  }

  bool get _ready =>
      _photos.length >= _minPhotos &&
      _brand.text.trim().isNotEmpty &&
      _color.text.trim().isNotEmpty &&
      _sizeClass != null &&
      _licenseMatches &&
      _seenInPerson &&
      _noLtoPlate &&
      (!_needsNote || _note.text.trim().isNotEmpty);

  @override
  void dispose() {
    _brand.dispose();
    _color.dispose();
    _marks.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final file = await BrowserFiles.pick(accept: 'image/jpeg,image/png');
    if (file == null || !mounted) return;
    setState(() => _photos.add(file));
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref
        .read(registrationActionsProvider.notifier)
        .inspectEBike(
          widget.detail.userId,
          brand: _brand.text.trim(),
          color: _color.text.trim(),
          marks: _marks.text,
          sizeClass: _sizeClass!,
          photos: _photos,
          overrideNote: _needsNote ? _note.text : null,
        );

    if (!mounted) return;

    if (result.ok) {
      Navigator.pop(context, result.message);
      return;
    }

    setState(() {
      _busy = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.status.accent.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pedal_bike_rounded,
              size: AppSizes.iconMd,
              color: t.status.accent.fg,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          const Text('Inspect e-bike'),
        ],
      ),
      content: SizedBox(
        width: context.dialogWidth(560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.detail.fullName} has brought the e-bike to the office. '
                'Record what you see, then approve.',
                style: text.bodyMedium?.copyWith(color: t.text.secondary),
              ),
              const SizedBox(height: AppSpacing.x4),
              _SectionTitle(
                icon: Icons.photo_camera_rounded,
                label: 'E-bike photos',
                required: true,
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                'Front, side and back at least: ${_photos.length} of $_minPhotos added. Up to $_maxPhotos.',
                style: text.bodySmall?.copyWith(color: t.text.secondary),
              ),
              const SizedBox(height: AppSpacing.x2),
              Wrap(
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x2,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    _PhotoTile(
                      file: _photos[i],
                      onRemove: _busy
                          ? null
                          : () => setState(() => _photos.removeAt(i)),
                    ),
                  if (_photos.length < _maxPhotos)
                    _AddPhotoTile(onTap: _busy ? null : _addPhoto),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),
              _SectionTitle(
                icon: Icons.badge_rounded,
                label: 'Identity of the e-bike',
                required: true,
              ),
              const SizedBox(height: AppSpacing.x2),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brand,
                      enabled: !_busy,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        label: _requiredLabel(context, 'Brand'),
                        hintText: 'Ecoride',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: TextField(
                      controller: _color,
                      enabled: !_busy,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        label: _requiredLabel(context, 'Colour'),
                        hintText: 'Black',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              TextField(
                controller: _marks,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Distinguishing marks (optional)',
                  hintText: 'Red sticker on the left fender',
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              _SectionTitle(
                icon: Icons.local_parking_rounded,
                label: 'Where it parks',
                required: true,
              ),
              const SizedBox(height: AppSpacing.x2),
              DropdownButtonFormField<String>(
                initialValue: _sizeClass,
                onChanged: _busy ? null : (v) => setState(() => _sizeClass = v),
                decoration: InputDecoration(
                  label: _requiredLabel(context, 'Size class'),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Motorcycle',
                    child: Text('Small: fits a motorcycle bay'),
                  ),
                  DropdownMenuItem(
                    value: 'Car',
                    child: Text('Large: needs a car bay'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              Container(
                padding: const EdgeInsets.all(AppSpacing.x3),
                decoration: BoxDecoration(
                  color: t.status.accent.bg,
                  border: Border.all(color: t.status.accent.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_rounded,
                      size: AppSizes.iconMd,
                      color: t.status.accent.fg,
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(
                        'A temporary plate (EB-0001, EB-0002…) is issued automatically when you approve.',
                        style: text.bodySmall?.copyWith(
                          color: t.status.accent.fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              _SectionTitle(
                icon: Icons.checklist_rounded,
                label: 'Checklist',
                required: true,
              ),
              const SizedBox(height: AppSpacing.x2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: AppSpacing.x1,
                ),
                decoration: BoxDecoration(
                  color: (_licenseMatches && _seenInPerson && _noLtoPlate)
                      ? t.status.success.bg
                      : t.status.neutral.bg,
                  border: Border.all(
                    color: (_licenseMatches && _seenInPerson && _noLtoPlate)
                        ? t.status.success.border
                        : t.status.neutral.border,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: _licenseMatches,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _licenseMatches = v ?? false),
                      title: const Text('The licence matches the person'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: _seenInPerson,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _seenInPerson = v ?? false),
                      title: const Text('I have seen the e-bike in person'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: _noLtoPlate,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _noLtoPlate = v ?? false),
                      title: const Text(
                        'It is an e-bike with no LTO plate, not a registered motor vehicle',
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              if (_needsNote) ...[
                const SizedBox(height: AppSpacing.x4),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x3),
                  decoration: BoxDecoration(
                    color: t.status.warning.bg,
                    border: Border.all(color: t.status.warning.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final headline in widget.detail.checks!.headlines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.x1),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: AppSizes.iconSm,
                                color: t.status.warning.fg,
                              ),
                              const SizedBox(width: AppSpacing.x1),
                              Expanded(child: Text(headline)),
                            ],
                          ),
                        ),
                      if (widget.detail.checks!.headlines.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.x1),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: AppSizes.iconSm,
                                color: t.status.warning.fg,
                              ),
                              const SizedBox(width: AppSpacing.x1),
                              const Expanded(
                                child: Text(
                                  'The automatic checks could not confirm '
                                  'everything on the documents, so a reason is '
                                  'needed to approve.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.x2),
                      TextField(
                        controller: _note,
                        enabled: !_busy,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          label: _requiredLabel(
                            context,
                            'Reason for approving despite the above',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.x4),
              Row(
                children: [
                  Text(
                    '*',
                    style: text.bodySmall?.copyWith(color: t.status.danger.fg),
                  ),
                  const SizedBox(width: AppSpacing.x1),
                  Expanded(
                    child: Text(
                      'Required. Approve unlocks when all of these are filled in, '
                      'with at least $_minPhotos photos.',
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ),
                ],
              ),
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.x3),
                Text(
                  error,
                  style: text.bodyMedium?.copyWith(color: t.status.danger.fg),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // Locked until the photos and the checklist are done: the server
          // refuses without them, and a button that only fails is worse than
          // one that waits.
          onPressed: _ready && !_busy ? _submit : null,
          child: Text(_busy ? 'Approving…' : 'Approve and issue plate'),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.file, required this.onRemove});

  final PickedFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(file.bytes, fit: BoxFit.cover),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: t.surface.card.withValues(alpha: 0.85),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: t.status.accent.bg,
          border: Border.all(color: t.status.accent.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, color: t.status.accent.fg),
            const SizedBox(height: 4),
            Text(
              'Add photo',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.status.accent.fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section heading with a small tinted icon, so the dialog reads as four
/// distinct steps rather than one grey form.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.label,
    this.required = false,
  });

  final IconData icon;
  final String label;

  /// Adds a red asterisk: this section has to be done before approving.
  final bool required;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: t.status.accent.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: AppSizes.iconSm, color: t.status.accent.fg),
        ),
        const SizedBox(width: AppSpacing.x2),
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: t.status.danger.fg),
                ),
            ],
          ),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

/// A field label that ends in a red asterisk.
Widget _requiredLabel(BuildContext context, String label) {
  final t = context.tokens;

  return Text.rich(
    TextSpan(
      text: label,
      children: [
        TextSpan(
          text: ' *',
          style: TextStyle(color: t.status.danger.fg),
        ),
      ],
    ),
  );
}
