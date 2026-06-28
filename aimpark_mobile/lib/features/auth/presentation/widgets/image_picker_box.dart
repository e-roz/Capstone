import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showSourcePicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: imagePath != null
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
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            color: Colors.white,
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showSourcePicker(context),
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
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add photo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
