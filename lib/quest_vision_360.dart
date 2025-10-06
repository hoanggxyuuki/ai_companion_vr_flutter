import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import '../core/openai_tts_service.dart';
import '../core/vr_configuration_service.dart';

class QuestVision360 extends StatefulWidget {
  const QuestVision360({super.key});

  @override
  State<QuestVision360> createState() => _QuestVision360State();
}

class _QuestVision360State extends State<QuestVision360> {
  WebSocketChannel? _channel;
  String _connectionStatus = 'Disconnected';
  String _lastDetection = 'No detection yet';
  List<String> _detectionHistory = [];
  final OpenAITTSService _openAiTts = OpenAITTSService();
  bool _isConnecting = false;
  bool _isVRMode = false;
  bool _is360Mode = false;
  Timer? _reconnectTimer;
  Map<String, dynamic> _vrStatus = {};
  
  // Server configuration
  final String _serverHost = '192.168.1.100'; // Replace with your server IP
  final int _serverPort = 8765;
  
  @override
  void initState() {
    super.initState();
    _initializeVRSystem();
    _connectToServer();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _openAiTts.dispose();
    if (_is360Mode) {
      VRConfigurationService.exit360Mode();
    }
    VRConfigurationService.disableImmersiveMode();
    super.dispose();
  }

  Future<void> _initializeVRSystem() async {
    try {
      debugPrint('🥽 Initializing VR system...');
      
      final supported = await VRConfigurationService.isVRSupported();
      if (!supported) {
        debugPrint('⚠️ VR not supported on this device');
        return;
      }
      
      final initialized = await VRConfigurationService.initializeVRMode();
      if (initialized) {
        await VRConfigurationService.optimizeVRPerformance();
        await VRConfigurationService.configureVRCamera();
        
        setState(() {
          _isVRMode = true;
        });
        
        _updateVRStatus();
        debugPrint('✅ VR system initialized');
      }
    } catch (e) {
      debugPrint('🚨 VR initialization error: $e');
    }
  }

  Future<void> _updateVRStatus() async {
    final status = await VRConfigurationService.getVRStatus();
    setState(() {
      _vrStatus = status;
    });
  }

  Future<void> _toggle360Mode() async {
    try {
      if (_is360Mode) {
        // Exit 360° mode
        final success = await VRConfigurationService.exit360Mode();
        if (success) {
          await VRConfigurationService.disableImmersiveMode();
          setState(() {
            _is360Mode = false;
          });
          _openAiTts.speak('Đã thoát chế độ 360 độ');
        }
      } else {
        // Enter 360° mode
        await VRConfigurationService.enableImmersiveMode();
        final success = await VRConfigurationService.enter360Mode();
        if (success) {
          setState(() {
            _is360Mode = true;
          });
          _openAiTts.speak('Đã bật chế độ 360 độ VR');
        }
      }
      
      _updateVRStatus();
    } catch (e) {
      debugPrint('🚨 Toggle 360° error: $e');
    }
  }

