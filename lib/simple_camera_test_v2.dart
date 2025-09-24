import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'quest_frame_capture.dart';

class SimpleCameraTest extends StatefulWidget {
  @override
  _SimpleCameraTestState createState() => _SimpleCameraTestState();
}

class _SimpleCameraTestState extends State<SimpleCameraTest> {
  Timer? _captureTimer;
  Uint8List? _latestFrame;
  String _status = "Starting camera test...";
  String _currentCameraId = "0";

  @override
  void initState() {
    super.initState();
    _testCamera("0"); 
  }

  Future<void> _testCamera(String cameraId) async {
    try {
      _captureTimer?.cancel();
      await QuestFrameCapture.release();
      
      setState(() {
        _status = "Testing Camera ID $cameraId...";
        _currentCameraId = cameraId;
        _latestFrame = null;
      });
      
      final result = await QuestFrameCapture.initializeCamera(cameraId: cameraId);
      
      if (result != null) {
        setState(() => _status = "Camera $cameraId ready! Capturing...");
        
        _captureTimer = Timer.periodic(Duration(milliseconds: 500), (_) async {
          final frame = await QuestFrameCapture.captureFrame();
          if (frame != null && mounted) {
            setState(() {
              _latestFrame = frame;
              _status = "Camera $cameraId - Frame: ${frame.length} bytes";
            });
          }
        });
      } else {
        setState(() => _status = "Failed to initialize Camera $cameraId");
      }
    } catch (e) {
      setState(() => _status = "Camera $cameraId error: $e");
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    QuestFrameCapture.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Quest 3S Camera Test', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _status,
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => _testCamera("0"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentCameraId == "0" ? Colors.green : Colors.grey,
                ),
                child: Text('Camera 0\n(Back)', textAlign: TextAlign.center),
              ),
              ElevatedButton(
                onPressed: () => _testCamera("1"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentCameraId == "1" ? Colors.green : Colors.grey,
                ),
                child: Text('Camera 1\n(Front)', textAlign: TextAlign.center),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _latestFrame != null 
                  ? Image.memory(
                      _latestFrame!, 
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, color: Colors.grey, size: 64),
                            SizedBox(height: 16),
                            Text(
                              'No camera feed',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
          ),
          
          Container(
            padding: EdgeInsets.all(16),
            child: Text(
              'Current: Camera $_currentCameraId\nTap buttons to switch cameras\nLook for REAL camera feed vs Avatar',
              style: TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}