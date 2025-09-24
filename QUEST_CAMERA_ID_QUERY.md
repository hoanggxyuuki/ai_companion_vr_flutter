# Camera ID Query for Meta Quest 3S

**Question for AI Assistant:**

I'm developing a Flutter app that needs to access the passthrough cameras on Meta Quest 3S using Android Camera2 API. Currently, I can access cameras but I'm getting the wrong camera.

**Current Situation:**
- Device: Meta Quest 3S
- API: Android Camera2 API through Flutter Platform Channels
- Available cameras: Camera ID "0" and Camera ID "1"
- Camera ID "1" (LENS_FACING_FRONT) shows avatar/memoji instead of real camera feed
- Camera ID "0" (LENS_FACING_BACK) - need to confirm if this accesses passthrough cameras

**What I need to know:**

1. **What are the exact Camera IDs for Meta Quest 3S passthrough cameras?**
   - Which camera ID gives access to the real-world passthrough view?
   - Are there multiple passthrough camera IDs (left/right eye cameras)?

2. **Camera characteristics for Quest 3S:**
   - Do passthrough cameras use LENS_FACING_BACK or a different facing constant?
   - Are there special camera characteristics or capabilities I should check for?

3. **Permission requirements:**
   - Do I need special permissions beyond android.permission.CAMERA?
   - Are there Quest-specific permissions like com.oculus.permission.PASSTHROUGH?

4. **Camera2 API specifics:**
   - Should I use CameraDevice.TEMPLATE_PREVIEW or TEMPLATE_STILL_CAPTURE?
   - Any special CaptureRequest parameters for passthrough cameras?

**Current Code Pattern:**
```kotlin
val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
val cameraIds = cameraManager.cameraIdList
// Currently trying Camera ID "0" for back camera
// But need to confirm this accesses passthrough cameras, not device rear camera
```

**Expected Result:**
I need to capture real-world camera feed from Quest 3S passthrough system, not avatar representations or front-facing user camera.

Please provide the correct Camera ID(s) and any Quest 3S-specific configuration needed for accessing passthrough cameras through Android Camera2 API.