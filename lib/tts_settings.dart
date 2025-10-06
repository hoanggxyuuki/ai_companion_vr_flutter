import 'package:flutter/material.dart';

class TTSSettings {
  static const String LOCAL_TTS = 'local';
  static const String OPENAI_TTS = 'openai';
  static const String GEMINI_TTS = 'gemini';
  
  String provider = OPENAI_TTS; 
  
  String openaiApiKey = '';
  String openaiVoice = 'alloy';
  String openaiModel = 'tts-1';
  
  String geminiApiKey = '';
  String? geminiVoice = 'Zephyr'; 
  double geminiTemperature = 1.0;
  
  String localLanguage = 'vi-VN';
  double speechRate = 0.8;
  double volume = 1.0;
  double pitch = 1.0;
  
  bool autoSpeak = true;
  bool speakDetections = true;
  bool speakDescriptions = true;

  TTSSettings();

  TTSSettings.fromJson(Map<String, dynamic> json) {
    provider = json['provider'] ?? OPENAI_TTS;
    openaiApiKey = json['openai_api_key'] ?? '';
    openaiVoice = json['openai_voice'] ?? 'alloy';
    openaiModel = json['openai_model'] ?? 'tts-1';
    geminiApiKey = json['gemini_api_key'] ?? '';
    geminiVoice = json['gemini_voice'] ?? 'Zephyr';
    geminiTemperature = json['gemini_temperature']?.toDouble() ?? 1.0;
    localLanguage = json['local_language'] ?? 'vi-VN';
    speechRate = json['speech_rate']?.toDouble() ?? 0.8;
    volume = json['volume']?.toDouble() ?? 1.0;
    pitch = json['pitch']?.toDouble() ?? 1.0;
    autoSpeak = json['auto_speak'] ?? true;
    speakDetections = json['speak_detections'] ?? true;
    speakDescriptions = json['speak_descriptions'] ?? true;
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'openai_api_key': openaiApiKey,
      'openai_voice': openaiVoice,
      'openai_model': openaiModel,
      'gemini_api_key': geminiApiKey,
      'gemini_voice': geminiVoice,
      'gemini_temperature': geminiTemperature,
      'local_language': localLanguage,
      'speech_rate': speechRate,
      'volume': volume,
      'pitch': pitch,
      'auto_speak': autoSpeak,
      'speak_detections': speakDetections,
      'speak_descriptions': speakDescriptions,
    };
  }

  bool get hasValidOpenAIKey => openaiApiKey.isNotEmpty && openaiApiKey.startsWith('sk-');
  bool get hasValidGeminiKey => geminiApiKey.isNotEmpty && geminiApiKey.startsWith('AIza');
  bool get isOpenAIProvider => provider == OPENAI_TTS;
  bool get isGeminiProvider => provider == GEMINI_TTS;
  bool get isLocalProvider => provider == LOCAL_TTS;
  
  static const List<String> geminiVoices = ['Zephyr', 'Puck', 'Kore', 'Sage'];
}