import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class Quest3SCameraManager {
  static CameraController? _controller;
  static List<CameraDescription> _availableCameras = [];
  static bool _isInitialized = false;
  
  static const int QUEST_MAX_RESOLUTION_WIDTH = 1280;
  static const int QUEST_MAX_RESOLUTION_HEIGHT = 960;
  
  static Future<bool> initializeQuest3SCamera() async {
    try {
      debugPrint('Quest3S Camera: Requesting headset camera permission...');
      
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission != PermissionStatus.granted) {
        debugPrint('Quest3S Camera: Standard camera permission denied');
        return false;
      }
      
      debugPrint('Quest3S Camera: Getting available cameras...');
      _availableCameras = await availableCameras;
      
      if (_availableCameras.isEmpty) {
        debugPrint('Quest3S Camera: No cameras found');
        return false;
      }
      
      CameraDescription? questCamera;
      for (final camera in _availableCameras) {
        debugPrint('Quest3S Camera: Found camera - ${camera.name}, lens: ${camera.lensDirection}');
        
        if (camera.lensDirection == CameraLensDirection.front ||
            camera.name.toLowerCase().contains('passthrough') ||
            camera.name.toLowerCase().contains('quest') ||
            camera.name.toLowerCase().contains('meta')) {
          questCamera = camera;
          break;
        }
      }
      
      questCamera ??= _availableCameras.first;
      
      debugPrint('Quest3S Camera: Selected camera - ${questCamera.name}');
      
      _controller = CameraController(
        questCamera,
        ResolutionPreset.high, 
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      debugPrint('Quest3S Camera: Initializing camera controller...');
      await _controller!.initialize();
      
      _isInitialized = true;
      debugPrint('Quest3S Camera: Successfully initialized for Quest 3S');
      return true;
      
    } catch (e) {
      debugPrint('Quest3S Camera: Initialization error - $e');
      _isInitialized = false;
      return false;
    }
  }
  
  static CameraController? get controller => _controller;
  static bool get isInitialized => _isInitialized && _controller?.value.isInitialized == true;
  
  static Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
    debugPrint('Quest3S Camera: Disposed');
  }
  
  static List<CameraDescription> get availableCameras => _availableCameras;
}