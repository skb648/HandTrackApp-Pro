package com.airtouch.airtouch_ultimate

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Point
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.ImageView
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * AirTouch Ultimate - Main Activity
 * 
 * CRASH-PROOF Implementation for Android 16+
 * - All operations wrapped in try-catch
 * - Defensive initialization
 * - Proper coordinate mapping
 * - Real mouse pointer cursor
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "AirTouch"
        private const val CHANNEL = "com.airtouch.ultimate/control"
        const val NOTIFICATION_CHANNEL_ID = "airtouch_cursor_channel"
        const val NOTIFICATION_ID = 1001
        
        @Volatile
        var accessibilityServiceInstance: AirTouchAccessibilityService? = null
        
        @Volatile
        var instance: MainActivity? = null
        
        fun isAccessibilityEnabled(context: Context): Boolean {
            return try {
                accessibilityServiceInstance != null
            } catch (e: Exception) {
                Log.e(TAG, "Accessibility check error: ${e.message}")
                false
            }
        }
    }
    
    // Window Manager for cursor overlay
    private var windowManager: WindowManager? = null
    private var cursorView: ImageView? = null
    private var cursorParams: WindowManager.LayoutParams? = null
    private var isCursorVisible = false
    
    // Coroutines
    private val uiHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    
    // Screen dimensions - will be updated
    private var screenWidth = 1080
    private var screenHeight = 2400
    
    // Cursor position with EMA smoothing
    private var currentX = 540f
    private var currentY = 1200f
    private var smoothedX = 540f
    private var smoothedY = 1200f
    
    // EMA smoothing factor (0.15 = smooth, 0.3 = responsive)
    private val smoothingAlpha = 0.2f
    
    // Click debouncing
    private var lastClickTime = 0L
    private val clickDebounceMs = 300L

    // ==========================================
    // FLUTTER ENGINE CONFIGURATION
    // ==========================================
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        instance = this
        
        // Get screen dimensions safely
        try {
            val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            val displayMetrics = DisplayMetrics()
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bounds = windowManager.currentWindowMetrics.bounds
                screenWidth = bounds.width()
                screenHeight = bounds.height()
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.getRealMetrics(displayMetrics)
                screenWidth = displayMetrics.widthPixels
                screenHeight = displayMetrics.heightPixels
            }
            
            Log.d(TAG, "Screen dimensions: ${screenWidth}x${screenHeight}")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get screen dimensions: ${e.message}")
            // Use safe defaults
            screenWidth = 1080
            screenHeight = 2400
        }
        
        // Initialize center position
        smoothedX = screenWidth / 2f
        smoothedY = screenHeight / 2f
        
        // Create notification channel
        createNotificationChannel()
        
        // Setup method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
        
        Log.d(TAG, "Flutter engine configured")
    }
    
    private fun handleMethodCall(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                when (call.method) {
                    "isAccessibilityEnabled" -> {
                        val enabled = isAccessibilityEnabled(this@MainActivity)
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
                    
                    "showOverlay" -> {
                        withContext(Dispatchers.Main) {
                            showCursorOverlay()
                        }
                        result.success(true)
                    }
                    
                    "hideOverlay" -> {
                        withContext(Dispatchers.Main) {
                            hideCursorOverlay()
                        }
                        result.success(true)
                    }
                    
                    "updateCursorPosition" -> {
                        val x = call.argument<Double>("x")?.toFloat() ?: 0.5f
                        val y = call.argument<Double>("y")?.toFloat() ?: 0.5f
                        withContext(Dispatchers.Main) {
                            updateCursorFromNormalized(x, y)
                        }
                        result.success(true)
                    }
                    
                    "performClick" -> {
                        val x = call.argument<Double>("x")?.toFloat() ?: smoothedX
                        val y = call.argument<Double>("y")?.toFloat() ?: smoothedY
                        val success = performSystemClick(x, y)
                        result.success(success)
                    }
                    
                    "performDoubleTap" -> {
                        val x = call.argument<Double>("x")?.toFloat() ?: smoothedX
                        val y = call.argument<Double>("y")?.toFloat() ?: smoothedY
                        val success = performDoubleTap(x, y)
                        result.success(success)
                    }
                    
                    "performSwipe" -> {
                        val startX = call.argument<Double>("startX")?.toFloat() ?: 0f
                        val startY = call.argument<Double>("startY")?.toFloat() ?: 0f
                        val endX = call.argument<Double>("endX")?.toFloat() ?: 0f
                        val endY = call.argument<Double>("endY")?.toFloat() ?: 0f
                        val duration = call.argument<Int>("duration")?.toLong() ?: 300L
                        val success = performSwipe(startX, startY, endX, endY, duration)
                        result.success(success)
                    }
                    
                    "getScreenSize" -> {
                        result.success(mapOf(
                            "width" to screenWidth,
                            "height" to screenHeight
                        ))
                    }
                    
                    "canDrawOverlays" -> {
                        val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this@MainActivity)
                        } else {
                            true
                        }
                        result.success(canDraw)
                    }
                    
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this@MainActivity)) {
                            try {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    android.net.Uri.parse("package:$packageName")
                                )
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
                    
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Method call error: ${e.message}")
                result.error("EXCEPTION", e.message, null)
            }
        }
    }

    // ==========================================
    // CURSOR OVERLAY - REAL MOUSE POINTER
    // ==========================================
    
    @SuppressLint("ClickableViewAccessibility")
    private fun showCursorOverlay() {
        if (isCursorVisible) {
            Log.d(TAG, "Cursor already visible")
            return
        }
        
        if (!canDrawOverlays()) {
            Log.e(TAG, "Cannot draw overlays - permission not granted")
            return
        }
        
        try {
            windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            
            // Create cursor ImageView
            cursorView = ImageView(this)
            
            // Load real mouse pointer cursor
            val cursorDrawable = createMousePointerDrawable()
            cursorView?.setImageDrawable(cursorDrawable)
            cursorView?.measure(
                View.MeasureSpec.makeMeasureSpec(96, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(96, View.MeasureSpec.EXACTLY)
            )
            cursorView?.layout(0, 0, 96, 96)
            
            // Window params for overlay
            val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            cursorParams = WindowManager.LayoutParams(
                96,
                96,
                layoutType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = smoothedX.toInt()
                y = smoothedY.toInt()
            }
            
            windowManager?.addView(cursorView, cursorParams)
            isCursorVisible = true
            
            Log.d(TAG, "Cursor overlay shown at (${smoothedX}, ${smoothedY})")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show cursor overlay: ${e.message}")
            isCursorVisible = false
        }
    }
    
    private fun hideCursorOverlay() {
        try {
            if (cursorView != null && windowManager != null) {
                windowManager?.removeView(cursorView)
                cursorView = null
                cursorParams = null
            }
            isCursorVisible = false
            Log.d(TAG, "Cursor overlay hidden")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hide cursor: ${e.message}")
        }
    }
    
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    /**
     * Create a real mouse pointer arrow cursor
     */
    private fun createMousePointerDrawable(): Drawable {
        val size = 72
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        
        // Create arrow pointer path
        val path = Path().apply {
            // Mouse pointer arrow shape
            moveTo(4f, 4f)      // Tip of arrow
            lineTo(4f, 56f)     // Left edge down
            lineTo(16f, 44f)    // Inner left
            lineTo(26f, 64f)    // Bottom left of stem
            lineTo(34f, 60f)    // Bottom right of stem
            lineTo(24f, 40f)    // Inner right
            lineTo(40f, 40f)    // Right edge
            close()
        }
        
        // Draw shadow first (offset)
        val shadowPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#66000000")
            style = Paint.Style.FILL
        }
        canvas.save()
        canvas.translate(3f, 3f)
        canvas.drawPath(path, shadowPaint)
        canvas.restore()
        
        // Draw white fill
        val fillPaint = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawPath(path, fillPaint)
        
        // Draw black outline
        val outlinePaint = Paint().apply {
            isAntiAlias = true
            color = Color.BLACK
            style = Paint.Style.STROKE
            strokeWidth = 2f
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(path, outlinePaint)
        
        return BitmapDrawable(resources, bitmap)
    }

    // ==========================================
    // COORDINATE MAPPING
    // ==========================================
    
    /**
     * Update cursor from normalized coordinates (0-1)
     * X-axis is mirrored for natural mirror behavior
     */
    private fun updateCursorFromNormalized(normalizedX: Float, normalizedY: Float) {
        // Clamp input
        val clampedX = normalizedX.coerceIn(0f, 1f)
        val clampedY = normalizedY.coerceIn(0f, 1f)
        
        // Mirror X for natural mirror movement
        val targetX = (1f - clampedX) * screenWidth
        val targetY = clampedY * screenHeight
        
        // Apply EMA smoothing
        smoothedX = smoothingAlpha * targetX + (1f - smoothingAlpha) * smoothedX
        smoothedY = smoothingAlpha * targetY + (1f - smoothingAlpha) * smoothedY
        
        // Update cursor position
        updateCursorPosition(smoothedX, smoothedY)
    }
    
    private fun updateCursorPosition(x: Float, y: Float) {
        if (!isCursorVisible || cursorParams == null || windowManager == null) {
            return
        }
        
        try {
            // Offset to position cursor tip at the exact point
            cursorParams?.x = x.toInt() - 4  // Cursor tip offset
            cursorParams?.y = y.toInt() - 4
            
            windowManager?.updateViewLayout(cursorView, cursorParams)
        } catch (e: Exception) {
            // View might have been detached
            Log.e(TAG, "Failed to update cursor position: ${e.message}")
        }
    }

    // ==========================================
    // GESTURE ACTIONS
    // ==========================================
    
    private fun performSystemClick(x: Float, y: Float): Boolean {
        // Debounce
        val now = System.currentTimeMillis()
        if (now - lastClickTime < clickDebounceMs) {
            return false
        }
        lastClickTime = now
        
        return try {
            val service = accessibilityServiceInstance
            if (service != null) {
                Log.d(TAG, "Performing click at ($x, $y)")
                service.performClick(x, y)
            } else {
                Log.w(TAG, "Accessibility service not available")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Click failed: ${e.message}")
            false
        }
    }
    
    private fun performDoubleTap(x: Float, y: Float): Boolean {
        return try {
            val service = accessibilityServiceInstance
            if (service != null) {
                service.performDoubleTap(x, y)
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Double tap failed: ${e.message}")
            false
        }
    }
    
    private fun performSwipe(startX: Float, startY: Float, endX: Float, endY: Float, duration: Long): Boolean {
        return try {
            val service = accessibilityServiceInstance
            if (service != null) {
                service.performSwipe(startX, startY, endX, endY, duration)
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Swipe failed: ${e.message}")
            false
        }
    }

    // ==========================================
    // NOTIFICATIONS
    // ==========================================
    
    private fun createNotificationChannel() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "AirTouch Cursor Service",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Hand tracking cursor control service"
                    setShowBadge(false)
                }
                
                val notificationManager = getSystemService(NotificationManager::class.java)
                notificationManager.createNotificationChannel(channel)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create notification channel: ${e.message}")
        }
    }

    // ==========================================
    // LIFECYCLE
    // ==========================================
    
    override fun onDestroy() {
        Log.d(TAG, "MainActivity onDestroy")
        try {
            hideCursorOverlay()
        } catch (e: Exception) {
            Log.e(TAG, "Error in onDestroy: ${e.message}")
        }
        instance = null
        super.onDestroy()
    }
}

