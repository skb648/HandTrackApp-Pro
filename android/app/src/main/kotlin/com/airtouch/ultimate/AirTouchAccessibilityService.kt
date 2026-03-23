package com.airtouch.ultimate

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * AIRTOUCH ACCESSIBILITY SERVICE - OS-LEVEL GESTURE EXECUTION
 * ═══════════════════════════════════════════════════════════════════════════════
 * 
 * This service receives gesture commands from Flutter via MethodChannel and executes
 * them at the OS level using Android's GestureDescription API.
 * 
 * IMPORTANT: User must enable this service in Settings > Accessibility
 */
class AirTouchAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AirTouchAccessibility"
        
        // Gesture durations
        private const val TAP_DURATION_MS: Long = 50
        private const val LONG_PRESS_DURATION_MS: Long = 500
        private const val SWIPE_DURATION_MS: Long = 300
        private const val DRAG_DURATION_MS: Long = 400

        @Volatile
        var instance: AirTouchAccessibilityService? = null
            private set

        val isRunning: Boolean
            get() = instance != null

        // Global action constants (AccessibilityService constants)
        private const val GLOBAL_ACTION_BACK = 1
        private const val GLOBAL_ACTION_HOME = 2
        private const val GLOBAL_ACTION_RECENTS = 3
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    // ═══════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ═══════════════════════════════════════════════════════════════

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        MainActivity.accessibilityServiceInstance = this
        Log.i(TAG, "✅ Accessibility Service CONNECTED and READY")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // We don't need to intercept events, just dispatch gestures
    }

    override fun onInterrupt() {
        Log.w(TAG, "⚠️ Accessibility service interrupted")
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        MainActivity.accessibilityServiceInstance = null
        Log.i(TAG, "❌ Accessibility Service DISCONNECTED")
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        MainActivity.accessibilityServiceInstance = null
        super.onDestroy()
        Log.i(TAG, "❌ Accessibility Service DESTROYED")
    }

    // ═══════════════════════════════════════════════════════════════
    // TAP / CLICK - Single finger tap at coordinates
    // ═══════════════════════════════════════════════════════════════

    /**
     * Perform a tap at the specified screen coordinates
     * @param x X coordinate in pixels (absolute screen position)
     * @param y Y coordinate in pixels (absolute screen position)
     * @return true if gesture was dispatched successfully
     */
    fun performTap(x: Float, y: Float): Boolean {
        return performTap(x, y, TAP_DURATION_MS)
    }

    fun performTap(x: Float, y: Float, durationMs: Long): Boolean {
        if (!isGestureSupported()) {
            Log.e(TAG, "❌ Gestures not supported on this device (requires Android 7+)")
            return false
        }

        Log.d(TAG, "👆 TAP at ($x, $y) duration=${durationMs}ms")

        val path = Path().apply {
            moveTo(x, y)
            // Small movement ensures gesture registers
            lineTo(x + 1f, y + 1f)
        }

        return dispatchGesture(path, 0, durationMs)
    }

    // ═══════════════════════════════════════════════════════════════
    // DOUBLE TAP
    // ═══════════════════════════════════════════════════════════════

    fun performDoubleTap(x: Float, y: Float): Boolean {
        if (!isGestureSupported()) return false
        
        Log.d(TAG, "👆👆 DOUBLE TAP at ($x, $y)")

        // First tap
        val success1 = performTap(x, y)
        
        // Small delay between taps
        Thread.sleep(100)
        
        // Second tap
        val success2 = performTap(x, y)
        
        return success1 && success2
    }

    // ═══════════════════════════════════════════════════════════════
    // LONG PRESS
    // ═══════════════════════════════════════════════════════════════

    fun performLongPress(x: Float, y: Float): Boolean {
        if (!isGestureSupported()) return false
        
        Log.d(TAG, "✋ LONG PRESS at ($x, $y)")

        val path = Path().apply {
            moveTo(x, y)
        }

        return dispatchGesture(path, 0, LONG_PRESS_DURATION_MS)
    }

    // ═══════════════════════════════════════════════════════════════
    // SWIPE - Single finger swipe
    // ═══════════════════════════════════════════════════════════════

    /**
     * Perform a swipe gesture from start to end coordinates
     */
    fun performSwipe(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Long = SWIPE_DURATION_MS
    ): Boolean {
        if (!isGestureSupported()) return false
        
        Log.d(TAG, "👆 SWIPE ($startX, $startY) → ($endX, $endY)")

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }

        return dispatchGesture(path, 0, durationMs)
    }

    // ═══════════════════════════════════════════════════════════════
    // SCROLL - Directional scroll
    // ═══════════════════════════════════════════════════════════════

    /**
     * Perform a scroll in the specified direction
     * @param direction "up", "down", "left", "right"
     * @param distance Distance to scroll in pixels
     */
    fun performScroll(direction: String, distance: Float, centerX: Float, centerY: Float): Boolean {
        if (!isGestureSupported()) return false
        
        Log.d(TAG, "📜 SCROLL $direction distance=$distance")

        val (startX, startY, endX, endY) = when (direction) {
            "up" -> listOf(centerX, centerY + distance / 2, centerX, centerY - distance / 2)
            "down" -> listOf(centerX, centerY - distance / 2, centerX, centerY + distance / 2)
            "left" -> listOf(centerX + distance / 2, centerY, centerX - distance / 2, centerY)
            "right" -> listOf(centerX - distance / 2, centerY, centerX + distance / 2, centerY)
            else -> return false
        }

        return performSwipe(startX, startY, endX, endY)
    }

    // ═══════════════════════════════════════════════════════════════
    // DRAG - Drag and drop
    // ═══════════════════════════════════════════════════════════════

    /**
     * Perform a drag gesture
     */
    fun performDrag(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Long = DRAG_DURATION_MS
    ): Boolean {
        if (!isGestureSupported()) return false
        
        Log.d(TAG, "✊ DRAG ($startX, $startY) → ($endX, $endY)")

        val path = Path().apply {
            moveTo(startX, startY)
            // Add intermediate points for smoother drag
            val midX = (startX + endX) / 2
            val midY = (startY + endY) / 2
            lineTo(midX, midY)
            lineTo(endX, endY)
        }

        return dispatchGesture(path, 0, durationMs)
    }

    // ═══════════════════════════════════════════════════════════════
    // PINCH - Two finger pinch gesture
    // ═══════════════════════════════════════════════════════════════

    /**
     * Perform a pinch gesture (zoom in/out)
     */
    fun performPinch(
        centerX: Float,
        centerY: Float,
        startSpan: Float,
        endSpan: Float,
        durationMs: Long = 300
    ): Boolean {
        if (!isGestureSupported()) return false
        
        Log.d(TAG, "🤏 PINCH center=($centerX, $centerY) startSpan=$startSpan endSpan=$endSpan")

        val builder = GestureDescription.Builder()

        // Finger 1: moves from left
        val path1 = Path().apply {
            val startX1 = centerX - startSpan / 2
            val endX1 = centerX - endSpan / 2
            moveTo(startX1, centerY)
            lineTo(endX1, centerY)
        }

        // Finger 2: moves from right
        val path2 = Path().apply {
            val startX2 = centerX + startSpan / 2
            val endX2 = centerX + endSpan / 2
            moveTo(startX2, centerY)
            lineTo(endX2, centerY)
        }

        builder.addStroke(GestureDescription.StrokeDescription(path1, 0, durationMs))
        builder.addStroke(GestureDescription.StrokeDescription(path2, 0, durationMs))

        return dispatchGesture(builder.build())
    }

    // ═══════════════════════════════════════════════════════════════
    // GLOBAL ACTIONS - System navigation
    // ═══════════════════════════════════════════════════════════════

    fun goBack(): Boolean {
        Log.d(TAG, "◀️ BACK")
        return performGlobalAction(GLOBAL_ACTION_BACK)
    }

    fun goHome(): Boolean {
        Log.d(TAG, "🏠 HOME")
        return performGlobalAction(GLOBAL_ACTION_HOME)
    }

    fun openRecents(): Boolean {
        Log.d(TAG, "📋 RECENTS")
        return performGlobalAction(GLOBAL_ACTION_RECENTS)
    }

    fun openNotifications(): Boolean {
        Log.d(TAG, "🔔 NOTIFICATIONS")
        return performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
    }

    fun openQuickSettings(): Boolean {
        Log.d(TAG, "⚙️ QUICK SETTINGS")
        return performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS)
    }

    fun openPowerDialog(): Boolean {
        Log.d(TAG, "🔌 POWER DIALOG")
        return performGlobalAction(GLOBAL_ACTION_POWER_DIALOG)
    }

    fun lockScreen(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Log.d(TAG, "🔒 LOCK SCREEN")
            performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
        } else {
            Log.w(TAG, "❌ Lock screen not available on Android < 9")
            false
        }
    }

    fun takeScreenshot(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Log.d(TAG, "📸 SCREENSHOT")
            performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT)
        } else {
            Log.w(TAG, "❌ Screenshot not available on Android < 9")
            false
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // INTERNAL HELPERS
    // ═══════════════════════════════════════════════════════════════

    private fun isGestureSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.N
    }

    private fun dispatchGesture(path: Path, startTime: Long, duration: Long): Boolean {
        val builder = GestureDescription.Builder()
        builder.addStroke(GestureDescription.StrokeDescription(path, startTime, duration))
        return dispatchGesture(builder.build())
    }

    private fun dispatchGesture(gesture: GestureDescription): Boolean {
        return try {
            val callback = object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    Log.v(TAG, "✅ Gesture completed")
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    Log.w(TAG, "⚠️ Gesture cancelled")
                }
            }
            val result = dispatchGesture(gesture, callback, null)
            if (result) {
                Log.v(TAG, "📤 Gesture dispatched successfully")
            } else {
                Log.e(TAG, "❌ Failed to dispatch gesture")
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "❌ Gesture dispatch error: ${e.message}")
            false
        }
    }

    /**
     * Find a clickable node at specific coordinates
     */
    fun findClickableAt(x: Int, y: Int): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null

        // Try to find node at exact location
        val nodes = root.findAccessibilityNodeInfosByViewId("")
        for (node in nodes) {
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            if (bounds.contains(x, y) && node.isClickable) {
                return node
            }
        }

        return null
    }
}
