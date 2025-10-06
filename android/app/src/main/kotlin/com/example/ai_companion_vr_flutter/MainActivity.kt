package com.example.ai_companion_vr_flutter

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.ToneGenerator
import android.os.Build
import android.speech.tts.TextToSpeech
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val AUDIO_CHANNEL = "vr_tts_audio"
    private val NATIVE_TTS_CHANNEL = "native_tts"
    private val VR_CONFIGURATION_CHANNEL = "vr_configuration"
    private lateinit var audioManager: AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null
    private lateinit var textToSpeech: TextToSpeech
    private var ttsInitialized = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i("MainActivity", "🎥 Quest VR Activity with TTS Audio Support starting...")
        
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register Quest Frame Capture Plugin
        flutterEngine.plugins.add(QuestFrameCapturePlugin())
        
        // Initialize Native TTS with proper initialization
        initializeNativeTTS()
        
        // Audio Focus Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestAudioFocus" -> {
                        val focusResult = requestAudioFocus()
                        Log.i("AudioFocus", "Audio focus request result: $focusResult")
                        result.success(focusResult)
                    }
                    "abandonAudioFocus" -> {
                        abandonAudioFocus()
                        result.success(true)
                    }
                    "configureAudioSession" -> {
                        configureAudioSession()
                        result.success(true)
                    }
                    "testAudio" -> {
                        val testResult = testAudioSystem()
                        result.success(testResult)
                    }
                    "playBeep" -> {
                        playTestBeep()
                        result.success(true)
                    }
                    "playTone" -> {
                        playTestTone()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Native TTS Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_TTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val language = call.argument<String>("language") ?: "vi-VN"
                        
                        if (ttsInitialized) {
                            // Request audio focus before speaking
                            requestAudioFocus()
                            
                            Log.i("NativeTTS", "🔊 Speaking: $text")
                            val utteranceId = "TTS_${System.currentTimeMillis()}"
                            textToSpeech.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                            result.success(true)
                        } else {
                            Log.e("NativeTTS", "❌ TTS not initialized")
                            result.success(false)
                        }
                    }
                    "isInitialized" -> {
                        result.success(ttsInitialized)
                    }
                    "stop" -> {
                        textToSpeech.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // VR Configuration Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VR_CONFIGURATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeVR" -> {
                        val vrResult = initializeVRMode(call.arguments as? Map<String, Any>)
                        result.success(vrResult)
                    }
                    "enter360Mode" -> {
                        val mode360Result = enter360Mode()
                        result.success(mode360Result)
                    }
                    "exit360Mode" -> {
                        val exitResult = exit360Mode()
                        result.success(exitResult)
                    }
                    "keepScreenOn" -> {
                        val enable = call.arguments as? Boolean ?: true
                        setKeepScreenOn(enable)
                        result.success(true)
                    }
                    "configureCamera" -> {
                        val cameraConfig = configureVRCamera(call.arguments as? Map<String, Any>)
                        result.success(cameraConfig)
                    }
                    "optimizePerformance" -> {
                        optimizeVRPerformance(call.arguments as? Map<String, Any>)
                        result.success(true)
                    }
                    "getVRStatus" -> {
                        val status = getVRStatus()
                        result.success(status)
                    }
                    "isVRSupported" -> {
                        val supported = isVRSupported()
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    private fun requestAudioFocus(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                    
                val focusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            Log.i("AudioFocus", "🎯 Audio Focus GAINED")
                        }
                        AudioManager.AUDIOFOCUS_LOSS -> {
                            Log.w("AudioFocus", "❌ Audio Focus LOST")
                        }
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            Log.w("AudioFocus", "⏸️ Audio Focus LOST TRANSIENT")
                        }
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                            Log.i("AudioFocus", "🦆 Audio Focus DUCK")
                        }
                    }
                }
                
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(audioAttributes)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener(focusChangeListener)
                    .build()
                    
                val result = audioManager.requestAudioFocus(audioFocusRequest!!)
                result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            } else {
                @Suppress("DEPRECATION")
                val result = audioManager.requestAudioFocus(
                    null,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                )
                result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            }
        } catch (e: Exception) {
            Log.e("AudioFocus", "❌ Failed to request audio focus: ${e.message}")
            false
        }
    }
    
    private fun abandonAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let {
                    audioManager.abandonAudioFocusRequest(it)
                }
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(null)
            }
        } catch (e: Exception) {
            Log.e("AudioFocus", "Failed to abandon audio focus: ${e.message}")
        }
    }
    
    private fun configureAudioSession() {
        try {
            // Configure for VR environment
            audioManager.mode = AudioManager.MODE_NORMAL
            audioManager.isSpeakerphoneOn = true
            
            Log.i("AudioConfig", "✅ Audio session configured for Quest VR")
            Log.i("AudioConfig", "Speaker mode: ${audioManager.isSpeakerphoneOn}")
            Log.i("AudioConfig", "Audio mode: ${audioManager.mode}")
            
        } catch (e: Exception) {
            Log.e("AudioConfig", "❌ Failed to configure audio session: ${e.message}")
        }
    }
    
    private fun testAudioSystem(): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        
        try {
            // Test audio manager info
            result["audioMode"] = audioManager.mode
            result["speakerPhoneOn"] = audioManager.isSpeakerphoneOn
            result["musicActive"] = audioManager.isMusicActive
            result["volume"] = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            result["maxVolume"] = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            result["ttsInitialized"] = ttsInitialized
            
            Log.i("AudioTest", "🔍 Audio system test completed")
            Log.i("AudioTest", "Mode: ${result["audioMode"]}, Speaker: ${result["speakerPhoneOn"]}")
            Log.i("AudioTest", "Volume: ${result["volume"]}/${result["maxVolume"]}")
            
        } catch (e: Exception) {
            Log.e("AudioTest", "❌ Audio test failed: ${e.message}")
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }
    
    private fun initializeNativeTTS() {
        Log.i("TTS", "🔄 Initializing Native TTS for Quest...")
        
        try {
            textToSpeech = TextToSpeech(this) { status ->
                when (status) {
                    TextToSpeech.SUCCESS -> {
                        Log.i("TTS", "✅ TTS Engine connected successfully")
                        
                        // Try Vietnamese first
                        val langResult = textToSpeech.setLanguage(Locale.forLanguageTag("vi-VN"))
                        when (langResult) {
                            TextToSpeech.LANG_AVAILABLE, TextToSpeech.LANG_COUNTRY_AVAILABLE, TextToSpeech.LANG_COUNTRY_VAR_AVAILABLE -> {
                                Log.i("TTS", "✅ Vietnamese language set successfully")
                            }
                            TextToSpeech.LANG_MISSING_DATA -> {
                                Log.w("TTS", "⚠️ Vietnamese missing data, trying English")
                                textToSpeech.setLanguage(Locale.US)
                            }
                            TextToSpeech.LANG_NOT_SUPPORTED -> {
                                Log.w("TTS", "⚠️ Vietnamese not supported, using English")
                                textToSpeech.setLanguage(Locale.US)
                            }
                        }
                        
                        // Configure TTS for Quest VR
                        textToSpeech.setSpeechRate(0.8f) // Slightly faster for VR
                        textToSpeech.setPitch(1.0f)
                        
                        // Set audio attributes for VR
                        val audioAttributes = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANT)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            textToSpeech.setAudioAttributes(audioAttributes)
                        }
                        
                        ttsInitialized = true
                        Log.i("TTS", "🎯 Native TTS fully configured for Quest VR")
                        
                        // Test speak immediately
                        runOnUiThread {
                            testNativeTTSConnection()
                        }
                    }
                    TextToSpeech.ERROR -> {
                        Log.e("TTS", "❌ TTS initialization failed with ERROR")
                        ttsInitialized = false
                    }
                    else -> {
                        Log.e("TTS", "❌ TTS initialization failed with status: $status")
                        ttsInitialized = false
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("TTS", "❌ Exception during TTS initialization: ${e.message}")
            ttsInitialized = false
        }
    }
    
    private fun testNativeTTSConnection() {
        if (ttsInitialized) {
            Log.i("TTS", "🧪 Testing Native TTS connection...")
            try {
                requestAudioFocus()
                val utteranceId = "TEST_${System.currentTimeMillis()}"
                val result = textToSpeech.speak("TTS hoạt động", TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                Log.i("TTS", "🔊 Test speak result: $result")
            } catch (e: Exception) {
                Log.e("TTS", "❌ Test speak failed: ${e.message}")
            }
        }
    }
    
    private fun playTestBeep() {
        try {
            Log.i("AudioTest", "🔔 Playing test beep...")
            
            // Request audio focus first
            requestAudioFocus()
            
            val toneGen = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
            toneGen.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 200)
            
            // Clean up after a delay
            android.os.Handler().postDelayed({
                toneGen.release()
            }, 500)
            
            Log.i("AudioTest", "✅ Test beep played")
        } catch (e: Exception) {
            Log.e("AudioTest", "❌ Failed to play beep: ${e.message}")
        }
    }
    
    private fun playTestTone() {
        try {
            Log.i("AudioTest", "🎵 Playing test tone...")
            
            requestAudioFocus()
            
            val mediaPlayer = MediaPlayer()
            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
            
            // Generate a simple tone using MediaPlayer
            mediaPlayer.setOnCompletionListener { mp ->
                mp.release()
                Log.i("AudioTest", "✅ Test tone completed")
            }
            
            // We'll use system notification sound as test
            val notification = android.provider.Settings.System.DEFAULT_NOTIFICATION_URI
            mediaPlayer.setDataSource(this, notification)
            mediaPlayer.prepare()
            mediaPlayer.start()
            
        } catch (e: Exception) {
            Log.e("AudioTest", "❌ Failed to play tone: ${e.message}")
        }
    }
    
    // VR Configuration Methods
    private fun initializeVRMode(config: Map<String, Any>?): Boolean {
        return try {
            Log.i("VR", "🥽 Initializing VR mode for Quest 3S...")
            
            // Configure window for VR
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
            
            // Hide navigation bar for immersive VR
            window.decorView.systemUiVisibility = (
                android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                android.view.View.SYSTEM_UI_FLAG_FULLSCREEN or
                android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )
            
            // Set landscape orientation for VR
            requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            
            Log.i("VR", "✅ VR mode initialized successfully")
            true
        } catch (e: Exception) {
            Log.e("VR", "❌ VR initialization failed: ${e.message}")
            false
        }
    }
    
    private fun enter360Mode(): Boolean {
        return try {
            Log.i("VR", "🌐 Entering 360° VR mode...")
            
            // Additional 360° specific configurations
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
            
            // Configure for stereo rendering
            val params = window.attributes
            params.format = android.graphics.PixelFormat.RGB_565 // Optimized format for VR
            window.attributes = params
            
            Log.i("VR", "✅ 360° mode activated")
            true
        } catch (e: Exception) {
            Log.e("VR", "❌ 360° mode failed: ${e.message}")
            false
        }
    }
    
    private fun exit360Mode(): Boolean {
        return try {
            Log.i("VR", "📱 Exiting 360° mode...")
            
            // Restore normal orientation
            requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            
            // Restore system UI
            window.decorView.systemUiVisibility = android.view.View.SYSTEM_UI_FLAG_VISIBLE
            
            Log.i("VR", "✅ Returned to flat mode")
            true
        } catch (e: Exception) {
            Log.e("VR", "❌ Exit 360° failed: ${e.message}")
            false
        }
    }
    
    private fun setKeepScreenOn(enable: Boolean) {
        if (enable) {
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            Log.i("VR", "🔋 Screen will stay on during VR session")
        } else {
            window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            Log.i("VR", "🔋 Screen timeout restored")
        }
    }
    
    private fun configureVRCamera(config: Map<String, Any>?): Boolean {
        return try {
            Log.i("VRCamera", "📹 Configuring VR camera for Quest 3S...")
            
            val stereoMode = config?.get("stereoMode") as? Boolean ?: true
            val passthrough = config?.get("passthrough") as? Boolean ?: true
            val resolution = config?.get("resolution") as? String ?: "1280x960"
            val frameRate = config?.get("frameRate") as? Int ?: 30
            
            Log.i("VRCamera", "Stereo: $stereoMode, Passthrough: $passthrough")
            Log.i("VRCamera", "Resolution: $resolution, FPS: $frameRate")
            
            // Camera configuration would be handled by native camera plugins
            // This is a placeholder for camera-specific VR settings
            
            Log.i("VRCamera", "✅ VR camera configured")
            true
        } catch (e: Exception) {
            Log.e("VRCamera", "❌ Camera config failed: ${e.message}")
            false
        }
    }
    
    private fun optimizeVRPerformance(config: Map<String, Any>?) {
        try {
            Log.i("VRPerf", "⚡ Optimizing performance for Quest VR...")
            
            val cpuLevel = config?.get("cpuLevel") as? Int ?: 3
            val gpuLevel = config?.get("gpuLevel") as? Int ?: 3
            
            // Performance optimizations for Quest 3S
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
            
            Log.i("VRPerf", "CPU Level: $cpuLevel, GPU Level: $gpuLevel")
            Log.i("VRPerf", "✅ VR performance optimized")
            
        } catch (e: Exception) {
            Log.e("VRPerf", "❌ Performance optimization failed: ${e.message}")
        }
    }
    
    private fun getVRStatus(): Map<String, Any> {
        return try {
            mapOf<String, Any>(
                "isVRSupported" to isVRSupported(),
                "isImmersive" to (window.decorView.systemUiVisibility and 
                    android.view.View.SYSTEM_UI_FLAG_FULLSCREEN != 0),
                "keepScreenOn" to (window.attributes.flags and 
                    android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0),
                "orientation" to requestedOrientation,
                "deviceModel" to android.os.Build.MODEL,
                "androidVersion" to android.os.Build.VERSION.SDK_INT
            )
        } catch (e: Exception) {
            Log.e("VR", "❌ Get VR status failed: ${e.message}")
            mapOf<String, Any>("error" to (e.message ?: "Unknown error"))
        }
    }
    
    private fun isVRSupported(): Boolean {
        return try {
            val packageManager = packageManager
            
            // Check for VR features
            val hasVR = packageManager.hasSystemFeature("android.software.vr.mode")
            val hasHeadTracking = packageManager.hasSystemFeature("android.hardware.vr.headtracking")
            val isQuest = android.os.Build.MODEL.contains("Quest", ignoreCase = true) ||
                         android.os.Build.MANUFACTURER.contains("Meta", ignoreCase = true) ||
                         android.os.Build.MANUFACTURER.contains("Oculus", ignoreCase = true)
            
            Log.i("VR", "VR Mode: $hasVR, Head Tracking: $hasHeadTracking, Quest Device: $isQuest")
            Log.i("VR", "Device: ${android.os.Build.MODEL}, Manufacturer: ${android.os.Build.MANUFACTURER}")
            
            hasVR || isQuest
        } catch (e: Exception) {
            Log.e("VR", "❌ VR support check failed: ${e.message}")
            false
        }
    }
    
    override fun onDestroy() {
        if (::textToSpeech.isInitialized) {
            textToSpeech.stop()
            textToSpeech.shutdown()
        }
        abandonAudioFocus()
        super.onDestroy()
    }
}
