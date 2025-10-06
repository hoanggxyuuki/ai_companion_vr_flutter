import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'dart:async';

class STTService {
  static final SpeechToText _speechToText = SpeechToText();
  static bool _speechEnabled = false;
  static bool _isListening = false;
  static String _lastWords = '';
  static Timer? _timeoutTimer;
  static StreamController<String>? _resultController;

  static Future<bool> initialize() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: true,
      );
      
      if (_speechEnabled) {
        print("✅ STT Service initialized for Quest 3S");
      } else {
        print("❌ STT Service failed to initialize");
      }
      
      return _speechEnabled;
    } catch (e) {
      print("🚨 STT Initialize error: $e");
      return false;
    }
  }

  static Future<void> startListening({
    Function(String)? onResult,
    Function(String)? onPartialResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
  }) async {
    if (!_speechEnabled) {
      print("⚠️ Speech recognition not available");
      return;
    }

    if (_isListening) {
      print("⚠️ Already listening");
      return;
    }

    try {
      _resultController = StreamController<String>.broadcast();
      
      if (onResult != null) {
        _resultController!.stream.listen(onResult);
      }

      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastWords = result.recognizedWords;
          
          if (result.finalResult) {
            print("🎤 Final result: $_lastWords");
            _resultController?.add(_lastWords);
          } else if (onPartialResult != null) {
            print("🎤 Partial result: $_lastWords");
            onPartialResult(_lastWords);
          }
        },
        listenFor: listenFor ?? Duration(seconds: 30),
        pauseFor: pauseFor ?? Duration(seconds: 3),
        partialResults: true,
        localeId: localeId ?? 'vi-VN',
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );

      _isListening = true;
      print("🎤 Started listening...");

      _timeoutTimer = Timer(listenFor ?? Duration(seconds: 30), () {
        if (_isListening) {
          stopListening();
          print("⏰ Listening timeout");
        }
      });

    } catch (e) {
      print("🚨 STT Listen error: $e");
      _isListening = false;
    }
  }

  static Future<void> stopListening() async {
    try {
      await _speechToText.stop();
      _isListening = false;
      _timeoutTimer?.cancel();
      _resultController?.close();
      _resultController = null;
      print("🎤 Stopped listening");
    } catch (e) {
      print("🚨 STT Stop error: $e");
    }
  }

  static Future<void> cancel() async {
    try {
      await _speechToText.cancel();
      _isListening = false;
      _timeoutTimer?.cancel();
      _resultController?.close();
      _resultController = null;
      print("🎤 Cancelled listening");
    } catch (e) {
      print("🚨 STT Cancel error: $e");
    }
  }

  static void _onStatus(String status) {
    print("🎤 STT Status: $status");
    
    switch (status) {
      case 'listening':
        _isListening = true;
        break;
      case 'notListening':
      case 'done':
        _isListening = false;
        _timeoutTimer?.cancel();
        break;
    }
  }

  static void _onError(dynamic error) {
    print("🚨 STT Error: $error");
    _isListening = false;
    _timeoutTimer?.cancel();
  }

  static bool get isListening => _speechToText.isListening;
  static bool get isAvailable => _speechEnabled;
  static bool get hasError => _speechToText.hasError;
  static String get lastWords => _lastWords;

  static Future<List<LocaleName>> getAvailableLocales() async {
    if (!_speechEnabled) {
      return [];
    }
    
    try {
      return await _speechToText.locales();
    } catch (e) {
      print("🚨 Error getting locales: $e");
      return [];
    }
  }

  static Future<bool> isVietnameseSupported() async {
    List<LocaleName> locales = await getAvailableLocales();
    return locales.any((locale) => locale.localeId.startsWith('vi'));
  }

  static bool isVoiceCommand(String text) {
    String lowerText = text.toLowerCase().trim();
    
    List<String> commands = [
      'bắt đầu', 'dừng', 'dừng lại', 'tắt', 'mở',
      'chụp ảnh', 'quay video', 'kết nối', 'ngắt kết nối',
      'tăng âm', 'giảm âm', 'im lặng',
      
      'start', 'stop', 'pause', 'resume', 'capture',
      'connect', 'disconnect', 'volume up', 'volume down',
      'mute', 'unmute', 'help', 'exit',
    ];
    
    return commands.any((cmd) => lowerText.contains(cmd));
  }

  static String processVoiceCommand(String text) {
    String lowerText = text.toLowerCase().trim();
    
    if (lowerText.contains('bắt đầu') || lowerText.contains('start')) {
      return 'START_VISION';
    } else if (lowerText.contains('dừng') || lowerText.contains('stop')) {
      return 'STOP_VISION';
    } else if (lowerText.contains('chụp ảnh') || lowerText.contains('capture')) {
      return 'CAPTURE_FRAME';
    } else if (lowerText.contains('kết nối') || lowerText.contains('connect')) {
      return 'CONNECT_SERVER';
    } else if (lowerText.contains('ngắt kết nối') || lowerText.contains('disconnect')) {
      return 'DISCONNECT_SERVER';
    } else if (lowerText.contains('tăng âm') || lowerText.contains('volume up')) {
      return 'VOLUME_UP';
    } else if (lowerText.contains('giảm âm') || lowerText.contains('volume down')) {
      return 'VOLUME_DOWN';
    } else if (lowerText.contains('im lặng') || lowerText.contains('mute')) {
      return 'MUTE';
    } else if (lowerText.contains('help') || lowerText.contains('trợ giúp')) {
      return 'HELP';
    }
    
    return 'UNKNOWN_COMMAND';
  }

  static Future<bool> initializeWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        bool result = await initialize();
        if (result) return true;
      } catch (e) {
        print("🔄 STT init attempt ${i + 1} failed: $e");
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2));
        }
      }
    }
    return false;
  }

  static Future<void> optimizeForQuest() async {
    if (!_speechEnabled) return;
    
    try {
      List<LocaleName> locales = await getAvailableLocales();
      print("📢 Available locales: ${locales.map((l) => l.localeId).join(', ')}");
      
      String preferredLocale = 'vi-VN';
      bool hasVietnamese = locales.any((l) => l.localeId.startsWith('vi'));
      
      if (!hasVietnamese) {
        preferredLocale = 'en-US';
        print("⚠️ Vietnamese not supported, using English");
      } else {
        print("✅ Vietnamese locale available");
      }
      
    } catch (e) {
      print("⚠️ Could not optimize STT for Quest: $e");
    }
  }

  static Future<void> dispose() async {
    await stopListening();
    _timeoutTimer?.cancel();
    _resultController?.close();
    _resultController = null;
  }
}