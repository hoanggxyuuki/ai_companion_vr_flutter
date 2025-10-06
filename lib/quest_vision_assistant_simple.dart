import 'package:flutter/material.dart';
import 'package:ai_companion_vr_flutter/quest_frame_capture.dart';
import 'package:ai_companion_vr_flutter/core/tts_service.dart';
import 'package:ai_companion_vr_flutter/core/stt_service.dart';
import 'package:ai_companion_vr_flutter/core/web_tts_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
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
  String serverUrl = "ws://172.20.10.3:8000";
  
  // Camera
  String? selectedCameraId;
  Map<String, dynamic>? cameraInfo;
  List<Map<String, dynamic>> availableCameras = [];
  
  // Detection results
  List<Map<String, dynamic>> detectedObjects = [];
  String lastDescription = "";

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    captureTimer?.cancel();
    _visionChannel?.sink.close();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    setState(() {
      statusMessage = "🔄 Initializing services...";
    });

    try {
      // Initialize TTS and STT services
      await TTSService.initialize();
      await STTService.initialize(); 
      await WebTTSService.initialize();
      print("✅ Voice services initialized");
      
      // Test TTS immediately
      await Future.delayed(Duration(milliseconds: 500));
      try {
        print("🔊 Testing TTS initialization...");
        await TTSService.speak("Hệ thống giọng nói đã sẵn sàng");
      } catch (e) {
        print("⚠️ TTS test failed: $e");
      }

      setState(() {
        statusMessage = "✅ Services initialized - Ready for Quest 3S!";
      });
    } catch (e) {
      setState(() {
        statusMessage = "❌ Service initialization failed: $e";
      });
    }
  }

  Future<void> _startCapture() async {
    if (selectedCameraId == null) {
      setState(() {
        statusMessage = "❌ No camera selected - Please request permissions first";
      });
      return;
    }

    setState(() {
      isCapturing = true;
      statusMessage = "🔥 Starting AI vision capture...";
    });

    captureTimer = Timer.periodic(Duration(milliseconds: 1000), (timer) async {
      try {
        final frame = await QuestFrameCapture.captureFrame();
        if (frame != null) {
          print("🔥 Quest Camera: Frame captured - ${frame.length} bytes");
          setState(() {
            currentFrame = frame;
          });
          
          // Send to AI server
          if (isConnected && _visionChannel != null) {
            _visionChannel!.sink.add(frame);
          }
        }
      } catch (e) {
        print("🚨 Capture error: $e");
      }
    });
  }

  void _stopCapture() {
    captureTimer?.cancel();
    setState(() {
      isCapturing = false;
      statusMessage = "⏹️ Capture stopped";
    });
  }

  Future<void> _requestPermissions() async {
    setState(() {
      statusMessage = "📋 Requesting Quest 3S permissions...";
    });

    try {
      final result = await QuestFrameCapture.requestPermissions();
      if (result != null && result['granted'] == true) {
        setState(() {
          statusMessage = "✅ Permissions granted!";
        });
        await _setupCamera();
      } else {
        setState(() {
          statusMessage = "❌ Permissions denied - Cannot access Quest cameras";
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "❌ Permission request failed: $e";
      });
    }
  }

  Future<void> _setupCamera() async {
    setState(() {
      statusMessage = "🔍 Setting up Quest 3S cameras...";
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

    // Try to use camera 50 or 51 (Quest 3S passthrough cameras)
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
        statusMessage = "✅ Quest 3S Camera $targetCamera ready for AI vision!";
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

      _visionChannel = WebSocketChannel.connect(
        Uri.parse('$serverUrl/ws/vision'),
      );

      _visionChannel!.stream.listen(
        (data) {
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          setState(() {
            isConnected = false;
            statusMessage = "❌ WebSocket error: $error";
          });
        },
        onDone: () {
          setState(() {
            isConnected = false;
            statusMessage = "🔌 WebSocket disconnected";
          });
        },
      );

      // Send ping to establish connection
      _visionChannel!.sink.add(json.encode({"type": "ping"}));
      
      setState(() {
        isConnected = true;
        statusMessage = "✅ Connected to AI Vision Server!";
      });

    } catch (e) {
      setState(() {
        isConnected = false;
        statusMessage = "❌ Failed to connect: $e";
      });
    }
  }

  void _handleWebSocketMessage(dynamic data) async {
    try {
      final message = json.decode(data);
      
      if (message['type'] == 'detection_result') {
        setState(() {
          detectedObjects = List<Map<String, dynamic>>.from(message['objects'] ?? []);
          lastDescription = message['description'] ?? "";
        });
        
        print("🎯 AI Detection result: $lastDescription");
        print("🎯 Objects detected: ${detectedObjects.length}");

        // Speak the detection results using Web TTS
        try {
          if (lastDescription.isNotEmpty) {
            print("🔊 Attempting to speak with Web TTS: $lastDescription");
            await WebTTSService.speak(lastDescription);
            print("✅ Web TTS completed for description");
          } else if (detectedObjects.isNotEmpty) {
            print("🔊 Attempting to speak multiple detections with Web TTS");
            await WebTTSService.speakMultipleDetections(detectedObjects);
            print("✅ Web TTS completed for multiple detections");
          } else {
            print("⚠️ No description or objects to speak");
          }
        } catch (ttsError) {
          print("🚨 TTS Error: $ttsError");
          // Fallback: show snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(lastDescription.isNotEmpty ? lastDescription : "Detection completed"),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      print("🚨 WebSocket message error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🔥 Quest 3S Vision Assistant"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Status
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusMessage,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              
              // Camera Preview
              if (currentFrame != null)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      currentFrame!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              SizedBox(height: 16),
              
              // Main Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _requestPermissions,
                    icon: Icon(Icons.security),
                    label: Text("Permissions"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                  ElevatedButton.icon(
                    onPressed: isConnected ? null : _connectWebSocket,
                    icon: Icon(Icons.wifi),
                    label: Text("Connect AI"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // Capture Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: isCapturing ? null : _startCapture,
                    icon: Icon(Icons.play_arrow),
                    label: Text("Start"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  ElevatedButton.icon(
                    onPressed: isCapturing ? _stopCapture : null,
                    icon: Icon(Icons.stop),
                    label: Text("Stop"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // TTS Test Buttons
              Text("🔊 TTS Tests", style: TextStyle(color: Colors.white, fontSize: 18)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await TTSService.testSimpleBeep();
                      } catch (e) {
                        print("🚨 Beep test error: $e");
                      }
                    },
                    icon: Icon(Icons.notifications),
                    label: Text("Test Beep"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await WebTTSService.testSpeak();
                      } catch (e) {
                        print("🚨 Web TTS test error: $e");
                      }
                    },
                    icon: Icon(Icons.web),
                    label: Text("Web TTS"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // Web TTS Area
              Container(
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: WebTTSService.getWebView(height: 80),
              ),
              SizedBox(height: 16),
              
              // Detection Results
              if (detectedObjects.isNotEmpty) ...[
                Text("🎯 Detected Objects:", style: TextStyle(color: Colors.white, fontSize: 16)),
                ...detectedObjects.map((obj) => Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "${obj['name'] ?? 'Unknown'}",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Spacer(),
                      Text(
                        "${((obj['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%",
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}