import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class SimpleCameraTest extends StatefulWidget {
  @override
  _SimpleCameraTestState createState() => _SimpleCameraTestState();
}

class _SimpleCameraTestState extends State<SimpleCameraTest> {
  CameraController? _controller;
  bool _isInitialized = false;
  String _status = "Initializing...";
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      print('🥽 Starting camera initialization...');
      setState(() => _status = "Getting available cameras...");
      
      _cameras = await availableCameras();
      print('🥽 Available cameras: ${_cameras.length}');
      
      for (int i = 0; i < _cameras.length; i++) {
        print('🥽 Camera $i: ${_cameras[i].name}, direction: ${_cameras[i].lensDirection}');
      }
      
      if (_cameras.isEmpty) {
        setState(() => _status = "❌ No cameras found!");
        return;
      }

      // Use first available camera (Quest 3S should have cameras)
      final selectedCamera = _cameras.first;
      print('🥽 Using camera: ${selectedCamera.name}');

      setState(() => _status = "Creating camera controller...");

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.low, // Use low resolution first
        enableAudio: false,
      );

      setState(() => _status = "Initializing camera...");
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _status = "✅ Camera ready!";
        });
        print('🥽 Camera initialized successfully!');
      }

    } catch (e) {
      print('🥽 Camera initialization error: $e');
      setState(() => _status = "❌ Error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Full screen app for Quest 3S
    if (_isInitialized && _controller != null) {
      return Scaffold(
        body: Stack(
          children: [
            // Full screen camera preview
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: CameraPreview(_controller!),
            ),
            
            // Status overlay
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🥽 Quest 3S Camera Test', 
                         style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('📷 Cameras: ${_cameras.length}', 
                         style: TextStyle(color: Colors.white, fontSize: 14)),
                    Text('✅ Status: ${_status}', 
                         style: TextStyle(color: Colors.green, fontSize: 14)),
                    if (_controller != null) ...[
                      Text('🎥 Camera: ${_controller!.description.name}', 
                           style: TextStyle(color: Colors.white, fontSize: 12)),
                      Text('🎯 Direction: ${_controller!.description.lensDirection}', 
                           style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Loading screen
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_status.contains("Error")) ...[
                Icon(Icons.error, color: Colors.red, size: 64),
                SizedBox(height: 20),
                Text('❌ Camera Error', 
                     style: TextStyle(color: Colors.red, fontSize: 24)),
              ] else ...[
                CircularProgressIndicator(color: Colors.blue),
                SizedBox(height: 20),
                Text('🥽 Initializing Camera...', 
                     style: TextStyle(color: Colors.white, fontSize: 20)),
              ],
              
              SizedBox(height: 20),
              Text(_status, 
                   style: TextStyle(color: Colors.white, fontSize: 16),
                   textAlign: TextAlign.center),
                   
              SizedBox(height: 20),
              Text('📷 Found ${_cameras.length} cameras', 
                   style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}