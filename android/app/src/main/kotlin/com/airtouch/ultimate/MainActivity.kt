package com.airtouch.ultimate

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * AirTouch Ultimate - MainActivity
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "AirTouchMainActivity"
        private const val METHOD_CHANNEL = "com.airtouch.ultimate/control"
        private const val EVENT_CHANNEL = "com.airtouch.ultimate/events"
        
        @Volatile
        var instance: MainActivity? = null
    }
    
    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        hideSystemUI()
    }
    
    private fun hideSystemUI() {
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        )
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Configuring Flutter Engine")
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "Event channel listener attached")
                }
                
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "Event channel listener detached")
                }
            })
        
        CameraForegroundService.onPositionUpdate = { x, y ->
            sendPositionEvent(x, y)
        }
        
        CameraForegroundService.onGestureDetected = { gesture ->
            sendGestureEvent(gesture)
        }
        
        Log.d(TAG, "Flutter engine configured successfully")
    }
    
    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "Method call: ${call.method}")
        
        try {
            when (call.method) {
                "startTracking" -> {
                    startCameraService()
                    result.success(true)
                }
                
                "stopTracking" -> {
                    stopCameraService()
                    result.success(true)
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
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (!Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                }
                
                "isAccessibilityEnabled" -> {
                    result.success(AirTouchAccessibilityService.isEnabled)
                }
                
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                
                "getScreenSize" -> {
                    val size = getScreenSize()
                    result.success(mapOf(
                        "width" to size.first,
                        "height" to size.second
                    ))
                }
                
                "isServiceRunning" -> {
                    result.success(CameraForegroundService.isRunning)
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling method call: ${e.message}")
            result.error("ERROR", e.message, null)
        }
    }
    
    private fun startCameraService() {
        Log.d(TAG, "Starting camera foreground service")
        
        try {
            val intent = Intent(this, CameraForegroundService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting camera service: ${e.message}")
        }
    }
    
    private fun stopCameraService() {
        Log.d(TAG, "Stopping camera foreground service")
        
        try {
            val intent = Intent(this, CameraForegroundService::class.java)
            stopService(intent)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping camera service: ${e.message}")
        }
    }
    
    private fun getScreenSize(): Pair<Int, Int> {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bounds = windowManager.currentWindowMetrics.bounds
                Pair(bounds.width(), bounds.height())
            } else {
                val metrics = android.util.DisplayMetrics()
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.getRealMetrics(metrics)
                Pair(metrics.widthPixels, metrics.heightPixels)
            }
        } catch (e: Exception) {
            Pair(1080, 2400)
        }
    }
    
    private fun sendPositionEvent(x: Float, y: Float) {
        handler.post {
            try {
                eventSink?.success(mapOf(
                    "type" to "position",
                    "x" to x,
                    "y" to y
                ))
            } catch (e: Exception) {
                Log.e(TAG, "Error sending position event: ${e.message}")
            }
        }
    }
    
    private fun sendGestureEvent(gesture: String) {
        handler.post {
            try {
                eventSink?.success(mapOf(
                    "type" to "gesture",
                    "gesture" to gesture
                ))
            } catch (e: Exception) {
                Log.e(TAG, "Error sending gesture event: ${e.message}")
            }
        }
    }
    
    override fun onDestroy() {
        Log.d(TAG, "MainActivity onDestroy")
        
        CameraForegroundService.onPositionUpdate = null
        CameraForegroundService.onGestureDetected = null
        
        instance = null
        
        super.onDestroy()
    }
}
