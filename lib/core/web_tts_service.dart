import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebTTSService {
  static WebViewController? _controller;
  static bool _isInitialized = false;
  static bool _isSpeaking = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    print("🌐 Initializing Web TTS Service...");
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print("🌐 WebView loading progress: $progress%");
          },
          onPageStarted: (String url) {
            print("🌐 WebView page started: $url");
          },
          onPageFinished: (String url) {
            print("✅ Web TTS page loaded: $url");
            _waitForJavaScriptReady();
          },
          onHttpError: (HttpResponseError error) {
            print("🚨 Web TTS HTTP error: $error");
          },
          onWebResourceError: (WebResourceError error) {
            print("🚨 Web TTS resource error: $error");
          },
        ),
      );
    
    print("🌐 Loading TTS HTML...");
    await _controller!.loadHtmlString(_getTTSHtml());
    
    await Future.delayed(Duration(milliseconds: 2000));
    print("✅ Web TTS Service initialization completed");
  }
  
  static Future<void> _waitForJavaScriptReady() async {
    try {
      for (int i = 0; i < 10; i++) {
        try {
          await _controller!.runJavaScript("console.log('Testing JavaScript: ' + (typeof ttsSpeak))");
          Object result = await _controller!.runJavaScriptReturningResult("typeof ttsSpeak");
          if (result.toString().contains('function')) {
            print("✅ JavaScript TTS functions ready");
            _isInitialized = true;
            return;
          }
        } catch (e) {
          print("⚠️ JavaScript not ready yet, attempt ${i + 1}/10");
        }
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      print("⚠️ JavaScript functions not ready after 10 attempts");
      _isInitialized = true; 
    } catch (e) {
      print("🚨 Error checking JavaScript readiness: $e");
      _isInitialized = true;
    }
  }

  static String _getTTSHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TTS Service</title>
</head>
<body>
    <div id="status">TTS Ready</div>
    
    <script>
        console.log('🌐 Web TTS Script Loading...');
        
        let synth = window.speechSynthesis;
        let isSpeaking = false;
        
        // Initialize voices
        let voices = [];
        
        function loadVoices() {
            voices = synth.getVoices();
            console.log('📢 Available voices:', voices.length);
            
            // Find Vietnamese voice
            let vietnameseVoice = voices.find(voice => 
                voice.lang.startsWith('vi') || voice.name.toLowerCase().includes('vietnam')
            );
            
            if (vietnameseVoice) {
                console.log('✅ Vietnamese voice found:', vietnameseVoice.name);
            } else {
                console.log('⚠️ No Vietnamese voice, will use default');
            }
        }
        
        // Load voices when available
        if (synth.onvoiceschanged !== undefined) {
            synth.onvoiceschanged = loadVoices;
        }
        loadVoices();
        
        // TTS speak function
        function speak(text, lang = 'vi-VN') {
            return new Promise((resolve, reject) => {
                if (isSpeaking) {
                    console.log('⚠️ Already speaking, stopping previous');
                    synth.cancel();
                }
                
                console.log('🔊 Speaking:', text);
                
                let utterance = new SpeechSynthesisUtterance(text);
                utterance.lang = lang;
                utterance.rate = 0.8;
                utterance.pitch = 1.0;
                utterance.volume = 1.0;
                
                // Try to use Vietnamese voice
                let voice = voices.find(v => v.lang.startsWith('vi'));
                if (voice) {
                    utterance.voice = voice;
                    console.log('🎯 Using voice:', voice.name);
                } else {
                    console.log('⚠️ Using default voice');
                }
                
                utterance.onstart = function() {
                    isSpeaking = true;
                    console.log('🔊 TTS Started');
                    document.getElementById('status').innerHTML = 'Speaking...';
                };
                
                utterance.onend = function() {
                    isSpeaking = false;
                    console.log('✅ TTS Finished');
                    document.getElementById('status').innerHTML = 'TTS Ready';
                    resolve(true);
                };
                
                utterance.onerror = function(event) {
                    isSpeaking = false;
                    console.error('🚨 TTS Error:', event.error);
                    document.getElementById('status').innerHTML = 'TTS Error: ' + event.error;
                    reject(event.error);
                };
                
                // Speak
                synth.speak(utterance);
            });
        }
        
        // Stop function
        function stopSpeaking() {
            if (isSpeaking) {
                synth.cancel();
                isSpeaking = false;
                console.log('🛑 TTS Stopped');
            }
        }
        
        // Test function
        function testTTS() {
            speak('Xin chào, đây là thử nghiệm giọng nói từ Web Speech API');
        }
        
        // Make functions available globally
        window.ttsSpeak = speak;
        window.ttsStop = stopSpeaking;
        window.ttsTest = testTTS;
        window.ttsIsSpeaking = () => isSpeaking;
        
        console.log('✅ Web TTS Ready');
        document.getElementById('status').innerHTML = 'Web TTS Ready';
    </script>
</body>
</html>
    ''';
  }

  static Future<void> speak(String text) async {
    try {
      await initialize();
      
      if (!_isInitialized || _controller == null) {
        print("🚨 Web TTS not initialized");
        return;
      }
      
      if (text.isEmpty) {
        print("⚠️ Empty text provided to Web TTS");
        return;
      }
      
      print("🌐 Web TTS Speaking: $text");
      
      try {
        Object funcCheck = await _controller!.runJavaScriptReturningResult("typeof ttsSpeak");
        if (!funcCheck.toString().contains('function')) {
          print("⚠️ ttsSpeak function not ready, reinitializing...");
          await _reinitialize();
        }
      } catch (e) {
        print("⚠️ Cannot check function, reinitializing...");
        await _reinitialize();
      }
      
      String escapedText = text.replaceAll("'", "\\'").replaceAll('"', '\\"').replaceAll('\n', ' ');
      
      try {
        await _controller!.runJavaScript("console.log('Attempting to speak: $escapedText')");
        await _controller!.runJavaScript("if (typeof ttsSpeak === 'function') { ttsSpeak('$escapedText', 'vi-VN'); } else { console.error('ttsSpeak not available'); }");
        
        _isSpeaking = true;
        print("✅ Web TTS speak command sent");
        
        Future.delayed(Duration(seconds: 5), () {
          _isSpeaking = false;
        });
      } catch (jsError) {
        print("🚨 JavaScript execution error: $jsError");
        await _fallbackSpeak(text);
      }
      
    } catch (e) {
      print("🚨 Web TTS speak error: $e");
      _isSpeaking = false;
    }
  }
  
  static Future<void> _reinitialize() async {
    try {
      print("🔄 Reinitializing Web TTS...");
      _isInitialized = false;
      await _controller!.loadHtmlString(_getTTSHtml());
      await Future.delayed(Duration(milliseconds: 1000));
      await _waitForJavaScriptReady();
    } catch (e) {
      print("🚨 Reinitialize error: $e");
    }
  }
  
  static Future<void> _fallbackSpeak(String text) async {
    try {
      print("🔄 Using fallback Web TTS method...");
      
      String directJS = '''
        try {
          let synth = window.speechSynthesis;
          let utterance = new SpeechSynthesisUtterance('$text');
          utterance.lang = 'vi-VN';
          utterance.rate = 0.8;
          utterance.pitch = 1.0;
          utterance.volume = 1.0;
          synth.speak(utterance);
          console.log('Fallback TTS executed');
        } catch (e) {
          console.error('Fallback TTS error:', e);
        }
      ''';
      
      await _controller!.runJavaScript(directJS);
      print("✅ Fallback TTS executed");
    } catch (e) {
      print("🚨 Fallback TTS error: $e");
    }
  }

  static Future<void> stop() async {
    try {
      if (_controller != null) {
        await _controller!.runJavaScript("ttsStop()");
        _isSpeaking = false;
        print("🛑 Web TTS stopped");
      }
    } catch (e) {
      print("🚨 Web TTS stop error: $e");
    }
  }

  static Future<void> testSpeak() async {
    try {
      await initialize();
      if (_controller != null) {
        await _controller!.runJavaScript("ttsTest()");
        print("🧪 Web TTS test executed");
      }
    } catch (e) {
      print("🚨 Web TTS test error: $e");
    }
  }

  static bool get isSpeaking => _isSpeaking;
  static bool get isInitialized => _isInitialized;

  static Widget getWebView({double height = 100}) {
    if (_controller == null) {
      initialize();
      return Container(
        height: height,
        child: Center(
          child: Text("Initializing Web TTS..."),
        ),
      );
    }
    
    return SizedBox(
      height: height,
      child: WebViewWidget(controller: _controller!),
    );
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
}