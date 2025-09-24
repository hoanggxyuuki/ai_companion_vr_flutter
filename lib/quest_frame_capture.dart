import 'package:flutter/services.dart';
import 'dart:typed_data';

class QuestFrameCapture {
  static const MethodChannel _channel = MethodChannel('quest_frame_capture');

  // Check Quest 3S permissions (including horizonos.permission.HEADSET_CAMERA)
  static Future<Map<String, dynamic>?> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      print('🔥 Quest Camera permission check error: $e');
      return null;
    }
  }

  // Request Quest 3S permissions
  static Future<Map<String, dynamic>?> requestPermissions() async {
    try {
      final result = await _channel.invokeMethod('requestPermissions');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      print('🔥 Quest Camera permission request error: $e');
      return null;
    }
  }

  // Find Quest 3S passthrough camera using Meta metadata
  static Future<Map<String, dynamic>?> findPassthroughCamera() async {
    try {
      final result = await _channel.invokeMethod('findPassthroughCamera');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      print('🔥 Quest Camera passthrough search error: $e');
      return null;
    }
  }

  // List all cameras with Quest 3S passthrough detection
  static Future<List<Map<String, dynamic>>?> listCameras() async {
    try {
      final result = await _channel.invokeMethod('listAvailableCameras');
      if (result is List) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return null;
    } catch (e) {
      print('🔥 Quest Camera list error: $e');
      return null;
    }
  }

  // Initialize camera (automatically selects passthrough if available)
  static Future<Map<String, dynamic>?> initializeCamera({String? cameraId}) async {
    try {
      final result = await _channel.invokeMethod('initializeCamera', {
        'cameraId': cameraId,
      });
      if (result is Map) {
        final info = Map<String, dynamic>.from(result);
        print('🔥 Quest Camera initialized: ${info['message']} (Passthrough: ${info['isPassthrough']})');
        return info;
      }
      return null;
    } catch (e) {
      print('🔥 Quest Camera initialization error: $e');
      return null;
    }
  }

  // Capture single frame from Quest 3S camera
  static Future<Uint8List?> captureFrame() async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('captureFrame');
      if (result != null) {
        print('🔥 Quest Camera: Frame captured - ${result.length} bytes');
      }
      return result;
    } catch (e) {
      print('🔥 Quest Camera capture error: $e');
      return null;
    }
  }

  // Release camera resources
  static Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
      print('🔥 Quest Camera: Released');
    } catch (e) {
      print('🔥 Quest Camera release error: $e');
    }
  }
}