// ==========================================
// ACCESSIBILITY SERVICE
// ==========================================

/**
 * Accessibility Service for system-level gesture injection
 */
class AirTouchAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "AirTouchAccessibility"
        @Volatile
        var isServiceEnabled = false
    }
    
    private val handler = Handler(Looper.getMainLooper())
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        try {
            MainActivity.accessibilityServiceInstance = this
            isServiceEnabled = true
            Log.d(TAG, "Accessibility Service Connected")
        } catch (e: Exception) {
            Log.e(TAG, "Service connection error: ${e.message}")
        }
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not needed for gesture injection
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }
    
    override fun onDestroy() {
        isServiceEnabled = false
        MainActivity.accessibilityServiceInstance = null
        super.onDestroy()
    }
    
    /**
     * Perform a single tap/click at the specified coordinates
     */
    fun performClick(x: Float, y: Float): Boolean {
        return try {
            val path = Path().apply {
                moveTo(x, y)
            }
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 10))
                .build()
            
            val result = dispatchGesture(gesture, null, null)
            Log.d(TAG, "Click at ($x, $y) - result: $result")
            result
        } catch (e: Exception) {
            Log.e(TAG, "Click failed: ${e.message}")
            false
        }
    }
    
    /**
     * Perform a double tap at the specified coordinates
     */
    fun performDoubleTap(x: Float, y: Float): Boolean {
        return try {
            val path1 = Path().apply { moveTo(x, y) }
            val path2 = Path().apply { moveTo(x, y) }
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path1, 0, 50))
                .addStroke(GestureDescription.StrokeDescription(path2, 150, 50))
                .build()
            
            dispatchGesture(gesture, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "Double tap failed: ${e.message}")
            false
        }
    }
    
    /**
     * Perform a swipe gesture
     */
    fun performSwipe(startX: Float, startY: Float, endX: Float, endY: Float, duration: Long): Boolean {
        return try {
            val path = Path().apply {
                moveTo(startX, startY)
                lineTo(endX, endY)
            }
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
                .build()
            
            dispatchGesture(gesture, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "Swipe failed: ${e.message}")
            false
        }
    }
}
