import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'quest_frame_capture_view.dart';

void main() {
  runApp(QuestCameraApp());
}

class QuestCameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quest 3S Frame Capture',
      theme: ThemeData.dark(),
      home: QuestFrameCaptureView(),
    );
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
  bool _isCameraInitialized = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('🎥 VR Camera: Initializing Quest 3S camera via native plugin...');
      
      // Initialize Quest 3S camera through native plugin
      await QuestCameraPlugin.initializeCamera();
      
      // Start Quest 3S Passthrough mode
      await QuestCameraPlugin.startPassthrough();
      
      // Get camera info
      final cameraInfo = await QuestCameraPlugin.getCameraInfo();
      debugPrint('🎥 Quest Camera Info: $cameraInfo');
      
      // Quest 3S specific: Wait for camera to fully stabilize
      debugPrint('🎥 VR Camera: Waiting for Quest 3S camera stabilization...');
      await Future.delayed(const Duration(seconds: 2));
      
      // Start continuous capture for Quest 3S passthrough
      _startCapture();
      
      setState(() {
        _isCameraInitialized = true;
        _cameraError = null;
      });
      
      debugPrint('🎥 VR Camera: Quest 3S native camera initialized successfully');
    } catch (e) {
      debugPrint('🎥 VR Camera: Quest 3S native initialization error: $e');
      setState(() {
        _cameraError = 'Quest 3S Native Camera Error: $e';
        _isCameraInitialized = false;
      });
      
      // Fallback to regular camera if native fails
      _initializeFallbackCamera();
    }
  }
  
  Future<void> _initializeFallbackCamera() async {
    try {
      debugPrint('🎥 VR Camera: Falling back to regular camera...');
      
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('🎥 VR Camera: No cameras available on Quest 3S');
        setState(() {
          _cameraError = 'No cameras available on Quest 3S device';
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
        _isCameraInitialized = true;
        _cameraError = null;
      });
      
      debugPrint('🎥 VR Camera: Fallback camera initialized successfully');
    } catch (e) {
      debugPrint('🎥 VR Camera: Fallback initialization error: $e');
      setState(() {
        _cameraError = 'Fallback Camera Error: $e';
        _isCameraInitialized = false;
      });
    }
  }
  
  void _startCapture() {
    debugPrint('🎥 Starting capture process...');
    _startVisionProcessing();
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
      
      // Start capturing frames every 1 second using Quest 3S native camera
      _captureTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
        if (_isCapturing) {
          return;
        }
        
        _isCapturing = true;
        try {
          // Try Quest native camera first
          final String? framePath = await QuestCameraPlugin.captureFrame();
          
          if (framePath != null) {
            final File frameFile = File(framePath);
            if (await frameFile.exists()) {
              final bytes = await frameFile.readAsBytes();
              debugPrint('📸 Quest Captured frame: ${bytes.length} bytes');
              
              if (bytes.length < 500000) { // Max 500KB
                _vision!.sendJpeg(bytes);
                setState(() {
                  _frameCount++;
                });
              } else {
                debugPrint('📸 Quest frame too large, skipping...');
              }
            }
          } else if (_controller != null && _controller!.value.isInitialized) {
            // Fallback to regular camera
            final XFile image = await _controller!.takePicture();
            final bytes = await image.readAsBytes();
            
            debugPrint('📸 Fallback captured frame: ${bytes.length} bytes');
            
            if (bytes.length < 500000) { // Max 500KB
              _vision!.sendJpeg(bytes);
              setState(() {
                _frameCount++;
              });
            } else {
              debugPrint('📸 Fallback frame too large, skipping...');
            }
          }
          
        } catch (e) {
          debugPrint('📸 Capture error: $e');
        } finally {
          _isCapturing = false;  
        }
      });    }).catchError((error) {
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
    // Set VR optimized fullscreen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent for VR passthrough
      body: Stack(
        children: [
          // VR Passthrough Background (transparent to allow real-world view)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
          ),
          
          // No camera preview overlay - rely on passthrough instead
          // Camera data is captured but not displayed, allowing pure passthrough view
          
          // VR Status Panel (floating overlay)
          Positioned(
            top: 60,
            left: 40,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.cyan, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility,
                        color: Colors.cyan,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '🥽 VR AI Companion',
                        style: const TextStyle(
                          color: Colors.cyan,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  if (_lastDescription.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 350),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Text(
                        '👁️ ${_lastDescription}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Frame Counter (Bottom Left)
          Positioned(
            bottom: 30,
            left: 30,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_frameCount',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Frames',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // TTS Status (Bottom Right)
          Positioned(
            bottom: 30,
            right: 30,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isSpeaking 
                      ? Colors.green.withOpacity(0.7)
                      : Colors.grey.withOpacity(0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSpeaking ? Icons.volume_up : Icons.volume_off,
                    color: _isSpeaking ? Colors.green : Colors.grey,
                    size: 36,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSpeaking ? 'Đang nói' : 'TTS',
                    style: TextStyle(
                      color: _isSpeaking ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Center Loading Indicator when initializing
          if (_controller == null || !_controller!.value.isInitialized)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.blue,
                    strokeWidth: 6,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Đang khởi tạo camera...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Quest 3S specific permission request method
  Future<void> _requestQuest3SPermissions() async {
    if (!Platform.isAndroid) return;
    
    try {
      debugPrint('🎥 VR Camera: Requesting Quest 3S HEADSET_CAMERA permission...');
      
      // Check if running on Quest 3S (Horizon OS)
      const platform = MethodChannel('flutter/platform');
      
      try {
        // Enable Passthrough first
        await platform.invokeMethod('enablePassthrough');
        debugPrint('🎥 VR Camera: Passthrough enabled for Quest 3S');
        
        // Then request camera permissions
        await platform.invokeMethod('requestHorizonOSPermission', {
          'permission': 'horizonos.permission.HEADSET_CAMERA'
        });
        debugPrint('🎥 VR Camera: Horizon OS camera permission requested');
      } catch (e) {
        debugPrint('🎥 VR Camera: Platform channel not available, using fallback: $e');
        
        // Fallback: Wait longer for system to process permissions
        await Future.delayed(const Duration(seconds: 3));
      }
      
      // Also try requesting other VR permissions
      try {
        await Permission.camera.request();
        debugPrint('🎥 VR Camera: Standard camera permission requested');
      } catch (e) {
        debugPrint('🎥 VR Camera: Standard permission error: $e');
      }
      
    } catch (e) {
      debugPrint('🎥 VR Camera: Quest 3S permission error: $e');
      // Continue anyway, might still work
    }
  }
}