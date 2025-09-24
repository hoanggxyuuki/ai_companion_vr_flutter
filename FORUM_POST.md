# Flutter Camera Black Screen on Quest 3S - Need Help

**TL;DR**: Flutter camera plugin initializes successfully on Quest 3S but CameraPreview shows black screen. Camera hardware works, permissions granted, no errors in logs.

## Setup
- **Device**: Meta Quest 3S
- **Framework**: Flutter with camera: ^0.10.6
- **Permissions**: All camera permissions granted via ADB

## What Works ✅
- Camera service connects successfully
- Camera2 API opens camera ID 1 (front camera)
- Flutter camera plugin initializes without errors
- App UI displays correctly

## What Doesn't Work ❌
- CameraPreview widget shows completely black
- No visual output despite successful initialization
- Issue persists across different resolution settings

## Key Logs
```
I CameraService: CameraService::connect call (camera ID 1)
I Camera2ClientBase: Camera 1: Opened  
I flutter : 🥽 Camera initialized successfully!
I flutter : 📱 Available cameras: 2
```

## Code (Simplified)
```dart
_controller = CameraController(
  frontCamera, 
  ResolutionPreset.high,
  enableAudio: false,
);
await _controller!.initialize();

// In build():
CameraPreview(_controller!)  // Shows black screen
```

## Question
**Has anyone got Flutter camera preview working on Quest 3S/Quest 3?**

Wondering if:
1. Quest VR passthrough interferes with camera preview?
2. Need special surface configuration for VR devices?
3. Should use Unity/native Android instead of Flutter?
4. Any working camera plugins for Quest devices?

Any help appreciated! Can provide full logs if needed.