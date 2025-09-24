# Lỗi Camera Flutter trên Quest 3S - Màn hình đen

## Vấn đề
Đang làm app Flutter cho Quest 3S, camera plugin khởi động thành công nhưng CameraPreview bị đen xì. 

## Chi tiết kỹ thuật
- **Thiết bị**: Meta Quest 3S  
- **Framework**: Flutter + camera plugin ^0.10.6
- **Quyền**: Đã cấp đầy đủ camera permissions qua ADB

## Cái gì hoạt động ✅
- Camera service kết nối OK
- Camera2 API mở camera thành công  
- Flutter camera plugin initialize không lỗi
- UI app hiển thị bình thường

## Cái gì không hoạt động ❌  
- CameraPreview widget chỉ hiện màn hình đen
- Không có output hình ảnh gì cả
- Thử nhiều resolution khác nhau vẫn vậy

## Log quan trọng
```
I CameraService: CameraService::connect call (camera ID 1)
I Camera2ClientBase: Camera 1: Opened
I flutter : 🥽 Camera initialized successfully!
I flutter : 📱 Available cameras: 2  
```

## Code cơ bản
```dart
_controller = CameraController(
  frontCamera, 
  ResolutionPreset.high,
  enableAudio: false,
);
await _controller!.initialize(); // Thành công

// Trong build():
CameraPreview(_controller!)  // Bị đen
```

## Câu hỏi
**Có ai làm được Flutter camera preview trên Quest 3S chưa?**

Có phải:
1. VR passthrough can thiệp vào camera preview?
2. Cần config surface đặc biệt cho VR device?  
3. Nên dùng Unity/native Android thay vì Flutter?
4. Có plugin camera nào khác work trên Quest không?

## Đã thử
- Native Android Camera2 implementation
- Nhiều resolution settings khác nhau
- Cấp đủ permissions thủ công
- Tạo app test đơn giản nhất có thể

**Mong được góp ý! Có thể cung cấp full logs nếu cần.**