import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/theme.dart';

class ImagePickerBox extends StatelessWidget {
  const ImagePickerBox({
    super.key,
    required this.label,
    required this.imagePath,
    required this.onImageSelected,
    this.height = 140,
  });

  final String label;
  final String? imagePath;
  final ValueChanged<String> onImageSelected;

  /// Shorter when three of these sit in one row: at the full height a row of
  /// three reads as three tall slots rather than one control, and the prompt
  /// underneath the icon has no width left to sit in.
  final double height;

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (file != null) {
      onImageSelected(file.path);
    }
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final success = t.status.success;
    final hasImage = imagePath != null;
    final compact = height < 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelSmall),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _showSourcePicker(context),
          borderRadius: AppRadius.mdAll,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: t.surface.card,
              border: Border.all(
                color: hasImage ? success.solid : t.border.normal,
                width: hasImage ? 2 : 1.5,
              ),
              borderRadius: AppRadius.mdAll,
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: success.solid,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.check_rounded,
                            size: AppSizes.iconSm,
                            color: t.text.onDark,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showSourcePicker(context),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            // Sits on a scrim that is dark whatever the app
                            // theme is doing, so this reads onDark rather than
                            // the ordinary text tokens.
                            child: Text(
                              'Retake',
                              style: context.text.labelSmall
                                  ?.copyWith(color: t.text.onDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: compact ? AppSizes.iconLg : 36,
                        color: t.brand.primary,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // "Tap to add photo" ran the full width of a narrow box
                      // and touched both borders. In a row of three there is no
                      // room for the sentence, and the icon already says it.
                      if (!compact)
                        Text(
                          'Tap to add photo',
                          style: context.text.bodySmall,
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
