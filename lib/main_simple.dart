import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:typed_data';
import 'core/vision_ws_client.dart';
import 'core/vr_tts.dart';

Future<void> main() async {
  try {
    debugPrint('🥽 VR Camera App: STARTING...');
    WidgetsFlutterBinding.ensureInitialized();
    
    runApp(const VRCameraApp());
  } catch (e) {
    debugPrint('🥽 VR Camera App: ERROR in main: $e');
  }
}

class VRCameraApp extends StatelessWidget {
  const VRCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VR Camera Assistant',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      home: const VRCameraPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VRCameraPage extends StatefulWidget {
  const VRCameraPage({super.key});

  @override
  State<VRCameraPage> createState() => _VRCameraPageState();
}

class _VRCameraPageState extends State<VRCameraPage> {
  CameraController? _controller;
  String _status = "Đang khởi tạo camera...";
  VisionWsClient? _vision;
  Timer? _captureTimer;
  bool _isCapturing = false;
  int _frameCount = 0;
  String _lastDescription = '';
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('🎥 VR Camera: Requesting permissions...');
      
      // Request camera permission
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission != PermissionStatus.granted) {
        setState(() {
          _status = "❌ Cần cấp quyền camera";
        });
        return;
      }

      debugPrint('🎥 VR Camera: Getting available cameras...');
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        setState(() {
          _status = "❌ Không tìm thấy camera";
        });
        return;
      }

      // Tìm camera phù hợp cho Quest 3S
      CameraDescription? selectedCamera;
      for (final camera in cameras) {
        debugPrint('🎥 Found camera: ${camera.name}, lens: ${camera.lensDirection}');
        
        // Ưu tiên camera trước (Quest 3S passthrough cameras)
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }
      
      selectedCamera ??= cameras.first;
      debugPrint('🎥 Selected camera: ${selectedCamera.name}');

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // 1280x960 suitable for Quest 3S
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      
      setState(() {
        _status = "✅ Camera sẵn sàng - Đang kết nối API...";
      });
      
      debugPrint('🎥 VR Camera: Camera initialized successfully');
      
      // Start vision processing
      _startVisionProcessing();
      
    } catch (e) {
      debugPrint('🎥 VR Camera Error: $e');
      setState(() {
        _status = "❌ Lỗi camera: $e";
      });
    }
  }

  void _startVisionProcessing() {
    _vision = VisionWsClient(
      onDetections: (data) {
        final desc = data['description'] as String?;
        final frameCount = data['frame_count'] as int?;
        
        if (desc != null && mounted) {
          setState(() {
            _lastDescription = desc;
            _status = "🔍 $desc";
            if (frameCount != null) {
              _frameCount = frameCount;
            }
          });
          
          // Speak the description
          _speakDescription(desc);
        }
      },
      onError: (error) {
        debugPrint('🔥 Vision API Error: $error');
        setState(() {
          _status = "❌ Vision API lỗi: $error";
        });
      },
    );

    // Connect to WebSocket
    _vision!.connect().then((_) {
      setState(() {
        _status = "✅ Đã kết nối Vision API - Đang phân tích...";
      });
      
      // Start capturing frames every 1 second
      _captureTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
        if (_isCapturing || _controller == null || !_controller!.value.isInitialized) {
          return;
        }
        
        _isCapturing = true;
        try {
          final XFile image = await _controller!.takePicture();
          final bytes = await image.readAsBytes();
          
          debugPrint('📸 Captured frame: ${bytes.length} bytes');
          
          if (bytes.length < 500000) { // Max 500KB
            _vision!.sendJpeg(bytes);
            setState(() {
              _frameCount++;
            });
          } else {
            debugPrint('📸 Frame too large, skipping...');
          }
          
        } catch (e) {
          debugPrint('📸 Capture error: $e');
        } finally {
          _isCapturing = false;
        }
      });
      
    }).catchError((error) {
      debugPrint('🔥 Vision API connection failed: $error');
      setState(() {
        _status = "❌ Không thể kết nối Vision API: $error";
      });
    });
  }

  void _speakDescription(String description) async {
    if (description.isEmpty || description == _lastDescription || _isSpeaking) {
      return;
    }
    
    // Only speak meaningful descriptions
    if (description.length < 10 || 
        description.toLowerCase().contains('không có') ||
        description.toLowerCase().contains('trống')) {
      return;
    }
    
    try {
      _isSpeaking = true;
      debugPrint('🔊 TTS: Speaking "$description"');
      
      await VRTextToSpeech.speakVietnamese(
        description,
        speechRate: 1.0,
        pitch: 1.0,
      );
      
    } catch (e) {
      debugPrint('🔊 TTS Error: $e');
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        _isSpeaking = false;
      });
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _vision?.dispose();
    _controller?.dispose();
    VRTextToSpeech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Camera Preview
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _controller != null && _controller!.value.isInitialized
                      ? CameraPreview(_controller!)
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.blue),
                        ),
                ),
              ),
            ),
            
            // Status and Info
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Status
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Frame Counter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$_frameCount',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Frames',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        
                        Column(
                          children: [
                            Icon(
                              _isSpeaking ? Icons.volume_up : Icons.volume_off,
                              color: _isSpeaking ? Colors.green : Colors.grey,
                              size: 32,
                            ),
                            Text(
                              _isSpeaking ? 'Đang nói' : 'TTS',
                              style: TextStyle(
                                color: _isSpeaking ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Instructions
                    const Text(
                      'VR Camera Assistant cho Quest 3S\nTự động phân tích và thông báo bằng giọng nói',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}