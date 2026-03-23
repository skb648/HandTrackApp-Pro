package com.airtouch.ultimate

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * Accessibility Service for System-Level Click Injection
 */
class AirTouchAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "AirTouchAccessibility"
        
        @Volatile
        var instance: AirTouchAccessibilityService? = null
            private set
        
        @Volatile
        var isEnabled: Boolean = false
            private set
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        isEnabled = true
        Log.d(TAG, "Accessibility Service Connected and Ready")
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not needed for gesture injection
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }
    
    override fun onDestroy() {
        instance = null
        isEnabled = false
        super.onDestroy()
    }
    
    /**
     * Perform a single tap/click at the specified screen coordinates
     */
    fun performClick(screenX: Float, screenY: Float): Boolean {
        return try {
            Log.d(TAG, "Performing click at ($screenX, $screenY)")
            
            val path = Path().apply {
                moveTo(screenX, screenY)
            }
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 10))
                .build()
            
            val result = dispatchGesture(gesture, null, null)
            Log.d(TAG, "Click result: $result")
            result
            
        } catch (e: Exception) {
            Log.e(TAG, "Click failed: ${e.message}")
            false
        }
    }
    
    /**
     * Perform a double tap at the specified screen coordinates
     */
    fun performDoubleTap(screenX: Float, screenY: Float): Boolean {
        return try {
            val path1 = Path().apply { moveTo(screenX, screenY) }
            val path2 = Path().apply { moveTo(screenX, screenY) }
            
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
     * Perform a swipe gesture from start to end
     */
    fun performSwipe(startX: Float, startY: Float, endX: Float, endY: Float, durationMs: Long): Boolean {
        return try {
            val path = Path().apply {
                moveTo(startX, startY)
                lineTo(endX, endY)
            }
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs))
                .build()
            
            dispatchGesture(gesture, null, null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Swipe failed: ${e.message}")
            false
        }
    }
}
