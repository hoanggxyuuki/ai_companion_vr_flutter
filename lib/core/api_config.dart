class ApiConfig {
  static const String baseUrl = 'http://192.168.1.228:8000';
  static const String apiKey = 'hoanggxyuuki';
  
  static String get visionWsUrl => baseUrl
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://') + '/ws/vision';
      
  static String get audioWsUrl => baseUrl
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://') + '/ws/audio';
}