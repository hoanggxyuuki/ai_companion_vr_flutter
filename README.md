# AI Companion VR Flutter 🥽

Ứng dụng trợ lý AI với tích hợp camera vision được phát triển đặc biệt cho Meta Quest 3S. Ứng dụng sử dụng Flutter để tạo giao diện người dùng và kết nối với AI backend để phân tích hình ảnh real-time và cung cấp phản hồi bằng giọng nói.

## 🌟 Tính năng chính

### 📸 Vision Assistant
- **Real-time Camera Capture**: Chụp và xử lý frame từ camera Quest 3S
- **AI Object Detection**: Phát hiện và mô tả đối tượng trong thời gian thực
- **Smart Frame Processing**: Tối ưu hóa hiệu suất với interval processing
- **WebSocket Integration**: Kết nối với AI server để xử lý vision

### 🎤 Text-to-Speech (TTS)
- **Multi-language Support**: Hỗ trợ tiếng Việt và tiếng Anh
- **Multiple TTS Engines**:
  - Native Flutter TTS
  - OpenAI TTS API
  - Gemini TTS Service
  - Vietnamese TTS Service
- **Smart Throttling**: Tránh spam âm thanh với cooldown system
- **Quest 3S Optimized**: Tối ưu hóa cho VR headset

### 🎙️ Speech-to-Text (STT)
- **Voice Recognition**: Nhận diện giọng nói người dùng
- **Quest Optimization**: Tối ưu hóa cho môi trường VR
- **Multi-language**: Hỗ trợ nhiều ngôn ngữ

### ⚙️ VR Configuration
- **Passthrough Mode**: Tích hợp với chế độ passthrough của Quest
- **Camera Management**: Quản lý camera hardware của Quest 3S
- **Performance Optimization**: Tối ưu hóa cho VR environment

## 🛠️ Cấu trúc dự án

```
lib/
├── main.dart                           # Entry point chính
├── quest_vision_assistant.dart         # UI chính của vision assistant
├── quest_frame_capture.dart           # Camera frame capture logic
├── tts_manager.dart                   # Quản lý TTS services
├── voice_test_widget.dart             # Test widget cho voice features
└── core/                              # Services và utilities
    ├── api_config.dart                # API configuration
    ├── openai_tts_service.dart        # OpenAI TTS integration
    ├── gemini_tts_service.dart        # Gemini TTS integration
    ├── vietnamese_tts_service.dart    # Vietnamese TTS
    ├── stt_service.dart               # Speech-to-Text service
    ├── tts_service.dart               # Base TTS service
    ├── vision_ws_client.dart          # WebSocket client for vision
    ├── vr_configuration_service.dart  # VR config management
    └── quest3s_camera.dart            # Quest 3S camera integration
```

## 📋 Yêu cầu hệ thống

- **Flutter SDK**: >=3.9.2
- **Meta Quest 3S**: Với developer mode enabled
- **Android SDK**: API level 23+
- **Camera Permissions**: Cần cấp quyền camera và microphone

## 🚀 Cài đặt và chạy

### 1. Clone repository
```bash
git clone https://github.com/hoanggxyuuki/ai_companion_vr_flutter.git
cd ai_companion_vr_flutter
```

### 2. Cài đặt dependencies
```bash
flutter pub get
```

### 3. Cấu hình Quest 3S
```bash
adb devices
adb shell pm grant com.example.ai_companion_vr_flutter android.permission.CAMERA
adb shell pm grant com.example.ai_companion_vr_flutter android.permission.RECORD_AUDIO
```

### 4. Cấu hình AI Server
Cập nhật địa chỉ server trong `lib/quest_vision_assistant.dart`:
```dart
String serverUrl = "ws://YOUR_SERVER_IP:8000";
```

### 5. Build và deploy
```bash
flutter build apk --release

adb install build/app/outputs/flutter-apk/app-release.apk
```

## 🎮 Cách sử dụng

### Vision Assistant Mode
1. **Khởi động app** trên Quest 3S
2. **Cho phép quyền** camera và microphone khi được yêu cầu
3. **Kết nối server**: App sẽ tự động kết nối với AI vision server
4. **Bắt đầu capture**: Nhấn nút capture để bắt đầu phân tích real-time
5. **Nghe mô tả**: AI sẽ mô tả những gì nhìn thấy qua TTS

### Voice Test Mode
1. Chuyển sang `main_voice_test.dart` để test voice features
2. Test TTS với nhiều engine khác nhau
3. Test STT recognition
4. Kiểm tra voice quality trên Quest 3S

## 🔧 Configuration

### TTS Settings
Tùy chỉnh TTS trong `lib/core/tts_service.dart`:
```dart
await TTSService.setOptimalVoiceForQuest();

await TTSService.setSpeechRate(0.8);
await TTSService.setPitch(1.0);
```

### Camera Settings
Cấu hình camera trong `lib/quest_frame_capture.dart`:
```dart
int aiProcessingInterval = 3; 
ResolutionPreset.high; 
```

## 🐛 Troubleshooting

### Camera Black Screen
- Kiểm tra camera permissions
- Restart Quest 3S
- Thử camera ID khác nhau
- Xem logs trong `adb logcat`

### TTS Không hoạt động
- Kiểm tra microphone permissions
- Test với voice_test_widget
- Kiểm tra network connection cho OpenAI TTS

### WebSocket Connection Issues
- Kiểm tra server IP address
- Đảm bảo server đang chạy
- Check firewall settings

## 📚 Dependencies chính

- `camera: ^0.10.5+9` - Camera integration
- `flutter_tts: ^3.8.5` - Text-to-Speech
- `web_socket_channel: ^2.4.0` - WebSocket connection
- `http: ^1.2.1` - HTTP client
- `audioplayers: ^5.2.1` - Audio playback
- `permission_handler: ^11.3.1` - Permissions management

## 🤝 Đóng góp

1. Fork repository
2. Tạo feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Mở Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 👥 Tác giả

- **hoanggxyuuki** - *Initial work* - [GitHub](https://github.com/hoanggxyuuki)

## 🙏 Acknowledgments

- Meta Quest SDK cho VR integration
- OpenAI API cho advanced TTS
- Flutter team cho cross-platform framework
- Community contributors
