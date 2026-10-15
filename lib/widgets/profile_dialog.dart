import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Profile edit dialog for changing Partner name and profile picture (DP).
class ProfileDialog {
  static void show({
    required BuildContext context,
    required String aiName,
    required bool isMen,
    required String? initialImagePath,
    required Function(String name, String? imagePath) onSave,
    required Future<String?> Function(ImageSource source) onPickImage,
  }) {
    final nameController = TextEditingController(text: aiName);
    String? tempImagePath = initialImagePath;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: dialogContext,
                        builder: (sheetContext) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Choose from Gallery'),
                                onTap: () => Navigator.pop(
                                    sheetContext, ImageSource.gallery),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_camera),
                                title: const Text('Take Photo with Camera'),
                                onTap: () => Navigator.pop(
                                    sheetContext, ImageSource.camera),
                              ),
                              if (tempImagePath != null)
                                ListTile(
                                  leading: const Icon(Icons.delete,
                                      color: Colors.red),
                                  title: const Text('Remove Photo',
                                      style: TextStyle(color: Colors.red)),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    setDialogState(() {
                                      tempImagePath = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      );

                      if (source != null) {
                        final path = await onPickImage(source);
                        if (path != null) {
                          setDialogState(() {
                            tempImagePath = path;
                          });
                        }
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: const Color(0xFF128C7E),
                          backgroundImage: tempImagePath != null
                              ? FileImage(File(tempImagePath!))
                              : null,
                          child: tempImagePath == null
                              ? Icon(
                                  isMen ? Icons.face : Icons.face_3,
                                  color: Colors.white,
                                  size: 45,
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF075E54),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF075E54),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final n = nameController.text.trim();
                    onSave(n.isNotEmpty ? n : aiName, tempImagePath);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
