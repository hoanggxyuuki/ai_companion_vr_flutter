import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class VRTextToSpeech {
  static FlutterTts? _flutterTts;
  static bool _isInitialized = false;

  static Future<void> _initTts() async {
    if (_isInitialized) return;
    
    _flutterTts = FlutterTts();
    
    try {
      await _flutterTts!.setLanguage("vi-VN");
      await _flutterTts!.setSpeechRate(1.0);
      await _flutterTts!.setVolume(0.8);
      await _flutterTts!.setPitch(1.0);
      
      _isInitialized = true;
      debugPrint('VR TTS: Initialized successfully for Vietnamese');
    } catch (e) {
      debugPrint('VR TTS: Initialization error: $e');
      try {
        await _flutterTts!.setLanguage("en-US");
        _isInitialized = true;
        debugPrint('VR TTS: Fallback to English');
      } catch (fallbackError) {
        debugPrint('VR TTS: Fallback error: $fallbackError');
      }
    }
  }

  static Future<bool> speakVietnamese(
    String text, {
    double speechRate = 1.0,
    double pitch = 1.0,
    double volume = 0.8,
  }) async {
    if (text.isEmpty) return false;
    
    try {
      await _initTts();
      if (!_isInitialized) return false;
      
      await _flutterTts!.setSpeechRate(speechRate);
      await _flutterTts!.setPitch(pitch);
      await _flutterTts!.setVolume(volume);
      
      final result = await _flutterTts!.speak(text);
      debugPrint('VR TTS: Speaking "$text" - Result: $result');
      
      return result == 1; 
    } catch (e) {
      debugPrint('VR TTS: Error speaking text: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      if (_isInitialized && _flutterTts != null) {
        await _flutterTts!.stop();
        debugPrint('VR TTS: Stopped');
      }
    } catch (e) {
      debugPrint('VR TTS: Error stopping: $e');
    }
  }

  static Future<bool> isLanguageAvailable(String language) async {
    try {
      await _initTts();
      if (!_isInitialized) return false;
      
      final languages = await _flutterTts!.getLanguages;
      return languages.contains(language);
    } catch (e) {
      debugPrint('VR TTS: Error checking language availability: $e');
      return false;
    }
  }

  static void dispose() {
    _flutterTts = null;
    _isInitialized = false;
    debugPrint('VR TTS: Disposed');
  }
}