package com.airtouch.ultimate

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityManager
import android.widget.FrameLayout
import android.widget.ImageView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * MAIN ACTIVITY - Flutter ↔ Native Bridge
 * ═══════════════════════════════════════════════════════════════════════════════
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val OVERLAY_CHANNEL = "com.airtouch.ultimate/overlay"
        const val ACCESSIBILITY_CHANNEL = "com.airtouch.ultimate/accessibility"
        const val FOREGROUND_CHANNEL = "com.airtouch.ultimate/foreground"
        const val TAG = "AirTouchUltimate"

        @Volatile
        var instance: MainActivity? = null

        @Volatile
        var accessibilityServiceInstance: AirTouchAccessibilityService? = null
    }

    private lateinit var overlayChannel: MethodChannel
    private lateinit var accessibilityChannel: MethodChannel
    private lateinit var foregroundChannel: MethodChannel
    private lateinit var windowManager: WindowManager
    
    // Cursor overlay
    private var cursorView: View? = null
    private var cursorImageView: ImageView? = null
    private var cursorGlowView: ImageView? = null
    private var isCursorVisible = false
    private var cursorParams: WindowManager.LayoutParams? = null
    private var currentCursorState: String = "normal"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // ═══════════════════════════════════════════════════════════
        // OVERLAY CHANNEL - Cursor Control
        // ═══════════════════════════════════════════════════════════
        overlayChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OVERLAY_CHANNEL
        )

        overlayChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "hasOverlayPermission" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }

                    "requestOverlayPermission" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivityForResult(intent, 1234)
                        result.success(true)
                    }

                    "initialize" -> result.success(true)

                    "showCursor" -> {
                        val x = call.argument<Double>("x")?.toFloat() ?: getScreenCenterX()
                        val y = call.argument<Double>("y")?.toFloat() ?: getScreenCenterY()
                        val success = showMousePointerCursor(x, y)
                        result.success(success)
                    }

                    "hideCursor" -> {
                        hideCursorOverlay()
                        result.success(true)
                    }

                    "updateCursorPosition" -> {
                        val x = call.argument<Double>("x")?.toFloat() ?: 0f
                        val y = call.argument<Double>("y")?.toFloat() ?: 0f
                        updateCursorPositionNormalized(x, y)
                        result.success(true)
                    }

                    "updateCursorPositionAbsolute" -> {
                        val x = call.argument<Double>("x")?.toFloat() ?: 0f
                        val y = call.argument<Double>("y")?.toFloat() ?: 0f
                        updateCursorPositionAbsolute(x, y)
                        result.success(true)
                    }

                    "updateCursorState" -> {
                        val state = call.argument<String>("state") ?: "normal"
                        updateCursorVisualState(state)
                        result.success(true)
                    }

                    "updateCursorRotation" -> {
                        val angle = call.argument<Double>("angle")?.toFloat() ?: 0f
                        updateCursorRotation(angle)
                        result.success(true)
                    }

                    "getScreenSize" -> {
                        val size = getScreenSize()
                        result.success(mapOf(
                            "width" to size.first.toDouble(),
                            "height" to size.second.toDouble()
                        ))
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Overlay channel error: ${e.message}")
                result.error("ERROR", e.message, null)
            }
        }

        // ═══════════════════════════════════════════════════════════
        // ACCESSIBILITY CHANNEL - Gesture Execution
        // ═══════════════════════════════════════════════════════════
        accessibilityChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCESSIBILITY_CHANNEL
        )

        accessibilityChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isServiceEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }

                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }

                    "performTap" -> {
                        val x = call.argument<Double>("x")?.toFloat() ?: 0f
                        val y = call.argument<Double>("y")?.toFloat() ?: 0f
                        val success = performAccessibilityTap(x, y)
                        result.success(success)
                    }

                    "performDoubleTap" -> {
                        val x = call.argument<Double>("x")?.toFloat() ?: 0f
                        val y = call.argument<Double>("y")?.toFloat() ?: 0f
                        val service = accessibilityServiceInstance
                        if (service != null) {
                            service.performTap(x, y)
                            Thread.sleep(100)
                            val success = service.performTap(x, y)
                            result.success(success)
                        } else {
                            result.success(false)
                        }
                    }

                    "performLongPress" -> {
                        val x = call.argument<Double>("x")?.toFloat() ?: 0f
                        val y = call.argument<Double>("y")?.toFloat() ?: 0f
                        val service = accessibilityServiceInstance
                        result.success(service?.performLongPress(x, y) ?: false)
                    }

                    "performSwipe" -> {
                        val startX = call.argument<Double>("startX")?.toFloat() ?: 0f
                        val startY = call.argument<Double>("startY")?.toFloat() ?: 0f
                        val endX = call.argument<Double>("endX")?.toFloat() ?: 0f
                        val endY = call.argument<Double>("endY")?.toFloat() ?: 0f
                        val duration = call.argument<Number>("duration")?.toLong() ?: 300L
                        val service = accessibilityServiceInstance
                        result.success(service?.performSwipe(startX, startY, endX, endY, duration) ?: false)
                    }

                    "performScroll" -> {
                        val direction = call.argument<String>("direction") ?: "up"
                        val distance = call.argument<Double>("distance")?.toFloat() ?: 300f
                        val success = performAccessibilityScroll(direction, distance)
                        result.success(success)
                    }

                    "performGlobalAction" -> {
                        val action = call.argument<String>("action") ?: "back"
                        val success = performGlobalAction(action)
                        result.success(success)
                    }

                    "goBack" -> {
                        val service = accessibilityServiceInstance
                        result.success(service?.goBack() ?: false)
                    }

                    "openRecents" -> {
                        val service = accessibilityServiceInstance
                        result.success(service?.openRecents() ?: false)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Accessibility channel error: ${e.message}")
                result.error("ERROR", e.message, null)
            }
        }

        // ═══════════════════════════════════════════════════════════
        // FOREGROUND CHANNEL - Background Service Control
        // ═══════════════════════════════════════════════════════════
        foregroundChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FOREGROUND_CHANNEL
        )

        foregroundChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, HandTrackingForegroundService::class.java)
                        intent.action = HandTrackingForegroundService.ACTION_START
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }

                    "stopService" -> {
                        val intent = Intent(this, HandTrackingForegroundService::class.java)
                        intent.action = HandTrackingForegroundService.ACTION_STOP
                        stopService(intent)
                        result.success(true)
                    }

                    "isServiceRunning" -> {
                        result.success(HandTrackingForegroundService.isRunning)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Foreground channel error: ${e.message}")
                result.error("ERROR", e.message, null)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MOUSE POINTER CURSOR OVERLAY
    // ═══════════════════════════════════════════════════════════════

    /**
     * Show mouse pointer cursor at specified position
     */
    private fun showMousePointerCursor(x: Float, y: Float): Boolean {
        if (cursorView != null) {
            updateCursorPositionAbsolute(x, y)
            return true
        }

        if (!Settings.canDrawOverlays(this)) {
            Log.e(TAG, "❌ No overlay permission")
            return false
        }

        val cursorSize = dpToPx(32)
        val containerSize = dpToPx(48)

        cursorParams = WindowManager.LayoutParams(
            containerSize,
            containerSize,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            this.x = (x - cursorSize / 2).toInt()
            this.y = (y - cursorSize / 4).toInt()
        }

        cursorView = createMousePointerView()

        return try {
            windowManager.addView(cursorView, cursorParams)
            isCursorVisible = true
            Log.d(TAG, "✅ Mouse pointer cursor shown at ($x, $y)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show cursor: ${e.message}")
            cursorView = null
            false
        }
    }

    /**
     * Create mouse pointer view with arrow icon and glow
     */
    private fun createMousePointerView(): View {
        val container = FrameLayout(this)

        // Glow effect behind cursor
        cursorGlowView = ImageView(this).apply {
            setImageBitmap(createGlowBitmap())
            alpha = 0.5f
            scaleX = 1.2f
            scaleY = 1.2f
        }

        // Main cursor arrow
        cursorImageView = ImageView(this).apply {
            setImageBitmap(createMousePointerBitmap())
            scaleType = ImageView.ScaleType.FIT_CENTER
        }

        val sizePx = dpToPx(32)
        val glowSizePx = dpToPx(48)

        container.addView(cursorGlowView, FrameLayout.LayoutParams(glowSizePx, glowSizePx, Gravity.CENTER))
        container.addView(cursorImageView, FrameLayout.LayoutParams(sizePx, sizePx, Gravity.CENTER))

        return container
    }

    /**
     * Create mouse pointer arrow bitmap - Windows/Mac style cursor
     */
    private fun createMousePointerBitmap(): Bitmap {
        val size = dpToPx(32)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Colors based on state
        val fillColor = when (currentCursorState) {
            "clicking" -> Color.parseColor("#00FF88")  // Green
            "dragging" -> Color.parseColor("#FF6B6B")  // Red
            else -> Color.parseColor("#FFFFFF")        // White
        }

        // ═══════════════════════════════════════════════════════════
        // MOUSE POINTER ARROW PATH - Standard Windows/Mac cursor
        // ═══════════════════════════════════════════════════════════
        val path = Path().apply {
            // Arrow pointing up-left (standard cursor direction)
            // Tip at top-left
            moveTo(2f, 2f)
            
            // Left edge going down
            lineTo(2f, 26f)
            
            // Inner left corner to stem
            lineTo(8f, 20f)
            
            // Bottom of stem pointing right
            lineTo(12f, 28f)
            
            // Right side of stem going up
            lineTo(16f, 26f)
            
            // Inner right corner
            lineTo(12f, 18f)
            
            // Right edge going up
            lineTo(20f, 18f)
            
            // Back to tip
            close()
        }

        // Draw shadow for depth
        paint.setShadowLayer(4f, 2f, 2f, Color.parseColor("#80000000"))
        paint.style = Paint.Style.FILL
        paint.color = fillColor
        canvas.drawPath(path, paint)

        // Draw black outline for visibility
        paint.setShadowLayer(0f, 0f, 0f, Color.TRANSPARENT)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1.5f
        paint.color = Color.parseColor("#000000")
        canvas.drawPath(path, paint)

        // Draw white inner highlight
        paint.strokeWidth = 0.8f
        paint.color = Color.parseColor("#FFFFFF")
        paint.alpha = 100
        canvas.drawPath(path, paint)

        return bitmap
    }

    /**
     * Create glow effect bitmap
     */
    private fun createGlowBitmap(): Bitmap {
        val size = dpToPx(48)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        val glowColor = when (currentCursorState) {
            "clicking" -> Color.parseColor("#4000FF88")
            "dragging" -> Color.parseColor("#40FF6B6B")
            else -> Color.parseColor("#40FFFFFF")
        }

        paint.shader = RadialGradient(
            size / 2f, size / 2f, size / 2f,
            glowColor,
            Color.TRANSPARENT,
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)

        return bitmap
    }

    private fun hideCursorOverlay() {
        cursorView?.let {
            try {
                windowManager.removeView(it)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to hide cursor: ${e.message}")
            }
            cursorView = null
            cursorImageView = null
            cursorGlowView = null
            isCursorVisible = false
        }
    }

    private fun updateCursorPositionNormalized(x: Float, y: Float) {
        val (width, height) = getScreenSize()
        updateCursorPositionAbsolute(x * width, y * height)
    }

    private fun updateCursorPositionAbsolute(x: Float, y: Float) {
        cursorView?.let { view ->
            try {
                cursorParams?.let { params ->
                    val cursorSize = dpToPx(32)
                    params.x = (x - cursorSize / 2).toInt()
                    params.y = (y - cursorSize / 4).toInt()
                    windowManager.updateViewLayout(view, params)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update cursor: ${e.message}")
            }
        }
    }

    private fun updateCursorVisualState(state: String) {
        if (currentCursorState != state) {
            currentCursorState = state
            cursorImageView?.setImageBitmap(createMousePointerBitmap())
            cursorGlowView?.setImageBitmap(createGlowBitmap())
        }
    }

    private fun updateCursorRotation(angleDegrees: Float) {
        // Limit rotation to subtle angles
        val clampedAngle = angleDegrees.coerceIn(-25f, 25f)
        cursorImageView?.rotation = clampedAngle
        cursorGlowView?.rotation = clampedAngle
    }

    // ═══════════════════════════════════════════════════════════════
    // ACCESSIBILITY METHODS
    // ═══════════════════════════════════════════════════════════════

    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        return enabledServices.contains(packageName)
    }

    private fun performAccessibilityTap(x: Float, y: Float): Boolean {
        val service = accessibilityServiceInstance
        if (service == null) {
            Log.e(TAG, "❌ Accessibility service not running")
            return false
        }
        
        // Update cursor state to show clicking
        updateCursorVisualState("clicking")
        
        val result = service.performTap(x, y)
        
        // Reset cursor state after a short delay
        android.os.Handler(mainLooper).postDelayed({
            updateCursorVisualState("normal")
        }, 150)
        
        return result
    }

    private fun performAccessibilityScroll(direction: String, distance: Float): Boolean {
        val service = accessibilityServiceInstance ?: return false
        val (width, height) = getScreenSize()
        return service.performScroll(direction, distance, width / 2f, height / 2f)
    }

    private fun performGlobalAction(action: String): Boolean {
        val service = accessibilityServiceInstance ?: return false
        return when (action) {
            "back" -> service.goBack()
            "home" -> service.goHome()
            "recents" -> service.openRecents()
            "notifications" -> service.openNotifications()
            "quickSettings" -> service.openQuickSettings()
            "powerDialog" -> service.openPowerDialog()
            "lockScreen" -> service.lockScreen()
            "screenshot" -> service.takeScreenshot()
            else -> false
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // UTILITIES
    // ═══════════════════════════════════════════════════════════════

    private fun getScreenSize(): Pair<Int, Int> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            Pair(bounds.width(), bounds.height())
        } else {
            @Suppress("DEPRECATION")
            val point = android.graphics.Point()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealSize(point)
            Pair(point.x, point.y)
        }
    }

    private fun getScreenCenterX(): Float = getScreenSize().first / 2f
    private fun getScreenCenterY(): Float = getScreenSize().second / 2f
    private fun dpToPx(dp: Int): Int = (dp * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        hideCursorOverlay()
        instance = null
        super.onDestroy()
    }
}
