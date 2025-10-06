import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class OpenAITTSService {
  static const String _baseUrl = 'https://api.openai.com/v1/audio/speech';
  
  static const String _apiKey = 'apikey';
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  static const String _defaultVoice = 'alloy';
  
  static const String _defaultModel = 'gpt-4o-mini-tts';
  
  Future<bool> speak(String text, {
    String? voice,
    String? model,
    double speed = 1.0,
  }) async {
    try {
      debugPrint('🔊 OpenAI TTS: Starting speech synthesis');
      debugPrint('🔑 API Key starts with: ${_apiKey.substring(0, 10)}...');
      
      if (text.trim().isEmpty) {
        debugPrint('❌ OpenAI TTS: Empty text provided');
        return false;
      }
      
      debugPrint('🎙️ OpenAI TTS: Synthesizing text: "$text"');
      
      final improvedText = improveVietnamesePronunciation(text);
      debugPrint('🔧 Improved Vietnamese text: "$improvedText"');
      
      final Map<String, dynamic> payload = {
        'model': model ?? _defaultModel,
        'input': improvedText,
        'voice': voice ?? _defaultVoice,
        'response_format': 'mp3',
        'speed': speed.clamp(0.25, 4.0),
      };
      
      debugPrint('🚀 OpenAI TTS: Making HTTP request to $_baseUrl');
      debugPrint('📝 Payload: ${jsonEncode(payload)}');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(payload),
      );
      
      debugPrint('📊 OpenAI TTS: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        debugPrint('✅ OpenAI TTS: Received audio data');
        
        final Uint8List audioData = response.bodyBytes;
        debugPrint('🖻 Audio data size: ${audioData.length} bytes');
        
        final Directory tempDir = await getTemporaryDirectory();
        final String tempPath = '${tempDir.path}/openai_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(audioData);
        
        debugPrint('💾 File saved to: $tempPath');
        
        debugPrint('🎵 Playing audio...');
        await _audioPlayer.play(DeviceFileSource(tempPath));
        
        Future.delayed(const Duration(seconds: 10), () {
          if (tempFile.existsSync()) {
            tempFile.delete();
            debugPrint('🔄 Cleaned up temp file: $tempPath');
          }
        });
        
        debugPrint('✅ OpenAI TTS: Audio played successfully');
        return true;
        
      } else {
        debugPrint('❌ OpenAI TTS: HTTP Error ${response.statusCode}: ${response.body}');
        return false;
      }
      
    } catch (e) {
      debugPrint('🚨 OpenAI TTS: Exception occurred: $e');
      debugPrint('🚨 Stack trace: ${StackTrace.current}');
      return false;
    }
  }
  
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      debugPrint('OpenAI TTS: Audio stopped');
    } catch (e) {
      debugPrint('OpenAI TTS: Error stopping audio: $e');
    }
  }
  
  Future<bool> testTTS() async {
    debugPrint('🧪 🎤 Testing OpenAI TTS...');
    final result = await speak('Xin chào! Tôi là trợ lý AI thông minh của bạn. Hệ thống chuyển văn bản thành giọng nói đã sẵn sàng hoạt động.');
    debugPrint('🧪 Test result: $result');
    return result;
  }
  
  static const Map<String, String> vietnameseTranslations = {
    'person': 'người',
    'man': 'đàn ông',
    'woman': 'phụ nữ', 
    'child': 'trẻ em',
    'boy': 'con trai',
    'girl': 'con gái',
    'baby': 'em bé',
    'dog': 'con chó',
    'cat': 'con mèo',
    'bird': 'con chim',
    'fish': 'con cá',
    
    'car': 'ô tô',
    'bicycle': 'xe đạp',
    'motorbike': 'xe máy',
    'motorcycle': 'xe máy',
    'bus': 'xe buýt',
    'train': 'tàu hỏa',
    'truck': 'xe tải',
    'airplane': 'máy bay',
    'boat': 'thuyền',
    
    'chair': 'cái ghế',
    'table': 'cái bàn',
    'bed': 'giường ngủ',
    'sofa': 'ghế sô pha',
    'door': 'cửa ra vào',
    'window': 'cửa sổ',
    'lamp': 'đèn',
    'mirror': 'gương',
    
    'phone': 'điện thoại',
    'mobile': 'điện thoại di động',
    'laptop': 'máy tính xách tay', 
    'computer': 'máy tính',
    'television': 'ti vi',
    'tv': 'ti vi',
    'monitor': 'màn hình máy tính',
    'keyboard': 'bàn phím',
    'mouse': 'chuột máy tính',
    'remote': 'điều khiển từ xa',
    'camera': 'máy ảnh',
    
    'apple': 'quả táo',
    'banana': 'quả chuối',
    'orange': 'quả cam',
    'rice': 'cơm',
    'bread': 'bánh mì',
    'water': 'nước',
    'coffee': 'cà phê',
    'tea': 'trà',
    'milk': 'sữa',
    
    'book': 'quyển sách',
    'pen': 'bút',
    'pencil': 'bút chì',
    'bag': 'cái túi',
    'backpack': 'ba lô',
    'wallet': 'ví tiền',
    'watch': 'đồng hồ đeo tay',
    'clock': 'đồng hồ treo tường',
    'glasses': 'kính mắt',
    
    'cup': 'cái cốc',
    'glass': 'ly nước',
    'bottle': 'chai nước',
    'plate': 'đĩa ăn',
    'bowl': 'bát ăn',
    'spoon': 'thìa ăn',
    'knife': 'dao',
    'fork': 'nĩa',
  };
  
  static String translateToVietnamese(String englishName) {
    final translated = vietnameseTranslations[englishName.toLowerCase()];
    if (translated != null) {
      return translated;
    }
    
    return 'đồ vật';
  }
  
  static String improveVietnamesePronunciation(String text) {
    String improved = text;
    
    improved = improved.replaceAll('và', 'với');
    improved = improved.replaceAll('các', 'những');
    improved = improved.replaceAll('phát hiện', 'thấy có');
    improved = improved.replaceAll('vật thể', 'đồ vật');
    
    if (!improved.endsWith('.') && !improved.endsWith('!') && !improved.endsWith('?')) {
      improved += '.';
    }
    
    return improved;
  }
  
  Future<bool> announceDetectedObjects(List<String> objects) async {
    if (objects.isEmpty) {
      return await speak('Tôi không thấy vật thể nào cả.');
    }
    
    if (objects.length == 1) {
      final vietnameseName = translateToVietnamese(objects.first);
      return await speak('Tôi thấy có $vietnameseName.');
    }
    
    final vietnameseObjects = objects.map((obj) => translateToVietnamese(obj)).toList();
    
    if (objects.length == 2) {
      return await speak('Tôi thấy có ${vietnameseObjects[0]} và ${vietnameseObjects[1]}.');
    }
    
    final lastObject = vietnameseObjects.removeLast();
    final objectsList = vietnameseObjects.join(', ');
    return await speak('Tôi thấy có $objectsList và $lastObject.');
  }
  
  Future<bool> greetUser() async {
    final greetings = [
      'Xin chào! Tôi là trợ lý AI của bạn.',
      'Chào bạn! Tôi sẵn sàng hỗ trợ bạn.',
      'Xin chào! Hôm nay tôi có thể giúp gì cho bạn?',
    ];
    final greeting = greetings[DateTime.now().millisecond % greetings.length];
    return await speak(greeting);
  }
  
  Future<bool> announceCameraStatus(bool isActive) async {
    if (isActive) {
      return await speak('Camera đã được bật. Tôi có thể nhìn thấy những gì bạn đang nhìn.');
    } else {
      return await speak('Camera đã được tắt. Tôi không thể nhìn thấy gì cả.');
    }
  }
  
  Future<bool> announceError(String error) async {
    return await speak('Xin lỗi, đã có lỗi xảy ra. Vui lòng thử lại.');
  }
  
  Future<bool> announceNoObjectsDetected() async {
    final messages = [
      'Tôi không thấy vật gì đặc biệt.',
      'Không có gì để báo cáo.',
      'Tôi không phát hiện được vật thể nào.',
      'Khu vực này trống.',
    ];
    final message = messages[DateTime.now().millisecond % messages.length];
    return await speak(message);
  }
  
  void dispose() {
    _audioPlayer.dispose();
  }
}