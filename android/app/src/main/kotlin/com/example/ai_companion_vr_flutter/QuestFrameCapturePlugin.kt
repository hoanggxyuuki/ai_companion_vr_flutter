package com.example.ai_companion_vr_flutter

import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import android.app.Activity
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.media.Image
import java.io.ByteArrayOutputStream
import android.graphics.ImageFormat
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Size
import java.nio.ByteBuffer
import java.util.concurrent.Semaphore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class QuestFrameCapturePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    companion object {
        private const val TAG = "QuestFrameCapture"
        private const val CHANNEL = "quest_frame_capture"
        private const val META_PASSTHROUGH_CAMERA_KEY_NAME = "com.meta.extra_metadata.camera_source"
        private const val META_PASSTHROUGH_CAMERA_VALUE: Byte = 1
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var cameraManager: CameraManager? = null
    private var cameraDevice: CameraDevice? = null
    private var imageReader: ImageReader? = null
    private var backgroundHandler: Handler? = null
    private var backgroundThread: HandlerThread? = null
    private var passthroughCameraId: String? = null
    private var selectedCameraId: String? = null
    private val cameraOpenCloseLock = Semaphore(1)
    private var activity: Activity? = null
    private var permissionResult: MethodChannel.Result? = null
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        startBackgroundThread()
        Log.d(TAG, "🔥 Quest Frame Capture Plugin attached - Quest 3S Passthrough Mode")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        releaseCamera()
        stopBackgroundThread()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val result = permissionResult
            permissionResult = null
            
            if (result != null) {
                val granted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                result.success(mapOf(
                    "granted" to granted,
                    "permissions" to permissions.toList(),
                    "results" to grantResults.toList()
                ))
            }
            return true
        }
        return false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermissions" -> {
                checkAllPermissions(result)
            }
            "requestPermissions" -> {
                requestAllPermissions(result)
            }
            "findPassthroughCamera" -> {
                findPassthroughCamera(result)
            }
            "listAvailableCameras" -> {
                listAvailableCameras(result)
            }
            "initializeCamera" -> {
                val cameraId = call.argument<String>("cameraId") ?: findPassthroughCameraId()
                initializeCamera(cameraId, result)
            }
            "captureFrame" -> {
                captureFrame(result)
            }
            "release" -> {
                releaseCamera()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun checkAllPermissions(result: MethodChannel.Result) {
        val requiredPermissions = arrayOf(
            android.Manifest.permission.CAMERA,
            "horizonos.permission.HEADSET_CAMERA"
        )
        
        val permissionsGranted = requiredPermissions.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
        
        result.success(mapOf(
            "granted" to permissionsGranted,
            "missing" to requiredPermissions.filter { permission ->
                ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED
            }
        ))
    }

    private fun requestAllPermissions(result: MethodChannel.Result) {
        val requiredPermissions = arrayOf(
            android.Manifest.permission.CAMERA,
            "horizonos.permission.HEADSET_CAMERA"
        )
        
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available for permission request", null)
            return
        }
        
        val missingPermissions = requiredPermissions.filter { permission ->
            ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED
        }
        
        if (missingPermissions.isEmpty()) {
            result.success(mapOf(
                "granted" to true,
                "message" to "All permissions already granted"
            ))
            return
        }
        
        Log.d(TAG, "🔥 Requesting Quest 3S permissions: ${missingPermissions.joinToString()}")
        permissionResult = result
        
        ActivityCompat.requestPermissions(
            currentActivity,
            requiredPermissions,
            PERMISSION_REQUEST_CODE
        )
    }

    private fun findPassthroughCameraId(): String? {
        if (passthroughCameraId != null) return passthroughCameraId
        
        try {
            val manager = cameraManager ?: return null
            val metaCameraSourceKey = CameraCharacteristics.Key<Byte>(
                META_PASSTHROUGH_CAMERA_KEY_NAME,
                Byte::class.java
            )
            
            for (cameraId in manager.cameraIdList) {
                val characteristics = manager.getCameraCharacteristics(cameraId)
                val cameraSourceValue = characteristics.get(metaCameraSourceKey)
                
                if (cameraSourceValue != null && cameraSourceValue == META_PASSTHROUGH_CAMERA_VALUE) {
                    Log.d(TAG, "Found Quest 3S passthrough camera: $cameraId")
                    passthroughCameraId = cameraId
                    return cameraId
                }
            }
            
            Log.w(TAG, "No Quest 3S passthrough camera found!")
            return null
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Error finding passthrough camera: ${e.message}")
            return null
        }
    }

    private fun findPassthroughCamera(result: MethodChannel.Result) {
        val cameraId = findPassthroughCameraId()
        if (cameraId != null) {
            result.success(mapOf(
                "found" to true,
                "cameraId" to cameraId,
                "message" to "Quest 3S passthrough camera detected"
            ))
        } else {
            result.success(mapOf(
                "found" to false,
                "cameraId" to null,
                "message" to "No Quest 3S passthrough camera found"
            ))
        }
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread?.looper!!)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "Interrupted while stopping background thread", e)
        }
    }    private fun listAvailableCameras(result: MethodChannel.Result) {
        try {
            val manager = cameraManager ?: return result.error("CAMERA_ERROR", "Camera manager not available", null)
            val cameraIds = manager.cameraIdList
            val cameras = mutableListOf<Map<String, Any>>()
            
            val metaCameraSourceKey = CameraCharacteristics.Key<Byte>(
                META_PASSTHROUGH_CAMERA_KEY_NAME,
                Byte::class.java
            )
            
            for (cameraId in cameraIds) {
                val characteristics = manager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val facingString = when (facing) {
                    CameraCharacteristics.LENS_FACING_FRONT -> "front"
                    CameraCharacteristics.LENS_FACING_BACK -> "back"
                    CameraCharacteristics.LENS_FACING_EXTERNAL -> "external"
                    else -> "unknown"
                }
                
                // Check if this is a Quest passthrough camera
                val cameraSourceValue = characteristics.get(metaCameraSourceKey)
                val isPassthrough = cameraSourceValue != null && cameraSourceValue == META_PASSTHROUGH_CAMERA_VALUE
                
                // Get supported resolutions
                val streamConfigMap = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                val supportedSizes = streamConfigMap?.getOutputSizes(ImageFormat.JPEG)?.map { size ->
                    "${size.width}x${size.height}"
                } ?: listOf()
                
                cameras.add(mapOf(
                    "id" to cameraId,
                    "facing" to facingString,
                    "isPassthrough" to isPassthrough,
                    "supportedResolutions" to supportedSizes
                ))
                
                if (isPassthrough) {
                    Log.d(TAG, "Camera $cameraId: Quest 3S Passthrough Camera (facing: $facingString)")
                } else {
                    Log.d(TAG, "Camera $cameraId: Standard Camera (facing: $facingString)")
                }
            }
            
            result.success(cameras)
        } catch (e: CameraAccessException) {
            result.error("CAMERA_ERROR", "Failed to list cameras: ${e.message}", null)
        }
    }

    private fun initializeCamera(cameraId: String?, result: MethodChannel.Result) {
        val targetCameraId = cameraId ?: findPassthroughCameraId()
        
        if (targetCameraId == null) {
            result.error("CAMERA_ERROR", "No valid camera ID found", null)
            return
        }
        
        try {
            releaseCamera()
            selectedCameraId = targetCameraId
            
            val manager = cameraManager ?: return result.error("CAMERA_ERROR", "Camera manager not available", null)
            
            // Get camera characteristics to determine optimal resolution
            val characteristics = manager.getCameraCharacteristics(targetCameraId)
            val streamConfigMap = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val supportedSizes = streamConfigMap?.getOutputSizes(ImageFormat.JPEG)
            
            // Quest 3S optimal resolutions (select best available)
            val preferredSizes = arrayOf(
                Size(1280, 960),  // Best quality
                Size(800, 600),
                Size(640, 480),
                Size(320, 240)
            )
            
            val selectedSize = preferredSizes.firstOrNull { preferred ->
                supportedSizes?.any { it.width == preferred.width && it.height == preferred.height } == true
            } ?: Size(640, 480) // Fallback
            
            Log.d(TAG, "🔥 Selected resolution: ${selectedSize.width}x${selectedSize.height}")
            
            // Create ImageReader for JPEG capture with optimal resolution
            imageReader = ImageReader.newInstance(selectedSize.width, selectedSize.height, ImageFormat.JPEG, 1)
            
            Log.d(TAG, "🔥 Opening Quest camera: $targetCameraId")
            
            manager.openCamera(targetCameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    Log.d(TAG, "🔥 Quest camera opened successfully: $targetCameraId")
                    cameraDevice = camera
                    
                    // Check if this is actually a passthrough camera
                    val isPassthrough = try {
                        val metaCameraSourceKey = CameraCharacteristics.Key<Byte>(
                            META_PASSTHROUGH_CAMERA_KEY_NAME,
                            Byte::class.java
                        )
                        val cameraSourceValue = characteristics.get(metaCameraSourceKey)
                        cameraSourceValue != null && cameraSourceValue == META_PASSTHROUGH_CAMERA_VALUE
                    } catch (e: Exception) {
                        false
                    }
                    
                    result.success(mapOf(
                        "cameraId" to targetCameraId,
                        "resolution" to "${selectedSize.width}x${selectedSize.height}",
                        "isPassthrough" to isPassthrough,
                        "message" to "Camera $targetCameraId initialized successfully"
                    ))
                }
                
                override fun onDisconnected(camera: CameraDevice) {
                    Log.w(TAG, "🔥 Camera disconnected: $targetCameraId")
                    camera.close()
                    cameraDevice = null
                }
                
                override fun onError(camera: CameraDevice, error: Int) {
                    Log.e(TAG, "🔥 Camera error $error for camera: $targetCameraId")
                    camera.close()
                    cameraDevice = null
                    result.error("CAMERA_ERROR", "Camera error: $error", null)
                }
            }, backgroundHandler)
            
        } catch (e: CameraAccessException) {
            Log.e(TAG, "🔥 CameraAccessException in initializeCamera: ${e.message}")
            result.error("CAMERA_ERROR", "Failed to initialize camera: ${e.message}", null)
        } catch (e: SecurityException) {
            Log.e(TAG, "🔥 SecurityException in initializeCamera: ${e.message}")
            result.error("PERMISSION_ERROR", "Camera permission denied: ${e.message}", null)
        }
    }



    private fun captureFrame(result: MethodChannel.Result) {
        val device = cameraDevice
        val reader = imageReader
        
        if (device == null || reader == null) {
            result.error("CAMERA_NOT_READY", "Camera not initialized", null)
            return
        }
        
        try {
            Log.d(TAG, "🔥 Starting Quest 3S frame capture...")
            
            // Set up image available listener
            reader.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage()
                if (image != null) {
                    try {
                        val buffer: ByteBuffer = image.planes[0].buffer
                        val bytes = ByteArray(buffer.remaining())
                        buffer.get(bytes)
                        
                        Log.d(TAG, "🔥 Quest frame captured - size: ${bytes.size} bytes")
                        result.success(bytes)
                    } catch (e: Exception) {
                        Log.e(TAG, "🔥 Error processing captured frame", e)
                        result.error("CAPTURE_PROCESS_ERROR", e.message, null)
                    } finally {
                        image.close()
                    }
                } else {
                    Log.w(TAG, "🔥 No image available")
                    result.error("NO_IMAGE", "No image available", null)
                }
            }, backgroundHandler)
            
            // Create capture session for single shot
            device.createCaptureSession(
                listOf(reader.surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        Log.i(TAG, "🔥 Capture session configured for Quest 3S")
                        
                        try {
                            // Use TEMPLATE_STILL_CAPTURE for single frames (Quest 3S specific)
                            val captureBuilder = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
                            captureBuilder.addTarget(reader.surface)
                            
                            // Quest 3S specific settings for passthrough
                            captureBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                            captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_AUTO)
                            captureBuilder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
                            
                            session.capture(captureBuilder.build(), null, backgroundHandler)
                            Log.d(TAG, "🔥 Quest 3S frame capture requested")
                            
                        } catch (e: CameraAccessException) {
                            Log.e(TAG, "🔥 Error capturing Quest frame", e)
                            result.error("CAPTURE_ERROR", e.message, null)
                        }
                    }
                    
                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "🔥 Quest capture session configuration failed")
                        result.error("SESSION_ERROR", "Failed to configure capture session", null)
                    }
                },
                backgroundHandler
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "🔥 Error in Quest capture frame", e)
            result.error("CAPTURE_ERROR", e.message, null)
        }
    }
    
    private fun releaseCamera() {
        try {
            cameraOpenCloseLock.acquire()
            cameraDevice?.close()
            cameraDevice = null
            imageReader?.close()
            imageReader = null
            selectedCameraId = null
            Log.d(TAG, "🔥 Quest camera released")
        } catch (e: InterruptedException) {
            Log.e(TAG, "🔥 Interrupted while closing camera", e)
        } finally {
            cameraOpenCloseLock.release()
        }
    }
}