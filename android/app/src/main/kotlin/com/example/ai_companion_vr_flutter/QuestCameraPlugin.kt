package com.example.ai_companion_vr_flutter

import android.content.Context
import android.hardware.camera2.*
import android.media.ImageReader
import android.graphics.ImageFormat
import android.util.Size
import android.view.Surface
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

class QuestCameraPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var cameraManager: CameraManager? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var backgroundHandler: Handler? = null
    private var backgroundThread: HandlerThread? = null
    private var frontCameraId: String? = null
    
    companion object {
        private const val TAG = "QuestCameraPlugin"
        private const val CHANNEL_NAME = "quest_camera_plugin"
    }
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        
        cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        startBackgroundThread()
        
        Log.i(TAG, "🎥 Quest Camera Plugin: Attached to engine")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        closeCamera()
        stopBackgroundThread()
        Log.i(TAG, "🎥 Quest Camera Plugin: Detached from engine")
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> initializeQuestCamera(result)
            "captureFrame" -> capturePassthroughFrame(result)
            "startPassthrough" -> startPassthroughMode(result)
            "stopPassthrough" -> stopPassthroughMode(result)
            "getCameraInfo" -> getCameraInfo(result)
            else -> result.notImplemented()
        }
    }
    
    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("QuestCameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
        Log.d(TAG, "🎥 Background thread started")
    }
    
    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "🎥 Background thread interrupted", e)
        }
    }
    
    private fun initializeQuestCamera(result: Result) {
        try {
            val cameraIds = cameraManager!!.cameraIdList
            Log.d(TAG, "🎥 Available cameras: ${cameraIds.contentToString()}")
            
            // Quest 3S có multiple cameras, tìm front camera phù hợp
            frontCameraId = cameraIds.find { id ->
                val characteristics = cameraManager!!.getCameraCharacteristics(id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                
                Log.d(TAG, "🎥 Camera $id - Facing: $facing, Capabilities: ${capabilities?.contentToString()}")
                
                // Tìm front camera hoặc camera có khả năng passthrough
                facing == CameraCharacteristics.LENS_FACING_FRONT || 
                capabilities?.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_BACKWARD_COMPATIBLE) == true
            }
            
            if (frontCameraId != null) {
                Log.i(TAG, "🎥 Selected camera: $frontCameraId")
                openCamera(frontCameraId!!, result)
            } else {
                Log.e(TAG, "🎥 No suitable camera found")
                result.error("NO_CAMERA", "No suitable camera found for Quest 3S", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "🎥 Camera initialization error", e)
            result.error("CAMERA_ERROR", e.message, null)
        }
    }
    
    private fun openCamera(cameraId: String, result: Result) {
        try {
            // Setup ImageReader cho Quest 3S specs
            imageReader = ImageReader.newInstance(
                1280, 960, // Quest 3S resolution
                ImageFormat.JPEG,
                1
            )
            
            imageReader!!.setOnImageAvailableListener({
                Log.d(TAG, "🎥 Image available from camera")
            }, backgroundHandler)
            
            cameraManager!!.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    Log.i(TAG, "🎥 Camera opened successfully: $cameraId")
                    cameraDevice = camera
                    createCaptureSession(result)
                }
                
                override fun onDisconnected(camera: CameraDevice) {
                    Log.w(TAG, "🎥 Camera disconnected: $cameraId")
                    camera.close()
                    cameraDevice = null
                }
                
                override fun onError(camera: CameraDevice, error: Int) {
                    Log.e(TAG, "🎥 Camera error: $error")
                    camera.close()
                    cameraDevice = null
                    result.error("CAMERA_OPEN_ERROR", "Failed to open camera: $error", null)
                }
            }, backgroundHandler)
            
        } catch (e: Exception) {
            Log.e(TAG, "🎥 Error opening camera", e)
            result.error("CAMERA_OPEN_ERROR", e.message, null)
        }
    }
    
    private fun createCaptureSession(result: Result) {
        try {
            val surfaces = listOf<Surface>(imageReader!!.surface)
            
            cameraDevice!!.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    Log.i(TAG, "🎥 Capture session configured")
                    captureSession = session
                    startPreview()
                    result.success("Camera initialized successfully")
                }
                
                override fun onConfigureFailed(session: CameraCaptureSession) {
                    Log.e(TAG, "🎥 Capture session configuration failed")
                    result.error("SESSION_ERROR", "Failed to configure capture session", null)
                }
            }, backgroundHandler)
            
        } catch (e: Exception) {
            Log.e(TAG, "🎥 Error creating capture session", e)
            result.error("SESSION_ERROR", e.message, null)
        }
    }
    
    private fun startPreview() {
        try {
            // For capture-only mode, just prepare for capturing
            Log.i(TAG, "🎥 Preview session ready for capture")
            
        } catch (e: Exception) {
            Log.e(TAG, "🎥 Error starting preview", e)
        }
    }
    
    private fun capturePassthroughFrame(result: Result) {
        if (cameraDevice == null || captureSession == null) {
            result.error("CAMERA_NOT_READY", "Camera not initialized", null)
            return
        }
        
        try {
            val reader = ImageReader.newInstance(1280, 960, ImageFormat.JPEG, 1)
            
            reader.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage()
                if (image != null) {
                    val buffer: ByteBuffer = image.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    
                    // Save to file
                    val file = File(context.cacheDir, "quest_frame_${System.currentTimeMillis()}.jpg")
                    FileOutputStream(file).use { it.write(bytes) }
                    
                    Log.i(TAG, "🎥 Frame captured: ${file.absolutePath}")
                    result.success(file.absolutePath)
                    
                    image.close()
                } else {
                    result.error("CAPTURE_ERROR", "No image available", null)
                }
                reader.close()
            }, backgroundHandler)
            
            val requestBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            requestBuilder.addTarget(reader.surface)
            
            captureSession!!.capture(requestBuilder.build(), null, backgroundHandler)
            
        } catch (e: Exception) {
            Log.e(TAG, "🎥 Error capturing frame", e)
            result.error("CAPTURE_ERROR", e.message, null)
        }
    }
    
    private fun startPassthroughMode(result: Result) {
        // Quest 3S Passthrough mode
        Log.i(TAG, "🎥 Starting Quest 3S Passthrough mode")
        
        try {
            // Enable passthrough specific settings
            if (captureSession != null && cameraDevice != null) {
                val requestBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                requestBuilder.addTarget(imageReader!!.surface)
                
                // Quest 3S passthrough settings
                requestBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                requestBuilder.set(CaptureRequest.CONTROL_SCENE_MODE, CameraMetadata.CONTROL_SCENE_MODE_ACTION)
                
                captureSession!!.setRepeatingRequest(requestBuilder.build(), null, backgroundHandler)
                
                result.success("Passthrough mode started")
                Log.i(TAG, "🎥 Quest 3S Passthrough mode enabled")
            } else {
                result.error("PASSTHROUGH_ERROR", "Camera not ready for passthrough", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "🎥 Error starting passthrough", e)
            result.error("PASSTHROUGH_ERROR", e.message, null)
        }
    }
    
    private fun stopPassthroughMode(result: Result) {
        Log.i(TAG, "🎥 Stopping Quest 3S Passthrough mode")
        result.success("Passthrough mode stopped")
    }
    
    private fun getCameraInfo(result: Result) {
        try {
            if (frontCameraId != null) {
                val characteristics = cameraManager!!.getCameraCharacteristics(frontCameraId!!)
                val streamMap = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                val outputSizes = streamMap?.getOutputSizes(ImageFormat.JPEG)
                
                val info = mapOf(
                    "cameraId" to frontCameraId,
                    "supportedSizes" to outputSizes?.map { "${it.width}x${it.height}" },
                    "facing" to characteristics.get(CameraCharacteristics.LENS_FACING),
                    "isQuest3S" to true
                )
                
                Log.i(TAG, "🎥 Camera info: $info")
                result.success(info)
            } else {
                result.error("NO_CAMERA_INFO", "No camera available", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "🎥 Error getting camera info", e)
            result.error("CAMERA_INFO_ERROR", e.message, null)
        }
    }
    
    private fun closeCamera() {
        captureSession?.close()
        captureSession = null
        
        cameraDevice?.close()
        cameraDevice = null
        
        imageReader?.close()
        imageReader = null
        
        Log.i(TAG, "🎥 Camera closed")
    }
}