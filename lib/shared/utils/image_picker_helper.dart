import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';

/// Mostra a escolha "Câmara / Galeria", depois recorta a imagem —
/// substitui a Web Share/File API por `image_picker` + `image_cropper`,
/// espelhando o fluxo de upload+recorte da app web (react-easy-crop).
Future<File?> pickAndCropImage(
  BuildContext context, {
  CropAspectRatioPreset preset = CropAspectRatioPreset.square,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Câmara'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeria'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 90,
  );
  if (picked == null) return null;
  if (!context.mounted) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Recortar imagem',
        toolbarColor: WisColors.navy,
        toolbarWidgetColor: Colors.white,
        backgroundColor: WisColors.background,
        initAspectRatio: preset,
        lockAspectRatio: true,
        aspectRatioPresets: [preset],
      ),
      IOSUiSettings(title: 'Recortar imagem', aspectRatioLockEnabled: true),
    ],
  );
  if (cropped == null) return null;
  return File(cropped.path);
}
