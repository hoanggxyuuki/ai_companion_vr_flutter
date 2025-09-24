import 'package:flutter/services.dart';

class QuestCameraPlugin {
  static const MethodChannel _channel = 
      MethodChannel('quest_camera_plugin');
  
  static Future<void> initializeCamera() async {
    try {
      await _channel.invokeMethod('initialize');
      print('🎥 Quest Camera: Initialized successfully');
    } catch (e) {
      print('🎥 Quest Camera Error: $e');
      rethrow;
    }
  }
  
  static Future<String?> captureFrame() async {
    try {
      return await _channel.invokeMethod<String>('captureFrame');
    } catch (e) {
      print('🎥 Quest Camera Capture Error: $e');
      return null;
    }
  }
  
  static Future<void> startPassthrough() async {
    try {
      await _channel.invokeMethod('startPassthrough');
      print('🎥 Quest Passthrough: Started successfully');
    } catch (e) {
      print('🎥 Quest Passthrough Error: $e');
      rethrow;
    }
  }
  
  static Future<void> stopPassthrough() async {
    try {
      await _channel.invokeMethod('stopPassthrough');
      print('🎥 Quest Passthrough: Stopped');
    } catch (e) {
      print('🎥 Quest Passthrough Stop Error: $e');
    }
  }
  
  static Future<Map<String, dynamic>?> getCameraInfo() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getCameraInfo');
      return result?.cast<String, dynamic>();
    } catch (e) {
      print('🎥 Quest Camera Info Error: $e');
      return null;
    }
  }
}