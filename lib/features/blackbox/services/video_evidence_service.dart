import 'dart:async';

import 'package:camera/camera.dart';

/// Lightweight video evidence recorder for SOS events.
/// Captures a short clip using the first available camera and returns the file path.
class VideoEvidenceService {
  CameraController? _controller;

  Future<String?> recordShortVideo({
    Duration duration = const Duration(seconds: 10),
  }) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('[Evidence] No cameras available');
        return null;
      }

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();
      if (!_controller!.value.isInitialized) {
        print('[Evidence] Controller not initialized');
        return null;
      }

      // Prepare and record
      try {
        await _controller!.prepareForVideoRecording();
      } catch (_) {
        // Some platforms may not support prepare; continue.
      }

      await _controller!.startVideoRecording();
      await Future.delayed(duration);
      final XFile file = await _controller!.stopVideoRecording();
      return file.path;
    } catch (e) {
      print('[Evidence] Recording error: $e');
      return null;
    } finally {
      await dispose();
    }
  }

  Future<void> dispose() async {
    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (e) {
        print('[Evidence] Dispose error: $e');
      }
      _controller = null;
    }
  }
}
