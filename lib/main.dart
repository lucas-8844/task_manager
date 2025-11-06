// lib/services/camera_service.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  final ImagePicker _picker = ImagePicker();
  bool _initialized = false;

  Future<void> initialize() async {
    // Caso queira, você pode checar permissões aqui.
    // Com image_picker geralmente não precisa fazer nada.
    _initialized = true;
  }

  Future<String?> takePicture(BuildContext context) async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1920);
      return photo?.path;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir câmera: $e')),
        );
      }
      return null;
    }
  }

  Future<void> deletePhoto(String path) async {
    // opcional: deletar arquivo se existir
    // import 'dart:io';
    // final f = File(path);
    // if (await f.exists()) await f.delete();
  }
}
