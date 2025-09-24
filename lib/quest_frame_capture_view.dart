import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'quest_frame_capture.dart';

class QuestFrameCaptureView extends StatefulWidget {
  @override
  _QuestFrameCaptureViewState createState() => _QuestFrameCaptureViewState();
}

class _QuestFrameCaptureViewState extends State<QuestFrameCaptureView> {
  Timer? _captureTimer;
  Uint8List? _latestFrame;
  String _status = "Initializing Quest camera...";
  bool _isInitialized = false;
  int _frameCount = 0;
  DateTime? _lastCaptureTime;
  List<Map<String, dynamic>>? _availableCameras;
  String? _selectedCameraId;

  @override
  void initState() {
    super.initState();
    _initializeQuestCamera();
  }

  Future<void> _initializeQuestCamera() async {
    try {
      setState(() => _status = "Getting available cameras...");
      
      // List available cameras first
      try {
        _availableCameras = await QuestFrameCapture.listCameras();
        print('🎥 Debug: Available cameras: $_availableCameras');
      } catch (e) {
        print('🎥 Debug: Error listing cameras: $e');
        setState(() => _status = "Error listing cameras: $e");
        return;
      }
      
      if (_availableCameras != null && _availableCameras!.isNotEmpty) {
        setState(() {
          _status = "Found ${_availableCameras!.length} cameras. Connecting...";
        });
        
        // Try back camera first, then front camera
        Map<String, dynamic>? backCamera;
        Map<String, dynamic>? frontCamera;
        
        for (var cam in _availableCameras!) {
          if (cam['facing'] == 'back') backCamera = cam;
          if (cam['facing'] == 'front') frontCamera = cam;
        }
        
        _selectedCameraId = backCamera?['id'] ?? frontCamera?['id'] ?? _availableCameras!.first['id'];
        
        setState(() => _status = "Connecting to camera $_selectedCameraId (${backCamera != null ? 'back' : 'front'})...");
        
        try {
          final result = await QuestFrameCapture.initializeCamera(cameraId: _selectedCameraId);
          
          if (result != null) {
            setState(() {
              _status = "Quest camera ready! Using camera $_selectedCameraId - Starting capture...";
              _isInitialized = true;
            });
            
            // Start periodic capture every 200ms (5 FPS)
            _startPeriodicCapture();
          } else {
            setState(() => _status = "Failed to initialize camera $_selectedCameraId");
          }
        } catch (e) {
          print('🎥 Debug: Camera init error: $e');
          setState(() => _status = "Camera init error: $e");
        }
      } else {
        setState(() => _status = "No cameras found on Quest 3S");
      }
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  void _startPeriodicCapture() {
    _captureTimer = Timer.periodic(Duration(milliseconds: 200), (_) async {
      if (!mounted) return;
      
      try {
        final frame = await QuestFrameCapture.captureFrame();
        
        if (frame != null && mounted) {
          setState(() {
            _latestFrame = frame;
            _frameCount++;
            _lastCaptureTime = DateTime.now();
            _status = "Quest Camera Active - Frame #$_frameCount (${frame.length} bytes)";
          });
        }
      } catch (e) {
        print('🎥 Frame capture failed: $e');
        if (mounted) {
          setState(() => _status = "Frame capture error: $e");
        }
      }
    });
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    QuestFrameCapture.closeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Quest 3S Frame Capture', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isInitialized ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isInitialized ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            SizedBox(height: 20),
            
            // Frame Display
            Container(
              width: double.infinity,
              height: 400,
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
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _isInitialized 
                              ? CircularProgressIndicator(color: Colors.white)
                              : Icon(Icons.camera_alt, color: Colors.grey, size: 64),
                            SizedBox(height: 16),
                            Text(
                              _isInitialized ? 'Waiting for first frame...' : 'Camera not ready',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Debug Info
            if (_isInitialized)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue, width: 1),
                ),
                child: Column(
                  children: [
                    Text('📊 Debug Info', 
                         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('✅ Frames Captured: $_frameCount', 
                         style: TextStyle(color: Colors.white)),
                    if (_lastCaptureTime != null)
                      Text('✅ Last Capture: ${_lastCaptureTime!.toString().split('.')[0]}', 
                           style: TextStyle(color: Colors.white)),
                    Text('✅ Capture Rate: ~5 FPS (200ms interval)', 
                         style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            
            SizedBox(height: 20),
            
            // Camera Selection
            if (_availableCameras != null && _availableCameras!.length > 1)
              Container(
                margin: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _availableCameras!.map((camera) {
                    final cameraId = camera['id']?.toString() ?? 'unknown';
                    final facing = camera['facing']?.toString() ?? 'unknown';
                    final isSelected = cameraId == _selectedCameraId;
                    return ElevatedButton(
                      onPressed: isSelected ? null : () => _switchCamera(cameraId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? Colors.green : Colors.grey,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text(
                        'Camera $cameraId\n($facing)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
            
            // Manual Capture Button
            ElevatedButton(
              onPressed: _isInitialized ? _manualCapture : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                'Manual Capture',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchCamera(String cameraId) async {
    try {
      setState(() {
        _status = "Switching to camera $cameraId...";
        _isInitialized = false;
      });
      
      _captureTimer?.cancel();
      await QuestFrameCapture.closeCamera();
      
      final result = await QuestFrameCapture.initializeCamera(cameraId: cameraId);
      
      if (result != null) {
        setState(() {
          _selectedCameraId = cameraId;
          _isInitialized = true;
          _frameCount = 0;
          _status = "Switched to camera $cameraId - Starting capture...";
        });
        
        _startPeriodicCapture();
      } else {
        setState(() => _status = "Failed to switch to camera $cameraId");
      }
    } catch (e) {
      setState(() => _status = "Camera switch error: $e");
    }
  }

  Future<void> _manualCapture() async {
    try {
      final frame = await QuestFrameCapture.captureFrame();
      if (frame != null && mounted) {
        setState(() {
          _latestFrame = frame;
          _frameCount++;
          _status = "Manual capture successful - ${frame.length} bytes";
        });
      }
    } catch (e) {
      setState(() => _status = "Manual capture failed: $e");
    }
  }
}