  void _connectToServer() {
    if (_isConnecting) return;
    
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Connecting...';
    });

    try {
      final wsUrl = 'ws://$_serverHost:$_serverPort';
      debugPrint('Connecting to: $wsUrl');
      
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        connectTimeout: const Duration(seconds: 10),
      );

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      setState(() {
        _connectionStatus = 'Connected';
        _isConnecting = false;
      });
      
      debugPrint('WebSocket connected successfully');
    } catch (e) {
      debugPrint('Connection error: $e');
      setState(() {
        _connectionStatus = 'Connection failed: ${e.toString()}';
        _isConnecting = false;
      });
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      debugPrint('Received message: $message');
      final data = jsonDecode(message);
      
      if (data['type'] == 'detection' && data['objects'] != null) {
        final List<String> objects = List<String>.from(data['objects']);
        _processDetection(objects);
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  void _processDetection(List<String> objects) {
    if (objects.isEmpty) return;

    setState(() {
      _lastDetection = objects.join(', ');
      _detectionHistory.insert(0, _lastDetection);
      if (_detectionHistory.length > 10) {
        _detectionHistory = _detectionHistory.take(10).toList();
      }
    });

    // Announce detection using OpenAI TTS
    _openAiTts.announceDetectedObjects(objects);
  }

  void _handleError(error) {
    debugPrint('WebSocket error: $error');
    setState(() {
      _connectionStatus = 'Error: ${error.toString()}';
    });
    _scheduleReconnect();
  }

  void _handleDisconnection() {
    debugPrint('WebSocket disconnected');
    setState(() {
      _connectionStatus = 'Disconnected';
    });
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_connectionStatus != 'Connected') {
        _connectToServer();
      }
    });
  }

  void _manualReconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connectToServer();
  }

  Color _getStatusColor() {
    switch (_connectionStatus) {
      case 'Connected':
        return Colors.green;
      case 'Connecting...':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Widget _buildVRModeToggle() {
    return Card(
      elevation: 6,
      color: _is360Mode ? Colors.purple.shade900 : Colors.blue.shade900,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              _is360Mode ? Icons.threesixty : Icons.vrpano,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              _is360Mode ? '360° VR Mode' : 'Flat Mode',
              style: VRConfigurationService.getVRTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggle360Mode,
                icon: Icon(_is360Mode ? Icons.exit_to_app : Icons.threesixty),
                label: Text(_is360Mode ? 'Exit 360° Mode' : 'Enter 360° Mode'),
                style: VRConfigurationService.getVRButtonStyle().copyWith(
                  backgroundColor: MaterialStateProperty.all(
                    _is360Mode ? Colors.orange.shade600 : Colors.green.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVRControls() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VR Controls',
              style: VRConfigurationService.getVRTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Test TTS
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _openAiTts.speak('Xin chào, tôi là trợ lý AI VR 360 độ');
                },
                icon: const Icon(Icons.record_voice_over),
                label: const Text('Test VR Voice'),
                style: VRConfigurationService.getVRButtonStyle().copyWith(
                  backgroundColor: MaterialStateProperty.all(Colors.green.shade600),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Test Detection
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _processDetection(['person', 'laptop', 'cup']);
                },
                icon: const Icon(Icons.visibility),
                label: const Text('Test Detection'),
                style: VRConfigurationService.getVRButtonStyle().copyWith(
                  backgroundColor: MaterialStateProperty.all(Colors.purple.shade600),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Refresh VR Status
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updateVRStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh VR Status'),
                style: VRConfigurationService.getVRButtonStyle().copyWith(
                  backgroundColor: MaterialStateProperty.all(Colors.blue.shade600),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi,
                  color: _getStatusColor(),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Connection',
                  style: VRConfigurationService.getVRTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _connectionStatus,
              style: TextStyle(
                color: _getStatusColor(),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _manualReconnect,
              icon: const Icon(Icons.refresh),
              label: const Text('Reconnect'),
              style: VRConfigurationService.getVRButtonStyle(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVRStatus() {
    if (_vrStatus.isEmpty) return const SizedBox.shrink();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VR System Status',
              style: VRConfigurationService.getVRTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ..._vrStatus.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${entry.key}:',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.value.toString(),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionDisplay() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Detection',
              style: VRConfigurationService.getVRTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                _lastDetection,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = Scaffold(
      backgroundColor: _is360Mode ? Colors.black : null,
      appBar: _is360Mode ? null : AppBar(
        title: const Text('AI Companion VR 360°'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(_is360Mode ? 8.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_is360Mode) ...[
              const SizedBox(height: 40), // Extra space for VR mode
              Center(
                child: Text(
                  '🥽 VR 360° Mode Active 🥽',
                  style: VRConfigurationService.getVRTextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            _buildVRModeToggle(),
            const SizedBox(height: 16),
            _buildVRControls(),
            const SizedBox(height: 16),
            _buildConnectionStatus(),
            const SizedBox(height: 16),
            _buildDetectionDisplay(),
            const SizedBox(height: 16),
            _buildVRStatus(),
            
            if (_is360Mode) const SizedBox(height: 40), // Extra space for VR mode
          ],
        ),
      ),
    );

    // Wrap in VR configuration if in VR mode
    if (_is360Mode) {
      return VRConfigurationService.wrapForVR(child);
    }
    
    return child;
  }
}