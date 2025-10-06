import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VietnameseTTSService {
  late FlutterTts _flutterTts;
  bool _isInitialized = false;
  
  VietnameseTTSService() {
    _initTTS();
  }
  
  Future<void> _initTTS() async {
    try {
      _flutterTts = FlutterTts();
      
      await _flutterTts.setLanguage("vi-VN");
      
      await _flutterTts.setSpeechRate(0.5);
      
      await _flutterTts.setVolume(0.8);
      
      await _flutterTts.setPitch(1.0);
      
      final voices = await _flutterTts.getVoices;
      debugPrint('🎤 Available voices: $voices');
      
      final vietnameseVoices = voices.where((voice) => 
          voice['locale'].toString().contains('vi') || 
          voice['name'].toString().toLowerCase().contains('vietnam')).toList();
      
      if (vietnameseVoices.isNotEmpty) {
        final selectedVoice = vietnameseVoices.first;
        await _flutterTts.setVoice({
          "name": selectedVoice['name'], 
          "locale": selectedVoice['locale']
        });
        debugPrint('✅ Selected Vietnamese voice: ${selectedVoice['name']}');
      }
      
      _isInitialized = true;
      debugPrint('✅ Vietnamese TTS initialized successfully');
      
    } catch (e) {
      debugPrint('❌ Error initializing Vietnamese TTS: $e');
    }
  }
  
  Future<bool> speak(String text, {
    double? speechRate,
    double? volume,
    double? pitch,
  }) async {
    try {
      if (!_isInitialized) {
        await _initTTS();
      }
      
      if (text.trim().isEmpty) {
        debugPrint('❌ Vietnamese TTS: Empty text provided');
        return false;
      }
      
      debugPrint('🎙️ Vietnamese TTS: Speaking: "$text"');
      
      if (speechRate != null) {
        await _flutterTts.setSpeechRate(speechRate.clamp(0.0, 1.0));
      }
      if (volume != null) {
        await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
      }
      if (pitch != null) {
        await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
      }
      
      final result = await _flutterTts.speak(text);
      
      if (result == 1) {
        debugPrint('✅ Vietnamese TTS: Speech completed successfully');
        return true;
      } else {
        debugPrint('❌ Vietnamese TTS: Speech failed with result: $result');
        return false;
      }
      
    } catch (e) {
      debugPrint('🚨 Vietnamese TTS: Exception occurred: $e');
      return false;
    }
  }
  
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      debugPrint('Vietnamese TTS: Stopped speaking');
    } catch (e) {
      debugPrint('Vietnamese TTS: Error stopping: $e');
    }
  }
  
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      debugPrint('Vietnamese TTS: Paused speaking');
    } catch (e) {
      debugPrint('Vietnamese TTS: Error pausing: $e');
    }
  }
  
  Future<bool> testTTS() async {
    debugPrint('🧪 Testing Vietnamese TTS...');
    final result = await speak(
      'Xin chào! Tôi là trợ lý AI thông minh của bạn. '
      'Tôi đang sử dụng giọng nói tiếng Việt thuần túy để giao tiếp với bạn. '
      'Hệ thống nhận diện đối tượng đã sẵn sàng hoạt động.'
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
    'door': 'cửa',
    'window': 'cửa sổ',
    'lamp': 'đèn',
    'light': 'đèn',
    'mirror': 'gương',
    'picture': 'tranh',
    'clock': 'đồng hồ',
    
    'phone': 'điện thoại',
    'cellphone': 'điện thoại di động',
    'smartphone': 'điện thoại thông minh',
    'laptop': 'máy tính xách tay',
    'computer': 'máy tính',
    'tablet': 'máy tính bảng',
    'television': 'ti vi',
    'tv': 'ti vi',
    'monitor': 'màn hình',
    'screen': 'màn hình',
    'keyboard': 'bàn phím',
    'mouse': 'chuột máy tính',
    'camera': 'máy ảnh',
    'remote': 'điều khiển',
    
    'apple': 'quả táo',
    'banana': 'quả chuối',
    'orange': 'quả cam',
    'grape': 'nho',
    'strawberry': 'dâu tây',
    'watermelon': 'dưa hấu',
    'rice': 'cơm',
    'bread': 'bánh mì',
    'cake': 'bánh ngọt',
    'pizza': 'pizza',
    'sandwich': 'bánh mì sandwich',
    'water': 'nước',
    'coffee': 'cà phê',
    'tea': 'trà',
    'milk': 'sữa',
    'juice': 'nước ép',
    
    'book': 'quyển sách',
    'pen': 'bút',
    'pencil': 'bút chì',
    'eraser': 'tẩy',
    'ruler': 'thước kẻ',
    'paper': 'giấy',
    'notebook': 'vở',
    'bag': 'túi xách',
    'backpack': 'ba lô',
    'wallet': 'ví tiền',
    
    'shirt': 'áo sơ mi',
    'pants': 'quần dài',
    'dress': 'váy',
    'shoes': 'giày',
    'hat': 'mũ',
    'glasses': 'kính mắt',
    'watch': 'đồng hồ đeo tay',
    'bag': 'túi xách',
    
    'cup': 'cốc',
    'glass': 'ly',
    'bottle': 'chai',
    'plate': 'đĩa',
    'bowl': 'bát',
    'spoon': 'muỗng',
    'fork': 'nĩa',
    'knife': 'dao',
    'chopsticks': 'đôi đũa',
    
    'ball': 'quả bóng',
    'toy': 'đồ chơi',
    'doll': 'búp bê',
    'game': 'trò chơi',
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
      return await speak('Tôi không thấy vật gì cả.');
    }
    
    if (objects.length == 1) {
      final vietnameseName = translateToVietnamese(objects.first);
      return await speak('Tôi thấy có một $vietnameseName.');
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
      'Chào bạn! Tôi sẵn sàng giúp đỡ bạn.',
      'Xin chào! Hôm nay tôi có thể hỗ trợ gì cho bạn?',
      'Chào mừng bạn! Tôi là trợ lý thông minh của bạn.',
    ];
    final greeting = greetings[DateTime.now().millisecond % greetings.length];
    return await speak(greeting);
  }
  
  Future<bool> announceCameraStatus(bool isActive) async {
    if (isActive) {
      return await speak('Camera đã được kích hoạt. Tôi có thể nhìn thấy những gì bạn đang quan sát.');
    } else {
      return await speak('Camera đã được tắt. Tôi không thể nhìn thấy gì.');
    }
  }
  
  Future<bool> announceError(String error) async {
    return await speak('Xin lỗi, đã xảy ra lỗi. Vui lòng thử lại sau.');
  }
  
  Future<bool> announceNoObjectsDetected() async {
    final messages = [
      'Tôi không thấy vật gì đặc biệt.',
      'Không có gì để báo cáo.',
      'Khu vực này trông trống trải.',
      'Tôi không phát hiện được vật thể nào.',
    ];
    final message = messages[DateTime.now().millisecond % messages.length];
    return await speak(message);
  }
  
  Future<bool> announceStartScanning() async {
    return await speak('Đang bắt đầu quét và nhận diện đối tượng.');
  }
  
  Future<bool> announceStopScanning() async {
    return await speak('Đã dừng quét đối tượng.');
  }
  
  Future<bool> announceInstructions() async {
    return await speak(
      'Hướng dẫn sử dụng: Di chuyển camera để tôi có thể nhìn thấy các vật thể xung quanh. '
      'Tôi sẽ mô tả những gì tôi nhận diện được bằng tiếng Việt.'
    );
  }
  
  void dispose() {
  }
}