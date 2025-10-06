import 'package:flutter/material.dart';
import 'package:ai_companion_vr_flutter/quest_frame_capture.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:ai_companion_vr_flutter/tts_manager.dart';
import 'package:ai_companion_vr_flutter/core/openai_tts_service.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

class QuestVisionAssistant extends StatefulWidget {
  @override
  _QuestVisionAssistantState createState() => _QuestVisionAssistantState();
}

class _QuestVisionAssistantState extends State<QuestVisionAssistant> {
  Uint8List? currentFrame;
  String statusMessage = "🔥 Quest 3S Vision Assistant Ready";
  bool isCapturing = false;
  bool isConnected = false;
  Timer? captureTimer;
  
  // WebSocket
  WebSocketChannel? _visionChannel;
  String serverUrl = "ws://172.20.10.3:8000"; // API server IP address
  
  // Camera - Single camera với smooth display
  String? selectedCameraId;
  Map<String, dynamic>? cameraInfo;
  List<Map<String, dynamic>> availableCameras = [];
  
  // Camera frames - Tách display và processing
  Uint8List? displayFrame; // For UI display (smooth)
  Uint8List? processingFrame; // For AI processing (slower)
  
  // Frame counters để tối ưu
  int frameCount = 0;
  int aiProcessingInterval = 3; // Chỉ gửi AI mỗi 3 frames
  
  // Object Detection Results
  List<Map<String, dynamic>> detectedObjects = [];
  String lastDescription = "";
  
  // Text-to-Speech Manager
  final TTSManager _ttsManager = TTSManager.instance;
  bool isSpeaking = false;
  
  // TTS Throttling
  DateTime? lastTTSTime;
  String? lastSpokenContent;
  static const int TTS_COOLDOWN_SECONDS = 3; // Chỉ nói mỗi 3 giây

