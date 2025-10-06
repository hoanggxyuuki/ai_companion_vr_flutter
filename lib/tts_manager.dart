import 'package:flutter_tts/flutter_tts.dart';
import 'package:ai_companion_vr_flutter/core/openai_tts_service.dart';
import 'package:ai_companion_vr_flutter/tts_settings.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class TTSManager {
  static TTSManager? _instance;
  static TTSManager get instance => _instance ??= TTSManager._();
  
  TTSManager._();

  FlutterTts? _flutterTts;
  OpenAITTSService? _openaiTts;
  TTSSettings _settings = TTSSettings();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  TTSSettings get settings => _settings;

  Future<void> initialize([TTSSettings? settings]) async {
    if (settings != null) {
      _settings = settings;
    } else {
      _settings.provider = TTSSettings.OPENAI_TTS;
      _settings.openaiVoice = 'alloy';
      _settings.autoSpeak = true;
      _settings.speakDescriptions = true;
      _settings.speakDetections = true;
    }
    
    await _initializeProviders();
    _isInitialized = true;
  }

  Future<void> _initializeProviders() async {
    _flutterTts = FlutterTts();
    await _configureFlutterTts();
    
    try {
      _openaiTts = OpenAITTSService();
      print('✅ OpenAI TTS initialized');
    } catch (e) {
      print('❌ OpenAI TTS failed to initialize: $e');
      _settings.provider = TTSSettings.LOCAL_TTS; 
    }
  }

  Future<void> _configureFlutterTts() async {
    if (_flutterTts == null) return;
    
    await _flutterTts!.setLanguage(_settings.localLanguage);
    await _flutterTts!.setSpeechRate(_settings.speechRate);
    await _flutterTts!.setVolume(_settings.volume);
    await _flutterTts!.setPitch(_settings.pitch);
    
    _flutterTts!.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    _flutterTts!.setErrorHandler((msg) {
      print('🚨 Flutter TTS Error: $msg');
      _isSpeaking = false;
    });
  }

  Future<void> updateSettings(TTSSettings newSettings) async {
    _settings = newSettings;
    
    await _configureFlutterTts();
    
    if (_settings.isOpenAIProvider) {
      _openaiTts?.dispose();
      _openaiTts = OpenAITTSService();
    }
  }

  Future<bool> speak(String text) async {
    if (!_isInitialized || text.isEmpty || _isSpeaking) return false;
    
    if (!_settings.autoSpeak) return false;
    
    _isSpeaking = true;
    
    try {
      if (_openaiTts != null) {
        print('🔊 Speaking with OpenAI: $text');
        final success = await _openaiTts!.speak(
          text, 
          voice: _settings.openaiVoice,
        );
        if (success) {
          _isSpeaking = false;
          return true;
        }
      }
      
      print('🔊 Fallback to local TTS: $text');
      await _speakWithFlutterTts(text);
      return true;
    } catch (e) {
      print('🚨 TTS Error: $e');
      _isSpeaking = false;
      return false;
    }
  }

  Future<void> _speakWithFlutterTts(String text) async {
    if (_flutterTts != null) {
      await _flutterTts!.speak(text);
    } else {
      _isSpeaking = false;
    }
  }

  Future<void> speakDetection(String objectName, double confidence) async {
    if (!_settings.speakDetections) return;
    
    String text;
    if (_settings.localLanguage.startsWith('vi')) {
      text = 'Phát hiện $objectName với độ tin cậy ${(confidence * 100).toInt()} phần trăm';
    } else {
      text = 'Detected $objectName with ${(confidence * 100).toInt()} percent confidence';
    }
    
    await speak(text);
  }

  Future<void> speakDescription(String description) async {
    if (!_settings.speakDescriptions || description.isEmpty) return;
    
    await speak(description);
  }

  Future<void> speakDetectedObjects(List<Map<String, dynamic>> objects) async {
    if (!_settings.speakDetections || objects.isEmpty) return;
    
    if (_openaiTts != null) {
      final objectNames = objects.map((obj) => obj['name'] as String).toList();
      await _openaiTts!.announceDetectedObjects(objectNames);
    } else {
      String text;
      if (objects.length == 1) {
        final obj = objects.first;
        text = 'Phát hiện ${obj['name']}';
      } else {
        final objectNames = objects.map((obj) => obj['name'] as String).join(', ');
        text = 'Phát hiện ${objects.length} vật thể: $objectNames';
      }
      await speak(text);
    }
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      if (_settings.isOpenAIProvider && _openaiTts != null) {
        await _openaiTts!.stop();
      }
      
      if (_flutterTts != null) {
        await _flutterTts!.stop();
      }
      
      _isSpeaking = false;
    }
  }

  Future<bool> testTTS() async {
    if (_openaiTts != null) {
      return await _openaiTts!.testTTS();
    } else {
      String testText = 'Xin chào, hệ thống TTS đang hoạt động';
      return await speak(testText);
    }
  }

  Future<void> saveSettings() async {
    try {
      print('💾 TTS Settings saved: ${_settings.toJson()}');
    } catch (e) {
      print('🚨 Failed to save TTS settings: $e');
    }
  }

  void dispose() {
    _flutterTts?.stop();
    _openaiTts?.dispose();
    _flutterTts = null;
    _openaiTts = null;
    _isInitialized = false;
    _isSpeaking = false;
  }

  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'speaking': _isSpeaking,
      'provider': _settings.provider,
      'openai_available': _openaiTts != null,
      'flutter_tts_available': _flutterTts != null,
      'auto_speak': _settings.autoSpeak,
    };
  }
}