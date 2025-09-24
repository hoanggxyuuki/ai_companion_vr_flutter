import 'package:flutter/material.dart';
import 'package:ai_companion_vr_flutter/quest_frame_capture.dart';
import 'dart:typed_data';
import 'dart:async';

class Quest3SPassthroughTest extends StatefulWidget {
  @override
  _Quest3SPassthroughTestState createState() => _Quest3SPassthroughTestState();
}

class _Quest3SPassthroughTestState extends State<Quest3SPassthroughTest> {
  Uint8List? currentFrame;
  String statusMessage = "🔥 Quest 3S Passthrough Test Ready";
  bool isCapturing = false;
  Timer? captureTimer;
  List<Map<String, dynamic>> availableCameras = [];
  String? selectedCameraId;
  Map<String, dynamic>? cameraInfo;
  Map<String, dynamic>? permissionStatus;
  Map<String, dynamic>? passthroughInfo;

  @override
  void initState() {
    super.initState();
    _initializeQuest3S();
  }

  @override
  void dispose() {
    _stopCapture();
    QuestFrameCapture.release();
    super.dispose();
  }

  Future<void> _initializeQuest3S() async {
    setState(() {
      statusMessage = "🔥 Checking Quest 3S permissions...";
    });

    // Check permissions first
    final permissions = await QuestFrameCapture.checkPermissions();
    setState(() {
      permissionStatus = permissions;
    });

    if (permissions == null || permissions['granted'] != true) {
      setState(() {
        statusMessage = "❌ Missing permissions: ${permissions?['missing'] ?? 'Unknown'} - Click 'Request Permissions'";
      });
      return;
    }

    // Find passthrough camera
    setState(() {
      statusMessage = "🔥 Searching for Quest 3S passthrough camera...";
    });

    final passthrough = await QuestFrameCapture.findPassthroughCamera();
    setState(() {
      passthroughInfo = passthrough;
    });

    // List all cameras
    final cameras = await QuestFrameCapture.listCameras();
    if (cameras != null) {
      setState(() {
        availableCameras = cameras;
      });
    }

    // Auto-select passthrough camera if found
    if (passthrough != null && passthrough['found'] == true) {
      setState(() {
        selectedCameraId = passthrough['cameraId'];
        statusMessage = "✅ Quest 3S passthrough camera found: ${passthrough['cameraId']}";
      });
      await _initializeCamera(selectedCameraId);
    } else {
      setState(() {
        statusMessage = "⚠️ No Quest 3S passthrough camera found. Manual selection required.";
      });
    }
  }

  Future<void> _initializeCamera(String? cameraId) async {
    if (cameraId == null) return;

    setState(() {
      statusMessage = "🔥 Initializing Quest camera $cameraId...";
    });

    final result = await QuestFrameCapture.initializeCamera(cameraId: cameraId);
    if (result != null) {
      setState(() {
        cameraInfo = result;
        selectedCameraId = cameraId;
        statusMessage = result['isPassthrough'] == true 
            ? "✅ Quest 3S Passthrough Camera Ready!" 
            : "⚠️ Standard Camera (Not Passthrough)";
      });
    } else {
      setState(() {
        statusMessage = "❌ Failed to initialize camera $cameraId";
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      statusMessage = "🔥 Requesting Quest 3S permissions...";
    });

    final result = await QuestFrameCapture.requestPermissions();
    if (result != null && result['granted'] == true) {
      setState(() {
        statusMessage = "✅ Permissions granted! Initializing...";
        permissionStatus = {'granted': true};
      });
      await _initializeQuest3S();
    } else {
      setState(() {
        statusMessage = "❌ Permissions denied. App requires camera access.";
      });
    }
  }

  Future<void> _startCapture() async {
    if (selectedCameraId == null) {
      setState(() {
        statusMessage = "❌ No camera selected";
      });
      return;
    }

    setState(() {
      isCapturing = true;
      statusMessage = "🔥 Starting Quest 3S capture...";
    });

    captureTimer = Timer.periodic(Duration(milliseconds: 300), (timer) async {
      final frame = await QuestFrameCapture.captureFrame();
      if (frame != null && mounted) {
        setState(() {
          currentFrame = frame;
        });
      }
    });
  }

  void _stopCapture() {
    captureTimer?.cancel();
    captureTimer = null;
    setState(() {
      isCapturing = false;
      statusMessage = "🔥 Capture stopped";
    });
  }

  Widget _buildCameraSelector() {
    return Column(
      children: [
        Text("Available Cameras:", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        ...availableCameras.map((camera) {
          final id = camera['id'] as String;
          final facing = camera['facing'] as String;
          final isPassthrough = camera['isPassthrough'] == true;
          final resolutions = camera['supportedResolutions'] as List?;

          return Card(
            color: isPassthrough ? Colors.green.withOpacity(0.3) : null,
            child: ListTile(
              title: Text("Camera $id"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Facing: $facing"),
                  if (isPassthrough) Text("✅ QUEST 3S PASSTHROUGH", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  if (resolutions != null) Text("Resolutions: ${resolutions.take(3).join(', ')}"),
                ],
              ),
              trailing: selectedCameraId == id ? Icon(Icons.check, color: Colors.green) : null,
              onTap: () => _initializeCamera(id),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStatusInfo() {
    return Column(
      children: [
        // Permission Status
        if (permissionStatus != null) ...[
          Card(
            color: permissionStatus!['granted'] == true ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
            child: ListTile(
              title: Text("Permissions"),
              subtitle: Text(
                permissionStatus!['granted'] == true 
                    ? "✅ All permissions granted" 
                    : "❌ Missing: ${permissionStatus!['missing']?.join(', ')}"
              ),
            ),
          ),
          SizedBox(height: 8),
        ],

        // Passthrough Detection
        if (passthroughInfo != null) ...[
          Card(
            color: passthroughInfo!['found'] == true ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
            child: ListTile(
              title: Text("Quest 3S Passthrough Detection"),
              subtitle: Text(passthroughInfo!['message'] ?? 'Unknown'),
              trailing: passthroughInfo!['found'] == true ? Icon(Icons.check, color: Colors.green) : Icon(Icons.warning, color: Colors.orange),
            ),
          ),
          SizedBox(height: 8),
        ],

        // Current Camera Info
        if (cameraInfo != null) ...[
          Card(
            color: cameraInfo!['isPassthrough'] == true ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
            child: ListTile(
              title: Text("Current Camera: ${cameraInfo!['cameraId']}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Resolution: ${cameraInfo!['resolution']}"),
                  Text(cameraInfo!['isPassthrough'] == true ? "✅ Quest 3S Passthrough" : "⚠️ Standard Camera"),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🔥 Quest 3S Passthrough Test"),
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

              // Status Info
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: _buildStatusInfo(),
                ),
              ),

              // Camera Preview
              if (currentFrame != null) ...[
                SizedBox(height: 16),
                Expanded(
                  flex: 3,
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
              ],

              SizedBox(height: 16),

              // Controls
              Column(
                children: [
                  // Permission & Setup Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _requestPermissions,
                        icon: Icon(Icons.security),
                        label: Text("Request Permissions"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                      ElevatedButton.icon(
                        onPressed: _initializeQuest3S,
                        icon: Icon(Icons.refresh),
                        label: Text("Refresh"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Capture Control Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: selectedCameraId != null && !isCapturing ? _startCapture : null,
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
                ],
              ),

              SizedBox(height: 16),

              // Camera Selector
              if (availableCameras.isNotEmpty) ...[
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: _buildCameraSelector(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}