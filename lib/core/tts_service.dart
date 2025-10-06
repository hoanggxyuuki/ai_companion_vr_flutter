import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final FlutterTts _flutterTts = FlutterTts();
  static const MethodChannel _audioChannel = MethodChannel('vr_tts_audio');
  static const MethodChannel _nativeTTSChannel = MethodChannel('native_tts');
  static bool _isInitialized = false;
  static bool _isSpeaking = false;
  static bool _useNativeTTS = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    print("🔄 Initializing TTS Service for Quest 3S...");
    
    await Future.delayed(Duration(milliseconds: 500));
    
    try {
      bool nativeInitialized = await _nativeTTSChannel.invokeMethod('isInitialized');
      if (nativeInitialized) {
        _useNativeTTS = true;
        print("✅ Using Native Android TTS");
      } else {
        print("⚠️ Native TTS not initialized yet");
        _useNativeTTS = false;
      }
    } catch (e) {
      print("⚠️ Native TTS not available: $e");
      _useNativeTTS = false;
    }
    
    await _flutterTts.setLanguage("vi-VN"); 
    await _flutterTts.setSpeechRate(0.6); 
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setStartHandler(() {
      print("🔊 Flutter TTS Started");
      _isSpeaking = true;
    });
    
    _flutterTts.setCompletionHandler(() {
      print("🔊 Flutter TTS Completed");
      _isSpeaking = false;
    });
    
    _flutterTts.setErrorHandler((msg) {
      print("🚨 Flutter TTS Error: $msg");
      _isSpeaking = false;
    });
    
    _flutterTts.setCancelHandler(() {
      print("🔊 Flutter TTS Cancelled");
      _isSpeaking = false;
    });
    
    _flutterTts.setPauseHandler(() {
      print("🔊 Flutter TTS Paused");
    });
    
    _flutterTts.setContinueHandler(() {
      print("🔊 Flutter TTS Continued");
    });
    
    await _configureAudioSession();
    
    _isInitialized = true;
    print("✅ TTS Service initialized for Quest 3S (Native: $_useNativeTTS)");
  }

  static Future<void> speak(String text) async {
    try {
      await initialize();
      
      if (!_isInitialized) {
        print("🚨 TTS not initialized, cannot speak");
        return;
      }
      
      if (text.isEmpty) {
        print("⚠️ Empty text provided to TTS");
        return;
      }
      
      if (_isSpeaking) {
        print("⚠️ TTS seems stuck, forcing reset");
        _isSpeaking = false;
        await stop();
      }
      
      print("🔊 TTS Speaking: $text (Native: $_useNativeTTS)");
      _isSpeaking = true;
      
      if (_useNativeTTS) {
        await _speakWithNative(text);
      } else {
        await _speakWithFlutter(text);
      }
      
      print("✅ TTS speak command sent");
    } catch (e) {
      print("🚨 TTS speak error: $e");
      _isSpeaking = false;
      rethrow;
    }
  }
  
  static Future<void> _speakWithNative(String text) async {
    try {
      bool audioFocusGranted = await _audioChannel.invokeMethod('requestAudioFocus');
      print("🎯 Audio focus granted: $audioFocusGranted");
      
      bool success = await _nativeTTSChannel.invokeMethod('speak', {
        'text': text,
        'language': 'vi-VN'
      });
      
      if (!success) {
        print("⚠️ Native TTS failed, falling back to Flutter TTS");
        await _speakWithFlutter(text);
      } else {
        Future.delayed(Duration(seconds: 3), () {
          _isSpeaking = false;
        });
      }
    } catch (e) {
      print("🚨 Native TTS error: $e");
      await _speakWithFlutter(text);
    }
  }
  
  static Future<void> _speakWithFlutter(String text) async {
    try {
      await _audioChannel.invokeMethod('requestAudioFocus');
      
      await _audioChannel.invokeMethod('configureAudioSession');
      
      await _flutterTts.speak(text);
    } catch (e) {
      print("🚨 Flutter TTS error: $e");
      _isSpeaking = false;
      rethrow;
    }
  }

  static Future<void> speakDetection(String objectName, double confidence) async {
    String announcement = _createVietnameseAnnouncement(objectName, confidence);
    await speak(announcement);
  }

  static Future<void> speakMultipleDetections(List<Map<String, dynamic>> objects) async {
    if (objects.isEmpty) return;
    
    String announcement = _createMultipleDetectionsAnnouncement(objects);
    await speak(announcement);
  }

  static String _createVietnameseAnnouncement(String objectName, double confidence) {
    String vietnameseName = _translateToVietnamese(objectName);
    
    if (confidence > 0.8) {
      return "Tôi thấy $vietnameseName";
    } else if (confidence > 0.6) {
      return "Có thể là $vietnameseName";
    } else {
      return "Tôi nghĩ đây là $vietnameseName";
    }
  }

  static String _createMultipleDetectionsAnnouncement(List<Map<String, dynamic>> objects) {
    if (objects.length == 1) {
      return _createVietnameseAnnouncement(
        objects[0]['name'] ?? 'vật thể', 
        objects[0]['confidence'] ?? 0.0
      );
    }

    List<String> vietnameseNames = objects.take(3).map((obj) => 
      _translateToVietnamese(obj['name'] ?? 'vật thể')
    ).toList();

    if (vietnameseNames.length == 2) {
      return "Tôi thấy ${vietnameseNames[0]} và ${vietnameseNames[1]}";
    } else {
      String result = "Tôi thấy ";
      for (int i = 0; i < vietnameseNames.length; i++) {
        if (i == vietnameseNames.length - 1) {
          result += "và ${vietnameseNames[i]}";
        } else if (i == 0) {
          result += vietnameseNames[i];
        } else {
          result += ", ${vietnameseNames[i]}";
        }
      }
      return result;
    }
  }

  static String _translateToVietnamese(String objectName) {
    if (objectName.isEmpty) return "vật thể";
    
    String name = objectName.toLowerCase().trim();
    
    final translations = {
      'person': 'người',
      'people': 'người',
      'man': 'đàn ông',
      'woman': 'phụ nữ',
      'child': 'trẻ em',
      'baby': 'em bé',
      
      'chair': 'ghế',
      'table': 'bàn',
      'bed': 'giường',
      'sofa': 'sofa',
      'desk': 'bàn làm việc',
      'shelf': 'kệ',
      'couch': 'ghế sofa',
      
      'tv': 'tivi',
      'television': 'tivi',
      'computer': 'máy tính',
      'laptop': 'laptop',
      'phone': 'điện thoại',
      'mobile': 'điện thoại di động',
      'tablet': 'máy tính bảng',
      'monitor': 'màn hình',
      'keyboard': 'bàn phím',
      'mouse': 'chuột',
      'remote': 'điều khiển từ xa',
      
      'bottle': 'chai',
      'cup': 'cốc',
      'glass': 'ly',
      'bowl': 'bát',
      'plate': 'đĩa',
      'spoon': 'thìa',
      'fork': 'nĩa',
      'knife': 'dao',
      
      'apple': 'táo',
      'banana': 'chuối',
      'orange': 'cam',
      'bread': 'bánh mì',
      'cake': 'bánh ngọt',
      'pizza': 'pizza',
      'water': 'nước',
      'coffee': 'cà phê',
      'tea': 'trà',
      'milk': 'sữa',
      'juice': 'nước ép',
      
      'car': 'ô tô',
      'bus': 'xe buýt',
      'truck': 'xe tải',
      'bike': 'xe đạp',
      'bicycle': 'xe đạp',
      'motorcycle': 'xe máy',
      
      'cat': 'mèo',
      'dog': 'chó',
      'bird': 'chim',
      'fish': 'cá',
      
      'shirt': 'áo sơ mi',
      'pants': 'quần',
      'shoes': 'giày',
      'hat': 'mũ',
      'bag': 'túi',
      'backpack': 'ba lô',
      'watch': 'đồng hồ',
      'glasses': 'kính',
      
      'door': 'cửa',
      'window': 'cửa sổ',
      'wall': 'tường',
      'ceiling': 'trần nhà',
      'floor': 'sàn nhà',
      'stairs': 'cầu thang',
      'light': 'đèn',
      'lamp': 'đèn bàn',
      
      'book': 'sách',
      'pen': 'bút',
      'pencil': 'bút chì',
      'paper': 'giấy',
      'notebook': 'vở',
    };
    
    return translations[name] ?? name;
  }

  static Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  static Future<void> pause() async {
    await _flutterTts.pause();
  }

  static bool get isSpeaking => _isSpeaking;
  static bool get isInitialized => _isInitialized;

  static Future<void> speakWithFallback(String text, BuildContext? context) async {
    try {
      await speak(text);
    } catch (e) {
      print("🚨 TTS Error: $e");
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            duration: Duration(seconds: 3),
          )
        );
      }
    }
  }

  static Future<void> _configureAudioSession() async {
    try {
      await _audioChannel.invokeMethod('configureAudioSession');
      print("✅ Audio session configured for Quest VR");
    } catch (e) {
      print("⚠️ Could not configure audio session: $e");
    }
  }
  
  static Future<Map<String, dynamic>?> testAudioSystem() async {
    try {
      Map<dynamic, dynamic> result = await _audioChannel.invokeMethod('testAudio');
      print("🔍 Audio test result: $result");
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print("🚨 Audio test failed: $e");
      return null;
    }
  }

  static Future<void> setOptimalVoiceForQuest() async {
    await initialize();
    
    try {
      List<Map> voices = await _flutterTts.getVoices;
      print("📢 Available voices: ${voices.length}");
      
      Map? bestVietnameseVoice;
      Map? fallbackVoice;
      
      for (var voice in voices) {
        String locale = voice['locale'] ?? '';
        String name = voice['name'] ?? '';
        
        if (locale.startsWith('vi')) {
          bestVietnameseVoice = voice;
          break;
        } else if (locale.startsWith('en') && fallbackVoice == null) {
          fallbackVoice = voice;
        }
      }
      
      if (bestVietnameseVoice != null) {
        await _flutterTts.setVoice(Map<String, String>.from(bestVietnameseVoice));
        print("✅ Set Vietnamese voice: ${bestVietnameseVoice['name']}");
      } else if (fallbackVoice != null) {
        await _flutterTts.setVoice(Map<String, String>.from(fallbackVoice));
        print("⚠️ Using fallback English voice: ${fallbackVoice['name']}");
      }
    } catch (e) {
      print("⚠️ Could not set specific voice: $e");
    }
  }
  
  static Future<void> testNativeTTS(String text) async {
    try {
      await initialize();
      print("🧪 Testing Native TTS...");
      
      bool success = await _nativeTTSChannel.invokeMethod('speak', {
        'text': text,
        'language': 'vi-VN'
      });
      
      print("🧪 Native TTS test result: $success");
    } catch (e) {
      print("🚨 Native TTS test error: $e");
    }
  }
  
  static Future<void> forceReset() async {
    try {
      print("🔄 Force resetting TTS...");
      _isSpeaking = false;
      await _flutterTts.stop();
      await _nativeTTSChannel.invokeMethod('stop');
      print("✅ TTS force reset completed");
    } catch (e) {
      print("⚠️ TTS force reset error: $e");
    }
  }
  
  static Future<void> testSimpleBeep() async {
    try {
      print("🔔 Testing simple beep...");
      await _audioChannel.invokeMethod('playBeep');
      print("✅ Beep test completed");
    } catch (e) {
      print("🚨 Simple beep test error: $e");
    }
  }
  
  static Future<void> testTone() async {
    try {
      print("🎵 Testing tone sound...");
      await _audioChannel.invokeMethod('playTone');
      print("✅ Tone test completed");
    } catch (e) {
      print("🚨 Tone test error: $e");
    }
  }
}