package com.airtouch.airtouch_ultimate

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * AirTouch Ultimate - Main Activity
 * Production-ready hand tracking controller with MediaPipe Hands
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "AirTouch"
        private const val METHOD_CHANNEL = "com.airtouch.ultimate/control"
        private const val EVENT_CHANNEL = "com.airtouch.ultimate/events"
        const val NOTIFICATION_CHANNEL_ID = "airtouch_notification_channel"
        const val NOTIFICATION_ID = 1000
        
        @Volatile
        var instance: MainActivity? = null
        
        fun isAccessibilityEnabled(context: Context): Boolean {
            return try {
                AirTouchAccessibilityService.instance != null
            } catch (e: Exception) {
                Log.e(TAG, "Accessibility check error: ${e.message}")
                false
            }
        }
    }
    
    private var eventSink: EventChannel.EventSink? = null
    private var screenWidth = 1080
    private var screenHeight = 2400
    private val handler = Handler(Looper.getMainLooper())
    
    // Periodic update runnable
    private val updateRunnable = object : Runnable {
        override fun run() {
            if (CameraForegroundService.isRunning && eventSink != null) {
                // Send position update
                val positionMap = mapOf(
                    "type" to "position",
                    "x" to CameraForegroundService.cursorX,
                    "y" to CameraForegroundService.cursorY
                )
                handler.post { eventSink?.success(positionMap) }
                
                // Send FPS update
                val fpsMap = mapOf(
                    "type" to "fps",
                    "fps" to CameraForegroundService.currentFps
                )
                handler.post { eventSink?.success(fpsMap) }
            }
            
            // Schedule next update
            if (eventSink != null) {
                handler.postDelayed(this, 50) // 20 FPS for UI updates
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        getScreenDimensions()
        createNotificationChannel()
        Log.d(TAG, "=== MainActivity onCreate ===")
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Configuring Flutter Engine")
        
        // Method Channel for control commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }
        
        // Event Channel for streaming data
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    Log.d(TAG, "Event Channel onListen")
                    eventSink = sink
                    setupCallbacks()
                    // Start periodic updates
                    handler.post(updateRunnable)
                }
                
                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "Event Channel onCancel")
                    eventSink = null
                    clearCallbacks()
                    handler.removeCallbacks(updateRunnable)
                }
            })
        
        Log.d(TAG, "Flutter engine configured")
    }
    
    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "Method called: ${call.method}")
        
        when (call.method) {
            "isAccessibilityEnabled" -> {
                val enabled = isAccessibilityEnabled(this)
                result.success(enabled)
            }
            
            "openAccessibilitySettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to open accessibility settings: ${e.message}")
                    result.error("ERROR", e.message, null)
                }
            }
            
            "canDrawOverlays" -> {
                val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(this)
                } else {
                    true
                }
                result.success(canDraw)
            }
            
            "requestOverlayPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName")
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to request overlay permission: ${e.message}")
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.success(true)
                }
            }
            
            "startTracking" -> {
                try {
                    Log.d(TAG, ">>> Starting Camera Service")
                    startCameraService()
                    result.success(true)
                    Log.d(TAG, ">>> Camera Service Started Successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start tracking: ${e.message}")
                    result.error("ERROR", e.message, null)
                }
            }
            
            "stopTracking" -> {
                try {
                    Log.d(TAG, ">>> Stopping Camera Service")
                    stopCameraService()
                    result.success(true)
                    Log.d(TAG, ">>> Camera Service Stopped")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to stop tracking: ${e.message}")
                    result.error("ERROR", e.message, null)
                }
            }
            
            "getScreenSize" -> {
                result.success(mapOf(
                    "width" to screenWidth,
                    "height" to screenHeight
                ))
            }
            
            "getCursorState" -> {
                result.success(mapOf(
                    "x" to CameraForegroundService.cursorX,
                    "y" to CameraForegroundService.cursorY,
                    "gesture" to CameraForegroundService.currentGesture,
                    "isRunning" to CameraForegroundService.isRunning,
                    "fps" to CameraForegroundService.currentFps
                ))
            }
            
            "vibrate" -> {
                try {
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(android.os.VibrationEffect.createOneShot(50, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(50)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Vibration error: ${e.message}")
                }
                result.success(true)
            }
            
            else -> result.notImplemented()
        }
    }
    
    private fun setupCallbacks() {
        Log.d(TAG, "Setting up callbacks")
        
        // Gesture callback
        CameraForegroundService.onGestureDetected = { gesture ->
            handler.post {
                Log.d(TAG, ">>> Gesture detected: $gesture")
                eventSink?.success(mapOf("type" to "gesture", "gesture" to gesture))
            }
        }
        
        // Position callback (real-time from MediaPipe)
        CameraForegroundService.onPositionUpdate = { x, y ->
            // Position updates are handled by the updateRunnable
            // But we can also send them here for more responsive updates
        }
        
        // FPS callback
        CameraForegroundService.onFpsUpdate = { fps ->
            // FPS updates are handled by the updateRunnable
        }
    }
    
    private fun clearCallbacks() {
        Log.d(TAG, "Clearing callbacks")
        CameraForegroundService.onGestureDetected = null
        CameraForegroundService.onPositionUpdate = null
        CameraForegroundService.onFpsUpdate = null
    }
    
    private fun getScreenDimensions() {
        try {
            val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bounds = windowManager.currentWindowMetrics.bounds
                screenWidth = bounds.width()
                screenHeight = bounds.height()
            } else {
                @Suppress("DEPRECATION")
                val metrics = DisplayMetrics()
                windowManager.defaultDisplay.getRealMetrics(metrics)
                screenWidth = metrics.widthPixels
                screenHeight = metrics.heightPixels
            }
            Log.d(TAG, "Screen: ${screenWidth}x${screenHeight}")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting screen: ${e.message}")
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "AirTouch Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Hand tracking cursor control"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun startCameraService() {
        Log.d(TAG, "Starting camera foreground service")
        
        val intent = Intent(this, CameraForegroundService::class.java)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
    
    private fun stopCameraService() {
        Log.d(TAG, "Stopping camera foreground service")
        
        clearCallbacks()
        
        val intent = Intent(this, CameraForegroundService::class.java)
        stopService(intent)
    }
    
    override fun onDestroy() {
        Log.d(TAG, "MainActivity onDestroy")
        stopCameraService()
        handler.removeCallbacks(updateRunnable)
        instance = null
        super.onDestroy()
    }
}

// ==========================================
// ACCESSIBILITY SERVICE
// ==========================================

/**
 * Accessibility Service for system-level gestures
 */
class AirTouchAccessibilityService : android.accessibilityservice.AccessibilityService() {
    
    companion object {
        private const val TAG = "AirTouchAccessibility"
        
        @Volatile
        var instance: AirTouchAccessibilityService? = null
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "=== Accessibility Service Connected ===")
    }
    
    override fun onAccessibilityEvent(event: android.view.accessibility.AccessibilityEvent?) {
        // Not needed
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }
    
    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
    
    /**
     * Perform a single tap at screen coordinates
     */
    fun performClick(screenX: Float, screenY: Float): Boolean {
        return try {
            Log.d(TAG, ">>> performClick at ($screenX, $screenY)")
            
            val path = android.graphics.Path().apply {
                moveTo(screenX, screenY)
            }
            
            val gesture = android.accessibilityservice.GestureDescription.Builder()
                .addStroke(android.accessibilityservice.GestureDescription.StrokeDescription(path, 0, 10))
                .build()
            
            val result = dispatchGesture(gesture, null, null)
            Log.d(TAG, ">>> Click result: $result")
            result
        } catch (e: Exception) {
            Log.e(TAG, "Click failed: ${e.message}")
            false
        }
    }
    
    /**
     * Perform a swipe gesture
     */
    fun performSwipe(startX: Float, startY: Float, endX: Float, endY: Float, duration: Long): Boolean {
        return try {
            val path = android.graphics.Path().apply {
                moveTo(startX, startY)
                lineTo(endX, endY)
            }
            
            val gesture = android.accessibilityservice.GestureDescription.Builder()
                .addStroke(android.accessibilityservice.GestureDescription.StrokeDescription(path, 0, duration))
                .build()
            
            dispatchGesture(gesture, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "Swipe failed: ${e.message}")
            false
        }
    }
}
