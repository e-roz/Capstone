import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class ImagePickerBox extends StatelessWidget {
  const ImagePickerBox({
    super.key,
    required this.label,
    required this.imagePath,
    required this.onImageSelected,
  });

  final String label;
  final String? imagePath;
  final ValueChanged<String> onImageSelected;

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
    final hasImage = imagePath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _showSourcePicker(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              border: Border.all(
                color: hasImage ? AppColors.successDefault : AppColors.borderDefault,
                width: hasImage ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
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
                          decoration: const BoxDecoration(
                            color: AppColors.successDefault,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: AppColors.textOnBrand,
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
                            child: Text(
                              'Retake',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textOnBrand,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 36,
                        color: AppColors.brandDefault,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Tap to add photo', style: AppTextStyles.bodySmall),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