  @override
  void initState() {
    super.initState();
    print('🚀 Starting initState...');
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      print('🚀 Starting app initialization...');
      await _initializeTTSManager();
      await _initializeQuest3S();
      
      // Tự động thử connect (nhưng không chặn nếu lỗi)
      print('� Attempting auto-connect...');
      await Future.delayed(Duration(seconds: 1));
      try {
        await _connectWebSocket();
        print('✅ Auto-connect successful!');
        
        // Tự động start AI vision nếu connect thành công
        await Future.delayed(Duration(seconds: 1));
        if (isConnected && selectedCameraId != null) {
          print('🚀 Auto-starting vision capture...');
          await _startVisionCapture();
        }
      } catch (e) {
        print('⚠️ Auto-connect failed: $e. User can manually start.');
        setState(() {
          statusMessage = "⚠️ Auto-connect failed. Use Start button to begin.";
        });
      }
    } catch (e) {
      print('❌ Error in _initializeApp: $e');
      setState(() {
        statusMessage = "❌ Initialization error: $e";
      });
    }
  }

  @override
  void dispose() {
    _stopVisionCapture();
    _visionChannel?.sink.close();
    _ttsManager.dispose();
    QuestFrameCapture.release();
    super.dispose();
  }

  Future<void> _initializeTTSManager() async {
    try {
      print('🚀 Initializing TTS Manager...');
      await _ttsManager.initialize();
      print('✅ TTS Manager initialized: ${_ttsManager.getStatus()}');
    } catch (e) {
      print('❌ TTS Manager initialization failed: $e');
    }
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty && !isSpeaking) {
      setState(() {
        isSpeaking = true;
      });
      
      final success = await _ttsManager.speak(text);
      if (success) {
        // Wait for speaking to complete
        while (_ttsManager.isSpeaking) {
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
      
      setState(() {
        isSpeaking = false;
      });
    }
  }

  Future<void> _initializeQuest3S() async {
    setState(() {
      statusMessage = "🔥 Initializing Quest 3S...";
    });

    // Check permissions
    final permissions = await QuestFrameCapture.checkPermissions();
    if (permissions == null || permissions['granted'] != true) {
      setState(() {
        statusMessage = "❌ Need permissions - Click 'Request Permissions'";
      });
      return;
    }

    // Find passthrough camera
    final passthrough = await QuestFrameCapture.findPassthroughCamera();
    
    // List cameras
    final cameras = await QuestFrameCapture.listCameras();
    if (cameras != null) {
      setState(() {
        availableCameras = cameras;
      });
    }

    String? targetCamera;
    if (cameras != null) {
      for (var camera in cameras) {
        String id = camera['id'] as String;
        if (id == "50" || id == "51") {
          targetCamera = id;
          break;
        }
      }
    }

    if (targetCamera != null) {
      await _initializeCamera(targetCamera);
      
      setState(() {
        statusMessage = "✅ Quest 3S Camera $targetCamera ready for smooth AI vision!";
      });
    } else {
      setState(() {
        statusMessage = "⚠️ Quest 3S passthrough cameras (50/51) not found";
      });
    }
  }

  Future<void> _initializeCamera(String cameraId) async {
    final result = await QuestFrameCapture.initializeCamera(cameraId: cameraId);
    if (result != null) {
      setState(() {
        cameraInfo = result;
        selectedCameraId = cameraId;
      });
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      setState(() {
        statusMessage = "🔗 Connecting to AI Vision Server...";
      });

      print('🔗 Attempting to connect to: $serverUrl/ws/vision');
      
      _visionChannel = WebSocketChannel.connect(
        Uri.parse('$serverUrl/ws/vision'),
      );

      // Thiết lập listener
      _visionChannel!.stream.listen(
        (data) {
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          setState(() {
            isConnected = false;
            statusMessage = "❌ WebSocket error: $error";
          });
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
          setState(() {
            isConnected = false;
            statusMessage = "🔌 WebSocket disconnected";
          });
        },
      );

      // Chờ một chút để connection ổn định
      await Future.delayed(Duration(milliseconds: 500));
      
      // Send ping to test connection
      print('📤 Sending ping to test connection...');
      _visionChannel!.sink.add(json.encode({"type": "ping"}));
      
      // Chờ pong response trong 5 giây
      print('⏳ Waiting for pong response...');
      await Future.delayed(Duration(seconds: 2));
      
      // Giả định connection thành công nếu không có lỗi
      setState(() {
        isConnected = true;
        statusMessage = "✅ Connected to AI Vision Server!";
      });
      
      print('✅ WebSocket connection established successfully');

    } catch (e) {
      print('❌ Connection failed: $e');
      setState(() {
        isConnected = false;
        statusMessage = "❌ Failed to connect: $e";
      });
      rethrow;
    }
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      final message = json.decode(data);
      
      if (message['type'] == 'pong') {
        // Connection confirmed
        return;
      }
      
      if (message['type'] == 'detections') {
        setState(() {
          detectedObjects = List<Map<String, dynamic>>.from(message['objects'] ?? []);
          lastDescription = message['description'] ?? '';
        });

        // Speak with throttling logic
        print('🔊 Received detection data: description=${lastDescription.isNotEmpty}, objects=${detectedObjects.length}');
        print('🔊 TTS Manager status: ${_ttsManager.getStatus()}');
        
        _handleTTSWithThrottling();
      }
      
      if (message['type'] == 'error') {
        setState(() {
          statusMessage = "🚨 AI Error: ${message['message']}";
        });
      }
      
    } catch (e) {
      print("🚨 Error parsing WebSocket message: $e");
    }
  }

  Future<void> _startVisionCapture() async {
    print('🎥 Starting vision capture...');
    
    if (selectedCameraId == null) {
      print('❌ No camera selected');
      setState(() {
        statusMessage = "❌ No camera selected";
      });
      return;
    }
    
    if (!isConnected) {
      print('❌ Not connected to server');
      setState(() {
        statusMessage = "❌ Not connected to server";
      });
      return;
    }

    print('✅ Camera: $selectedCameraId, Connected: $isConnected');
    setState(() {
      isCapturing = true;
      statusMessage = "🔥 AI Vision Active - Analyzing environment...";
    });

    print('🎥 Starting single timer capture with frame optimization...');
    
    // Single timer để tránh conflict - 200ms interval
    captureTimer = Timer.periodic(Duration(milliseconds: 200), (timer) async {
      if (!isCapturing) {
        timer.cancel();
        return;
      }
      
      try {
        final frame = await QuestFrameCapture.captureFrame();
        if (frame != null && mounted) {
          // Luôn update UI để mượt
          setState(() {
            displayFrame = frame;
            currentFrame = frame;
          });
          
          // Chỉ gửi AI mỗi 5 frames (mỗi 1 giây)
          frameCount++;
          if (frameCount % 5 == 0 && isConnected) {
            processingFrame = frame;
            final base64Frame = base64Encode(frame);
            print('📤 Sending AI frame (${frame.length} bytes) - Count: $frameCount');
            _visionChannel!.sink.add(base64Frame);
          }
        }
      } catch (e) {
        print('❌ Capture error: $e');
        // Nếu có lỗi, thử reinitialize camera
        if (e.toString().contains('Session has been closed')) {
          print('🔄 Reinitializing camera due to session error...');
          await _initializeCamera(selectedCameraId!);
        }
      }
    });
    
    print('✅ Vision capture started successfully');
  }

  void _stopVisionCapture() {
    print('🛑 Stopping vision capture...');
    
    // Cancel timer trước
    captureTimer?.cancel();
    captureTimer = null;
    
    // Reset frame counter
    frameCount = 0;
    
    // Update state
    setState(() {
      isCapturing = false;
      statusMessage = "🔥 Vision capture stopped";
    });
    
    print('✅ Vision capture stopped successfully');
  }

  Future<void> _requestPermissions() async {
    final result = await QuestFrameCapture.requestPermissions();
    if (result != null && result['granted'] == true) {
      await _initializeQuest3S();
    }
  }

  void _handleTTSWithThrottling() {
    final now = DateTime.now();
    
    // Kiểm tra xem có đang phát âm thanh không
    if (_ttsManager.isSpeaking) {
      print('🔊 TTS is currently speaking, skipping...');
      return;
    }
    
    // Kiểm tra cooldown
    if (lastTTSTime != null) {
      final timeSinceLastTTS = now.difference(lastTTSTime!);
      if (timeSinceLastTTS.inSeconds < TTS_COOLDOWN_SECONDS) {
        print('🔊 TTS cooldown active (${timeSinceLastTTS.inSeconds}s), skipping...');
        return;
      }
    }
    
    String? contentToSpeak;
    
    // Quyết định nói gì
    if (lastDescription.isNotEmpty) {
      contentToSpeak = lastDescription;
    } else if (detectedObjects.isNotEmpty) {
      // Chỉ lấy vật thể có confidence cao
      final highConfidenceObjects = detectedObjects.where(
        (obj) => (obj['confidence'] ?? 0.0) > 0.7
      ).toList();
      
      if (highConfidenceObjects.isNotEmpty) {
        final objectNames = highConfidenceObjects.map((obj) => 
          OpenAITTSService.translateToVietnamese(obj['name'] as String)
        ).toSet().toList(); // Dùng Set để loại bỏ trùng lặp
        
        if (objectNames.length == 1) {
          contentToSpeak = 'Phát hiện ${objectNames.first}';
        } else {
          contentToSpeak = 'Phát hiện ${objectNames.join(', ')}';
        }
      }
    }
    
    // Kiểm tra xem nội dung có khác lần trước không
    if (contentToSpeak != null && contentToSpeak != lastSpokenContent) {
      print('🔊 Speaking new content: $contentToSpeak');
      lastTTSTime = now;
      lastSpokenContent = contentToSpeak;
      
      // Gọi TTS
      _speakContent(contentToSpeak);
    } else if (contentToSpeak == lastSpokenContent) {
      print('🔊 Content unchanged, skipping TTS');
    } else {
      print('🔊 No significant content to speak');
    }
  }
  
  Future<void> _speakContent(String content) async {
    try {
      final openaiTts = OpenAITTSService();
      final success = await openaiTts.speak(content);
      if (!success) {
        print('🔊 OpenAI TTS failed, trying local TTS...');
        await _ttsManager.speak(content);
      }
    } catch (e) {
      print('🔊 TTS Error: $e');
    }
  }

  Future<void> _testTTS() async {
    print('🎤 Testing TTS button pressed!');
    
    // Test OpenAI TTS directly
    try {
      final openaiTts = OpenAITTSService();
      print('🎤 Created OpenAI TTS service');
      final result = await openaiTts.testTTS();
      print('🎤 OpenAI TTS Test result: $result');
    } catch (e) {
      print('🎤 Direct OpenAI TTS Error: $e');
    }
    
    print('🎤 TTS Manager status: ${_ttsManager.getStatus()}');
    final result = await _ttsManager.testTTS();
    print('🎤 TTS Test result: $result');
  }

  Future<void> _startAIVision() async {
    print('🚀 Start AI Vision button pressed!');
    
    if (isCapturing) {
      // Stop vision if running
      _stopVisionCapture();
      return;
    }
    
    // Step 1: Connect to WebSocket if not connected
    if (!isConnected) {
      setState(() {
        statusMessage = "🔗 Connecting to AI server...";
      });
      
      try {
        await _connectWebSocket();
        if (!isConnected) {
          setState(() {
            statusMessage = "❌ Failed to connect to AI server";
          });
          return;
        }
      } catch (e) {
        setState(() {
          statusMessage = "❌ Connection error: $e";
        });
        return;
      }
    }
    
    // Step 2: Start vision capture
    if (selectedCameraId != null && isConnected) {
      await _startVisionCapture();
    } else {
      setState(() {
        statusMessage = "❌ Camera not ready or connection failed";
      });
    }
  }

  Widget _buildSmoothCameraView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.cyan.withOpacity(0.4), width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Main camera view
            Positioned.fill(
              child: Image.memory(
                currentFrame!,
                fit: BoxFit.cover,
              ),
            ),
            // Performance indicator
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isCapturing ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      "5 FPS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // AI processing indicator
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "🤖 AI: ${frameCount} frames",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionResults() {
    if (detectedObjects.isEmpty && lastDescription.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16), // Giảm padding để tối ưu không gian
        child: Text(
          "👁️ AI Vision is analyzing what you see...",
          style: TextStyle(color: Colors.white70, fontSize: 16), // Giảm font size
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lastDescription.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20), // Tăng padding
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12), // Bo tròn nhiều hơn
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "🎯 AI Analysis:",
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16), // Compact font
                ),
                SizedBox(height: 8), // Compact spacing
                Text(
                  lastDescription,
                  style: TextStyle(color: Colors.white, fontSize: 14), // Compact font
                ),
              ],
            ),
          ),
          SizedBox(height: 12), // Compact spacing
        ],
        
        if (detectedObjects.isNotEmpty) ...[
          Text(
            "🔍 Detected Objects:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), // Compact font
          ),
          SizedBox(height: 8), // Compact spacing
          ...detectedObjects.take(3).map((obj) { // Chỉ hiển thị 3 objects để tiết kiệm space
            return Container(
              margin: EdgeInsets.only(bottom: 8), // Compact margin
              padding: EdgeInsets.all(12), // Compact padding
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10), // Bo tròn nhiều hơn
              ),
              child: Row(
                children: [
                  Text(
                    "${obj['name'] ?? 'Unknown'}",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), // Compact font
                  ),
                  Spacer(),
                  Text(
                    "${((obj['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%",
                    style: TextStyle(color: Colors.green, fontSize: 12), // Compact font
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0), // Giảm padding để tối ưu không gian
          child: Column(
            children: [
              // Status - to hơn
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24), // Tăng padding
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusMessage,
                  style: TextStyle(color: Colors.white, fontSize: 20), // Tăng font size
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24), // Tăng spacing

              // Connection Status - to hơn
              Row(
                children: [
                  Container(
                    width: 16, // Tăng size indicator
                    height: 16,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    isConnected ? "🔗 AI + OpenAI TTS Ready" : "🔌 Disconnected",
                    style: TextStyle(color: Colors.white70, fontSize: 18), // Tăng font size
                  ),
                  Spacer(),
                  if (_ttsManager.isSpeaking)
                    Row(
                      children: [
                        Icon(Icons.volume_up, color: Colors.green, size: 20), // Tăng icon size
                        SizedBox(width: 6),
                        Text("🔊 OpenAI TTS...", style: TextStyle(color: Colors.green, fontSize: 16)),
                      ],
                    ),
                ],
              ),
              SizedBox(height: 24),

              // Camera Preview - Single smooth camera
              if (currentFrame != null) ...[
                Expanded(
                  flex: 4, // Camera chiếm 80% màn hình
                  child: _buildSmoothCameraView(),
                ),
                SizedBox(height: 16),
              ],

              // Detection Results - compact
              Expanded(
                flex: 1, // Giảm flex để camera chiếm nhiều không gian hơn
                child: SingleChildScrollView(
                  child: _buildDetectionResults(),
                ),
              ),

              SizedBox(height: 16),

              // Controls - Setup và Start buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Setup button
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        onPressed: _requestPermissions,
                        icon: Icon(Icons.settings, size: 24),
                        label: Text("Setup", style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Start button
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: ElevatedButton.icon(
                        onPressed: _startAIVision,
                        icon: Icon(
                          isCapturing ? Icons.stop : Icons.play_arrow, 
                          size: 24
                        ),
                        label: Text(
                          isCapturing ? "Stop AI" : "Start AI", 
                          style: TextStyle(fontSize: 18)
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCapturing ? Colors.red : Colors.green,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}