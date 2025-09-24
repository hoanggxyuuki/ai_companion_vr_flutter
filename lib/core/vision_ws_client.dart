import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';

typedef DetectionsHandler = void Function(Map<String, dynamic> data);
typedef ErrorHandler = void Function(String error);

class VisionWsClient {
  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  final DetectionsHandler onDetections;
  final ErrorHandler? onError;
  bool _isConnected = false;
  Timer? _pingTimer;

  VisionWsClient({
    required this.onDetections,
    this.onError,
  });

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      // WebSocket URLs cần protocol ws:// thay vì http://
      final wsUrl = ApiConfig.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      
      final uri = Uri.parse('$wsUrl/ws/vision');
      
      debugPrint('VR Vision: Connecting to WebSocket: $uri');
      
      // Thêm API key vào query parameter
      final uriWithAuth = uri.replace(queryParameters: {
        'api_key': ApiConfig.apiKey,
      });
      
      debugPrint('VR Vision: Connecting with auth: $uriWithAuth');
      
      _channel = IOWebSocketChannel.connect(uriWithAuth);
      
      _sub = _channel!.stream.listen(
        (event) {
          try {
            if (event is String) {
              final data = json.decode(event) as Map<String, dynamic>;
              debugPrint('VR Vision WebSocket received: ${data['type']}');
              
              if (data['type'] == 'detections') {
                onDetections(data);
              } else if (data['type'] == 'pong') {
                debugPrint('VR Vision WebSocket: Received pong');
              } else if (data['type'] == 'error') {
                debugPrint('VR Vision WebSocket error: ${data['message']}');
                onError?.call('Server error: ${data['message']}');
              }
            }
          } catch (e) {
            debugPrint('VR Vision WebSocket parse error: $e');
            onError?.call('Parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('VR Vision WebSocket error: $error');
          _isConnected = false;
          onError?.call('Connection error: $error');
        },
        onDone: () {
          debugPrint('VR Vision WebSocket connection closed');
          _isConnected = false;
        },
      );

      // Chờ một chút để connection establish
      await Future.delayed(const Duration(milliseconds: 1000));
      _isConnected = true;
      
      // Gửi ping định kỳ để duy trì connection
      _startPing();
      
      debugPrint('VR Vision WebSocket connected successfully');
    } catch (e) {
      debugPrint('VR Vision WebSocket connection failed: $e');
      _isConnected = false;
      onError?.call('Connection failed: $e');
      rethrow;
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('ping');
        } catch (e) {
          debugPrint('VR Vision WebSocket ping failed: $e');
        }
      }
    });
  }

  void sendJpeg(Uint8List bytes) {
    if (!_isConnected || _channel == null) {
      debugPrint('VR Vision WebSocket: Cannot send - not connected');
      onError?.call('WebSocket not connected');
      return;
    }
    
    try {
      // Gửi binary data (JPEG bytes)
      _channel!.sink.add(bytes);
      debugPrint('VR Vision WebSocket: Sent ${bytes.length} bytes');
    } catch (e) {
      debugPrint('VR Vision WebSocket send error: $e');
      onError?.call('Send error: $e');
      // Try to reconnect on send error
      _isConnected = false;
    }
  }

  Future<void> reconnect() async {
    dispose();
    await Future.delayed(const Duration(seconds: 1));
    await connect();
  }

  void dispose() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    debugPrint('VR Vision WebSocket disposed');
  }
}