import 'package:flutter/material.dart';
import 'package:ai_companion_vr_flutter/quest_frame_capture.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  String serverUrl = "ws://192.168.1.228:8000"; // API server IP address
  
  // Camera
  String? selectedCameraId;
  Map<String, dynamic>? cameraInfo;
  List<Map<String, dynamic>> availableCameras = [];
  
  // Object Detection Results
  List<Map<String, dynamic>> detectedObjects = [];
  String lastDescription = "";
  
  // Text-to-Speech
  FlutterTts? flutterTts;
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _initializeQuest3S();
  }

  @override
  void dispose() {
    _stopVisionCapture();
    _visionChannel?.sink.close();
    QuestFrameCapture.release();
    super.dispose();
  }

  Future<void> _initializeTTS() async {
    flutterTts = FlutterTts();
    await flutterTts?.setLanguage("vi-VN"); // Vietnamese
    await flutterTts?.setSpeechRate(0.8);
    await flutterTts?.setVolume(1.0);
    await flutterTts?.setPitch(1.0);
    
    flutterTts?.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty && !isSpeaking) {
      setState(() {
        isSpeaking = true;
      });
      await flutterTts?.speak(text);
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

        // Speak the description
        if (lastDescription.isNotEmpty) {
          _speak(lastDescription);
        }
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
    if (selectedCameraId == null || !isConnected) {
      setState(() {
        statusMessage = "❌ Need camera and WebSocket connection";
      });
      return;
    }

    setState(() {
      isCapturing = true;
      statusMessage = "🔥 AI Vision Active - Analyzing environment...";
    });

    captureTimer = Timer.periodic(Duration(milliseconds: 1000), (timer) async {
      final frame = await QuestFrameCapture.captureFrame();
      if (frame != null && mounted && isConnected) {
        setState(() {
          currentFrame = frame;
        });

        // Send frame to AI server (send base64 directly như API server expect)
        final base64Frame = base64Encode(frame);
        _visionChannel!.sink.add(base64Frame);
      }
    });
  }

  void _stopVisionCapture() {
    captureTimer?.cancel();
    captureTimer = null;
    setState(() {
      isCapturing = false;
      statusMessage = "🔥 Vision capture stopped";
    });
  }

  Future<void> _requestPermissions() async {
    final result = await QuestFrameCapture.requestPermissions();
    if (result != null && result['granted'] == true) {
      await _initializeQuest3S();
    }
  }

  Widget _buildDetectionResults() {
    if (detectedObjects.isEmpty && lastDescription.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Text(
          "👁️ AI Vision will analyze what you see...",
          style: TextStyle(color: Colors.white70, fontSize: 16),
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "🎯 AI Analysis:",
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  lastDescription,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        
        if (detectedObjects.isNotEmpty) ...[
          Text(
            "🔍 Detected Objects:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          ...detectedObjects.take(5).map((obj) {
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
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
            );
          }).toList(),
        ],
      ],
    );
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
        child: Padding(
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

              // Connection Status
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    isConnected ? "🔗 AI Server Connected" : "🔌 Disconnected",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Spacer(),
                  if (isSpeaking)
                    Row(
                      children: [
                        Icon(Icons.volume_up, color: Colors.blue, size: 16),
                        SizedBox(width: 4),
                        Text("🔊 Speaking...", style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                ],
              ),
              SizedBox(height: 16),

              // Camera Preview
              if (currentFrame != null) ...[
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        currentFrame!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Detection Results
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: _buildDetectionResults(),
                ),
              ),

              SizedBox(height: 16),

              // Controls
              Column(
                children: [
                  // Setup Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _requestPermissions,
                        icon: Icon(Icons.security),
                        label: Text("Permissions"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                      ElevatedButton.icon(
                        onPressed: !isConnected ? _connectWebSocket : null,
                        icon: Icon(Icons.wifi),
                        label: Text("Connect AI"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Vision Control Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: selectedCameraId != null && isConnected && !isCapturing 
                            ? _startVisionCapture : null,
                        icon: Icon(Icons.visibility),
                        label: Text("Start Vision"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                      ElevatedButton.icon(
                        onPressed: isCapturing ? _stopVisionCapture : null,
                        icon: Icon(Icons.stop),
                        label: Text("Stop"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ],
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