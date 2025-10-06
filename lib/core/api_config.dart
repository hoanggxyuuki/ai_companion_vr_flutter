class ApiConfig {
  static const String baseUrl = 'http://api_server';
  static const String apiKey = 'hoanggxyuuki';
  
  static String get visionWsUrl => baseUrl
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://') + '/ws/vision';
      
  static String get audioWsUrl => baseUrl
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://') + '/ws/audio';
}