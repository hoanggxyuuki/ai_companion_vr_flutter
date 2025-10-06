import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import 'package:ai_companion_vr_flutter/core/vietnamese_tts_service.dart';
import '../core/openai_tts_service.dart';
import '../core/web_tts_service.dart';

class QuestVisionAssistantOpenAI extends StatefulWidget {
  const QuestVisionAssistantOpenAI({super.key});

  @override
  State<QuestVisionAssistantOpenAI> createState() => _QuestVisionAssistantOpenAIState();
}

class _QuestVisionAssistantOpenAIState extends State<QuestVisionAssistantOpenAI> {
  WebSocketChannel? _channel;
  String _connectionStatus = 'Disconnected';
  String _lastDetection = 'No detection yet';
  List<String> _detectionHistory = [];
  final OpenAITTSService _openAiTts = OpenAITTSService();
  // WebTTSService uses static methods
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  
  // Server configuration
  final String _serverHost = '172.20.10.3'; // Replace with your server IP
  final int _serverPort = 8000;
  
  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _openAiTts.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Companion VR - OpenAI TTS'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            Card(
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
                          'Connection Status',
                          style: Theme.of(context).textTheme.titleLarge,
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
                    Text(
                      'Server: $_serverHost:$_serverPort',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _manualReconnect,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // TTS Test Controls
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TTS Testing',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    
                    // OpenAI TTS Test
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final success = await _openAiTts.testTTS();
                          if (!success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('OpenAI TTS test failed. Check API key and internet connection.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.cloud_outlined),
                        label: const Text('Test OpenAI TTS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Web TTS Test (Fallback)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await WebTTSService.speak('Đây là test Web TTS làm backup.');
                        },
                        icon: const Icon(Icons.web),
                        label: const Text('Test Web TTS (Fallback)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Manual Detection Test
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _processDetection(['person', 'laptop', 'cup']);
                        },
                        icon: const Icon(Icons.visibility),
                        label: const Text('Test Object Detection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Current Detection Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Detection',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
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
            ),

            const SizedBox(height: 16),

            // Detection History Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Colors.green.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Detection History',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_detectionHistory.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No detections yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      ..._detectionHistory.map((detection) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          detection,
                          style: const TextStyle(fontSize: 14),
                        ),
                      )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Configuration Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Configuration',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• OpenAI TTS: Primary text-to-speech engine\n'
                      '• Web TTS: Fallback option for VR compatibility\n'
                      '• Auto-reconnect: Enabled (5 second interval)\n'
                      '• Language: Vietnamese with English fallback\n'
                      '• Detection: Real-time object announcement',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: const Text(
                        '⚠️ Configure OpenAI API key in openai_tts_service.dart',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
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