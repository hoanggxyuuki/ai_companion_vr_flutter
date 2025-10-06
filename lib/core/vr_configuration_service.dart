import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VRConfigurationService {
  static const MethodChannel _channel = MethodChannel('vr_configuration');
  static bool _isVRMode = false;
  static bool _isImmersiveMode = false;

  static Future<bool> initializeVRMode() async {
    try {
      debugPrint('🥽 Initializing VR mode...');
      
      await enableImmersiveMode();
      
      final result = await _channel.invokeMethod('initializeVR', {
        'enable360': true,
        'enablePassthrough': true,
        'enableHandTracking': true,
        'stereoRendering': true,
        'targetFrameRate': 72, 
      });
      
      _isVRMode = result ?? false;
      debugPrint('🥽 VR Mode initialized: $_isVRMode');
      return _isVRMode;
      
    } catch (e) {
      debugPrint('🚨 VR initialization error: $e');
      return false;
    }
  }

  static Future<void> enableImmersiveMode() async {
    try {
      debugPrint('🌟 Enabling immersive mode...');
      
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
      
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      
      await _channel.invokeMethod('keepScreenOn', true);
      
      _isImmersiveMode = true;
      debugPrint('✅ Immersive mode enabled');
      
    } catch (e) {
      debugPrint('🚨 Immersive mode error: $e');
    }
  }

  static Future<void> disableImmersiveMode() async {
    try {
      debugPrint('🔙 Disabling immersive mode...');
      
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      
      await _channel.invokeMethod('keepScreenOn', false);
      
      _isImmersiveMode = false;
      debugPrint('✅ Immersive mode disabled');
      
    } catch (e) {
      debugPrint('🚨 Disable immersive mode error: $e');
    }
  }

  static Future<bool> configureVRCamera() async {
    try {
      debugPrint('📹 Configuring VR camera...');
      
      final result = await _channel.invokeMethod('configureCamera', {
        'stereoMode': true,
        'passthrough': true,
        'resolution': '1280x960', 
        'frameRate': 30,
        'eyeTracking': true,
        'handTracking': true,
      });
      
      debugPrint('📹 VR Camera configured: $result');
      return result ?? false;
      
    } catch (e) {
      debugPrint('🚨 VR Camera configuration error: $e');
      return false;
    }
  }

  static Future<bool> enter360Mode() async {
    try {
      debugPrint('🌐 Entering 360° VR mode...');
      
      if (!_isVRMode) {
        await initializeVRMode();
      }
      
      final result = await _channel.invokeMethod('enter360Mode', {
        'sphericalView': true,
        'headTracking': true,
        'roomScale': true,
        'guardianSystem': true,
      });
      
      debugPrint('🌐 360° Mode: $result');
      return result ?? false;
      
    } catch (e) {
      debugPrint('🚨 360° mode error: $e');
      return false;
    }
  }

  static Future<bool> exit360Mode() async {
    try {
      debugPrint('📱 Exiting 360° VR mode...');
      
      final result = await _channel.invokeMethod('exit360Mode');
      
      debugPrint('📱 Flat mode: $result');
      return result ?? false;
      
    } catch (e) {
      debugPrint('🚨 Exit 360° mode error: $e');
      return false;
    }
  }

  static Future<void> optimizeVRPerformance() async {
    try {
      debugPrint('⚡ Optimizing VR performance...');
      
      await _channel.invokeMethod('optimizePerformance', {
        'cpuLevel': 3, 
        'gpuLevel': 3, 
        'fixedFoveated': true,
        'multiview': true,
        'msaa': 2,
      });
      
      debugPrint('⚡ VR Performance optimized');
      
    } catch (e) {
      debugPrint('🚨 VR Performance optimization error: $e');
    }
  }

  static Future<Map<String, dynamic>> getVRStatus() async {
    try {
      final result = await _channel.invokeMethod('getVRStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('🚨 Get VR status error: $e');
      return {
        'isVRMode': _isVRMode,
        'isImmersiveMode': _isImmersiveMode,
        'error': e.toString(),
      };
    }
  }

  static Future<bool> isVRSupported() async {
    try {
      final result = await _channel.invokeMethod('isVRSupported');
      return result ?? false;
    } catch (e) {
      debugPrint('🚨 VR support check error: $e');
      return false;
    }
  }

  static bool get isVRMode => _isVRMode;
  static bool get isImmersiveMode => _isImmersiveMode;

  static Widget wrapForVR(Widget child) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black, 
      ),
      child: SafeArea(
        child: child,
      ),
    );
  }

  static ButtonStyle getVRButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white.withOpacity(0.9),
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
    );
  }

  static TextStyle getVRTextStyle({
    double fontSize = 16,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      shadows: [
        Shadow(
          offset: const Offset(1, 1),
          blurRadius: 2,
          color: Colors.black.withOpacity(0.8),
        ),
      ],
    );
  }
}