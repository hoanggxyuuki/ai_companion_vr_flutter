import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class GeminiTTSService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
  
  static const String _apiKey = 'apikey';
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Future<bool> speak(String text, {
    String voiceName = 'Zephyr', 
    double temperature = 1.0,
  }) async {
    try {
      debugPrint('🔊 Gemini TTS: Starting Vietnamese speech synthesis');
      debugPrint('🔑 API Key configured');
        ``
      if (text.trim().isEmpty) {
        debugPrint('❌ Gemini TTS: Empty text provided');
        return false;
      }
      
      final vietnameseText = _optimizeVietnameseText(text);
      debugPrint('🎙️ Gemini TTS: Synthesizing Vietnamese text: "$vietnameseText"');
      
      final Map<String, dynamic> payload = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text": "Hãy đọc đoạn văn sau bằng giọng nói tiếng Việt tự nhiên, rõ ràng và thân thiện: $vietnameseText"
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": temperature,
          "responseModalities": ["AUDIO"],
          "speechConfig": {
            "voiceConfig": {
              "prebuiltVoiceConfig": {
                "voiceName": voiceName
              }
            }
          }
        }
      };
      
      debugPrint('🚀 Gemini TTS: Making HTTP request');
      
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      
      debugPrint('📊 Gemini TTS: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['candidates'] != null && 
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final part = responseData['candidates'][0]['content']['parts'][0];
          
          if (part['inlineData'] != null && part['inlineData']['data'] != null) {
            debugPrint('✅ Gemini TTS: Received audio data');
            
            final base64AudioData = part['inlineData']['data'];
            final mimeType = part['inlineData']['mimeType'] ?? 'audio/wav';
            final audioBytes = base64Decode(base64AudioData);
            
            debugPrint('🎵 Audio data size: ${audioBytes.length} bytes');
            debugPrint('🎵 MIME type: $mimeType');
            
            final processedAudio = _ensureWavFormat(audioBytes, mimeType);
            
            final Directory tempDir = await getTemporaryDirectory();
            final String tempPath = '${tempDir.path}/gemini_tts_${DateTime.now().millisecondsSinceEpoch}.wav';
            final File tempFile = File(tempPath);
            await tempFile.writeAsBytes(processedAudio);
            
            debugPrint('💾 Audio file saved to: $tempPath');
            
            debugPrint('🎵 Playing Vietnamese audio...');
            await _audioPlayer.play(DeviceFileSource(tempPath));
            
            Future.delayed(const Duration(seconds: 15), () {
              if (tempFile.existsSync()) {
                tempFile.delete();
                debugPrint('🔄 Cleaned up temp file: $tempPath');
              }
            });
            
            debugPrint('✅ Gemini TTS: Vietnamese audio played successfully');
            return true;
          }
        }
        
        debugPrint('❌ Gemini TTS: No audio data in response');
        debugPrint('Response: ${response.body}');
        return false;
        
      } else {
        debugPrint('❌ Gemini TTS: HTTP Error ${response.statusCode}: ${response.body}');
        return false;
      }
      
    } catch (e) {
      debugPrint('🚨 Gemini TTS: Exception occurred: $e');
      debugPrint('🚨 Stack trace: ${StackTrace.current}');
      return false;
    }
  }
  
  String _optimizeVietnameseText(String text) {
    String optimized = text;
    
    optimized = optimized.replaceAll('.', '. ');
    optimized = optimized.replaceAll(',', ', ');
    optimized = optimized.replaceAll('!', '! ');
    optimized = optimized.replaceAll('?', '? ');

    
    optimized = optimized.replaceAll(RegExp(r'\s+'), ' ');
    
    
    if (!optimized.endsWith('.') && !optimized.endsWith('!') && !optimized.endsWith('?')) {
      optimized += '.';
    }
    
    return optimized.trim();
  }
  
  Uint8List _ensureWavFormat(Uint8List audioData, String mimeType) {
    if (mimeType.contains('wav') || mimeType.contains('wave')) {
      return audioData;
    }
    

    return audioData;
  }
  
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      debugPrint('Gemini TTS: Audio stopped');
    } catch (e) {
      debugPrint('Gemini TTS: Error stopping audio: $e');
    }
  }
  
  Future<bool> testTTS() async {
    debugPrint('🧪 🎤 Testing Gemini Vietnamese TTS...');
    final result = await speak(
      'Xin chào! Tôi là trợ lý AI thông minh sử dụng công nghệ Gemini. '
      'Tôi có thể nói tiếng Việt rất tự nhiên và rõ ràng. '
      'Hệ thống nhận diện đối tượng đã sẵn sàng hoạt động để hỗ trợ bạn.',
      voiceName: 'Zephyr'
    );
    debugPrint('🧪 Vietnamese TTS test result: $result');
    return result;
  }
  
  static const Map<String, String> vietnameseTranslations = {
    'person': 'người',
    'man': 'đàn ông',
    'woman': 'phụ nữ',
    'child': 'trẻ em',
    'boy': 'cậu bé',
    'girl': 'cô bé',
    'baby': 'em bé',
    'dog': 'con chó',
    'cat': 'con mèo',
    'bird': 'con chim',
    'fish': 'con cá',
    'horse': 'con ngựa',
    'cow': 'con bò',
    'sheep': 'con cừu',
    
    'car': 'ô tô',
    'truck': 'xe tải',
    'bus': 'xe buýt',
    'bicycle': 'xe đạp',
    'motorbike': 'xe máy',
    'motorcycle': 'xe máy',
    'train': 'tàu hỏa',
    'airplane': 'máy bay',
    'boat': 'thuyền',
    'ship': 'tàu thủy',
    
    'chair': 'cái ghế',
    'table': 'cái bàn',
    'desk': 'bàn làm việc',
    'bed': 'giường ngủ',
    'sofa': 'ghế sofa',
    'couch': 'ghế sofa',
    'door': 'cửa',
    'window': 'cửa sổ',
    'lamp': 'đèn',
    'light': 'đèn',
    'mirror': 'gương soi',
    'picture': 'bức tranh',
    'clock': 'đồng hồ',
    
    'phone': 'điện thoại',
    'cellphone': 'điện thoại di động',
    'smartphone': 'điện thoại thông minh',
    'laptop': 'máy tính xách tay',
    'computer': 'máy tính',
    'tablet': 'máy tính bảng',
    'television': 'ti vi',
    'tv': 'ti vi',
    'monitor': 'màn hình máy tính',
    'screen': 'màn hình',
    'keyboard': 'bàn phím',
    'mouse': 'chuột máy tính',
    'camera': 'máy ảnh',
    'remote': 'điều khiển từ xa',
    
    'apple': 'quả táo',
    'banana': 'quả chuối',
    'orange': 'quả cam',
    'grape': 'nho',
    'strawberry': 'dâu tây',
    'watermelon': 'dưa hấu',
    'rice': 'cơm',
    'bread': 'bánh mì',
    'cake': 'bánh ngọt',
    'pizza': 'bánh pizza',
    'sandwich': 'bánh mì kẹp',
    'water': 'nước uống',
    'coffee': 'cà phê',
    'tea': 'nước trà',
    'milk': 'sữa',
    'juice': 'nước ép trái cây',
    
    'book': 'quyển sách',
    'pen': 'cây bút',
    'pencil': 'bút chì',
    'eraser': 'cục tẩy',
    'ruler': 'thước kẻ',
    'paper': 'giấy',
    'notebook': 'vở ghi chép',
    'bag': 'túi xách',
    'backpack': 'ba lô',
    'wallet': 'ví tiền',
    
    'shirt': 'áo sơ mi',
    't-shirt': 'áo thun',
    'pants': 'quần dài',
    'jeans': 'quần jean',
    'dress': 'váy đầm',
    'shoes': 'giày',
    'sneakers': 'giày thể thao',
    'hat': 'mũ',
    'cap': 'nón',
    'glasses': 'kính mắt',
    'sunglasses': 'kính râm',
    'watch': 'đồng hồ đeo tay',
    
    'cup': 'cái cốc',
    'mug': 'cốc uống nước',
    'glass': 'ly thủy tinh',
    'bottle': 'chai',
    'plate': 'đĩa ăn',
    'bowl': 'cái bát',
    'spoon': 'cái muỗng',
    'fork': 'cái nĩa',
    'knife': 'con dao',
    'chopsticks': 'đôi đũa',
    
    'ball': 'quả bóng',
    'football': 'bóng đá',
    'basketball': 'bóng rổ',
    'toy': 'đồ chơi',
    'doll': 'búp bê',
    'game': 'trò chơi',
    'puzzle': 'trò chơi ghép hình',
  };
  
  static String translateToVietnamese(String englishName) {
    final translated = vietnameseTranslations[englishName.toLowerCase()];
    if (translated != null) {
      return translated;
    }
    
    return 'đồ vật';
  }
  
  Future<bool> announceDetectedObjects(List<String> objects) async {
    if (objects.isEmpty) {
      return await speak('Tôi không thấy vật gì trong khu vực này cả.');
    }
    
    if (objects.length == 1) {
      final vietnameseName = translateToVietnamese(objects.first);
      return await speak('Tôi nhận diện được một $vietnameseName.');
    }
    
    final vietnameseObjects = objects.map((obj) => translateToVietnamese(obj)).toList();
    
    if (objects.length == 2) {
      return await speak('Tôi thấy có ${vietnameseObjects[0]} và ${vietnameseObjects[1]}.');
    }
    
    final lastObject = vietnameseObjects.removeLast();
    final objectsList = vietnameseObjects.join(', ');
    return await speak('Tôi nhận diện được $objectsList và $lastObject.');
  }
  
  Future<bool> greetUser() async {
    final greetings = [
      'Xin chào! Tôi là trợ lý AI thông minh của bạn.',
      'Chào bạn! Tôi sẵn sàng hỗ trợ bạn hôm nay.',
      'Xin chào! Tôi có thể giúp gì cho bạn?',
      'Chào mừng bạn! Tôi là trợ lý nhận diện đối tượng.',
      'Xin chào! Hôm nay tôi sẽ giúp bạn nhận diện các vật thể xung quanh.',
    ];
    final greeting = greetings[DateTime.now().millisecond % greetings.length];
    return await speak(greeting, voiceName: 'Zephyr');
  }
  
  Future<bool> announceCameraStatus(bool isActive) async {
    if (isActive) {
      return await speak(
        'Camera đã được kích hoạt thành công. Tôi có thể nhìn thấy những gì bạn đang quan sát.',
        voiceName: 'Sage'
      );
    } else {
      return await speak(
        'Camera đã được tắt. Tôi không thể nhìn thấy gì trong lúc này.',
        voiceName: 'Sage'
      );
    }
  }
  
  Future<bool> announceError(String error) async {
    return await speak(
      'Xin lỗi, đã xảy ra một lỗi trong hệ thống. Vui lòng kiểm tra lại và thử lần nữa.',
      voiceName: 'Puck'
    );
  }
  
  Future<bool> announceNoObjectsDetected() async {
    final messages = [
      'Tôi không thấy vật gì đặc biệt trong khu vực này.',
      'Không có đối tượng nào được phát hiện.',
      'Khu vực này trông khá trống trải.',
      'Tôi chưa nhận diện được vật thể nào.',
      'Hiện tại không có gì để báo cáo.',
    ];
    final message = messages[DateTime.now().millisecond % messages.length];
    return await speak(message, voiceName: 'Kore');
  }
  
  Future<bool> announceStartScanning() async {
    return await speak(
      'Đang bắt đầu quét và phân tích các đối tượng trong tầm nhìn.',
      voiceName: 'Zephyr'
    );
  }
  
  Future<bool> announceStopScanning() async {
    return await speak(
      'Đã dừng quá trình quét đối tượng.',
      voiceName: 'Zephyr'
    );
  }
  
  Future<bool> announceInstructions() async {
    return await speak(
      'Hướng dẫn sử dụng: Di chuyển camera xung quanh để tôi có thể quan sát và nhận diện các vật thể. '
      'Tôi sẽ mô tả bằng tiếng Việt những gì tôi nhìn thấy một cách chi tiết và rõ ràng.',
      voiceName: 'Sage'
    );
  }
  
  Future<bool> announceDetectionDetails(String objectName, double confidence) async {
    final vietnameseName = translateToVietnamese(objectName);
    final confidencePercent = (confidence * 100).round();
    
    return await speak(
      'Tôi nhận diện được $vietnameseName với độ chính xác $confidencePercent phần trăm.',
      voiceName: 'Kore'
    );
  }
  
  void dispose() {
    _audioPlayer.dispose();
  }
}