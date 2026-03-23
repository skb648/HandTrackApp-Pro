package com.airtouch.airtouch_ultimate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.util.Size
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.sqrt

/**
 * Camera Foreground Service with ML Kit Pose Detection
 * 
 * - Uses ML Kit Pose Detection for hand tracking
 * - RIGHT_INDEX and LEFT_INDEX landmarks for cursor position
 * - RIGHT_THUMB and LEFT_THUMB for pinch gesture
 * - Runs in foreground service to survive app minimization
 */
class CameraForegroundService : LifecycleService() {
    
    companion object {
        private const val TAG = "AirTouchService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "airtouch_camera_service"
        
        @Volatile
        var instance: CameraForegroundService? = null
        
        // Cursor position (normalized 0-1)
        @Volatile
        var cursorX: Float = 0.5f
            private set
        
        @Volatile
        var cursorY: Float = 0.5f
            private set
        
        // Screen dimensions
        @Volatile
        var screenWidth: Int = 1080
            private set
        
        @Volatile
        var screenHeight: Int = 2400
            private set
        
        // Gesture state
        @Volatile
        var currentGesture: String = "none"
            private set
        
        @Volatile
        var isRunning: Boolean = false
            private set
        
        // FPS tracking
        @Volatile
        var currentFps: Float = 0f
            private set
        
        // Callbacks
        var onGestureDetected: ((String) -> Unit)? = null
        var onPositionUpdate: ((Float, Float) -> Unit)? = null
        var onFpsUpdate: ((Float) -> Unit)? = null
    }
    
    // CameraX components
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraExecutor: ExecutorService? = null
    private var poseDetector: PoseDetector? = null
    
    // Overlay components
    private var windowManager: WindowManager? = null
    private var cursorView: ImageView? = null
    private var cursorParams: WindowManager.LayoutParams? = null
    private var isOverlayVisible = false
    
    // Screen dimensions
    private var displayWidth: Int = 1080
    private var displayHeight: Int = 2400
    
    // Smoothing (EMA - Exponential Moving Average)
    private var smoothedX: Float = 0.5f
    private var smoothedY: Float = 0.5f
    private val smoothingAlpha = 0.4f  // Higher = more responsive
    
    // Gesture detection
    private var lastGestureTime: Long = 0
    private val gestureDebounceMs: Long = 200
    private var lastClickTime: Long = 0
    private val clickDebounceMs: Long = 400
    
    // FPS calculation
    private var frameCount: Long = 0
    private var lastFpsTime: Long = 0
    
    // Accessibility service
    private val accessibilityService: AirTouchAccessibilityService?
        get() = AirTouchAccessibilityService.instance
    
    private val handler = Handler(Looper.getMainLooper())
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "=== CameraForegroundService onCreate ===")
        instance = this
        
        // Get screen dimensions
        getScreenDimensions()
        
        // Initialize smoothed position to center
        smoothedX = 0.5f
        smoothedY = 0.5f
        cursorX = 0.5f
        cursorY = 0.5f
        screenWidth = displayWidth
        screenHeight = displayHeight
        
        // Create notification channel
        createNotificationChannel()
        
        Log.d(TAG, "Screen dimensions: ${displayWidth}x${displayHeight}")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "=== CameraForegroundService onStartCommand ===")
        
        // Create and show foreground notification
        val notification = createNotification()
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            Log.d(TAG, "Foreground service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground: ${e.message}")
            // Fallback
            startForeground(NOTIFICATION_ID, notification)
        }
        
        isRunning = true
        
        // Initialize pose detector
        initPoseDetector()
        
        // Initialize camera
        initCamera()
        
        // Show cursor overlay
        handler.postDelayed({ showCursorOverlay() }, 500)
        
        return START_STICKY
    }
    
    private fun getScreenDimensions() {
        try {
            val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bounds = windowManager.currentWindowMetrics.bounds
                displayWidth = bounds.width()
                displayHeight = bounds.height()
            } else {
                @Suppress("DEPRECATION")
                val metrics = DisplayMetrics()
                windowManager.defaultDisplay.getRealMetrics(metrics)
                displayWidth = metrics.widthPixels
                displayHeight = metrics.heightPixels
            }
            Log.d(TAG, "Screen: ${displayWidth}x${displayHeight}")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting screen: ${e.message}")
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AirTouch Camera Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Hand tracking camera service is running"
                setShowBadge(false)
                enableLights(false)
                vibrationPattern = null
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AirTouch Ultimate")
            .setContentText("Hand tracking active - Move your hand to control cursor")
            .setSmallIcon(android.R.drawable.ic_menu_myplaces)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }
    
    private fun initPoseDetector() {
        try {
            Log.d(TAG, "Initializing ML Kit Pose Detector...")
            
            val options = PoseDetectorOptions.Builder()
                .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
                .setPreferredHardwareConfigs(PoseDetectorOptions.CPU)
                .build()
            
            poseDetector = PoseDetection.getClient(options)
            Log.d(TAG, "ML Kit Pose Detector initialized successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init Pose Detector: ${e.message}")
        }
    }
    
    private fun initCamera() {
        try {
            cameraExecutor = Executors.newSingleThreadExecutor()
            
            val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
            
            cameraProviderFuture.addListener({
                try {
                    cameraProvider = cameraProviderFuture.get()
                    bindCamera()
                } catch (e: Exception) {
                    Log.e(TAG, "Error getting camera provider: ${e.message}")
                }
            }, ContextCompat.getMainExecutor(this))
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init camera: ${e.message}")
        }
    }
    
    private fun bindCamera() {
        try {
            cameraProvider?.unbindAll()
            
            // Image analysis for pose detection
            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setTargetResolution(Size(640, 480))
                .build()
            
            imageAnalysis.setAnalyzer(cameraExecutor!!) { imageProxy ->
                processImage(imageProxy)
            }
            
            // Front camera selector
            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                .build()
            
            // Bind to lifecycle
            cameraProvider?.bindToLifecycle(
                this as LifecycleOwner,
                cameraSelector,
                imageAnalysis
            )
            
            Log.d(TAG, "Camera bound successfully - Front camera active")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error binding camera: ${e.message}")
        }
    }
    
    private fun processImage(imageProxy: ImageProxy) {
        if (!isRunning) {
            imageProxy.close()
            return
        }
        
        // FPS calculation
        frameCount++
        val now = System.currentTimeMillis()
        if (now - lastFpsTime >= 1000) {
            currentFps = frameCount.toFloat()
            frameCount = 0
            lastFpsTime = now
            onFpsUpdate?.invoke(currentFps)
        }
        
        try {
            val mediaImage = imageProxy.image
            if (mediaImage == null) {
                imageProxy.close()
                return
            }
            
            // Create InputImage with rotation info
            val rotation = imageProxy.imageInfo.rotationDegrees
            val inputImage = InputImage.fromMediaImage(mediaImage, rotation)
            
            // Process with ML Kit
            poseDetector?.process(inputImage)
                ?.addOnSuccessListener { pose ->
                    handlePose(pose, imageProxy.width, imageProxy.height, rotation)
                    imageProxy.close()
                }
                ?.addOnFailureListener { e ->
                    Log.e(TAG, "Pose detection failed: ${e.message}")
                    imageProxy.close()
                }
                
        } catch (e: Exception) {
            Log.e(TAG, "Error processing image: ${e.message}")
            imageProxy.close()
        }
    }
    
    private fun handlePose(pose: Pose, imageWidth: Int, imageHeight: Int, rotation: Int) {
        try {
            // Get right index finger tip
            val rightIndex = pose.getPoseLandmark(PoseLandmark.RIGHT_INDEX)
            val rightThumb = pose.getPoseLandmark(PoseLandmark.RIGHT_THUMB)
            
            // Fallback to left hand if right not visible
            var indexTip = rightIndex
            var thumbTip = rightThumb
            
            if (rightIndex == null || rightIndex.inFrameLikelihood < 0.5f) {
                val leftIndex = pose.getPoseLandmark(PoseLandmark.LEFT_INDEX)
                val leftThumb = pose.getPoseLandmark(PoseLandmark.LEFT_THUMB)
                if (leftIndex != null && leftIndex.inFrameLikelihood > 0.5f) {
                    indexTip = leftIndex
                    thumbTip = leftThumb
                }
            }
            
            if (indexTip == null) return
            
            // Get coordinates - ML Kit returns coordinates in the original image coordinate system
            // After rotation is applied, coordinates are in the output image coordinate system
            val landmarkX = indexTip.position.x
            val landmarkY = indexTip.position.y
            
            // CRITICAL: ML Kit Pose landmark positions are already normalized to the input image
            // dimensions after accounting for rotation. We need to normalize to 0-1.
            
            // Use the ORIGINAL image dimensions (before rotation consideration)
            // ML Kit internally handles rotation and gives us coordinates in the image frame
            val imgW = imageWidth.toFloat()
            val imgH = imageHeight.toFloat()
            
            // Normalize coordinates (0-1)
            var normalizedX = (landmarkX / imgW).coerceIn(0f, 1f)
            var normalizedY = (landmarkY / imgH).coerceIn(0f, 1f)
            
            // Mirror X for front camera natural feel
            normalizedX = 1f - normalizedX
            
            // Apply EMA smoothing for stable cursor
            smoothedX = smoothingAlpha * normalizedX + (1f - smoothingAlpha) * smoothedX
            smoothedY = smoothingAlpha * normalizedY + (1f - smoothingAlpha) * smoothedY
            
            // Update cursor position
            cursorX = smoothedX
            cursorY = smoothedY
            
            // Update overlay on main thread
            handler.post {
                updateCursorOverlay(smoothedX, smoothedY)
                onPositionUpdate?.invoke(smoothedX, smoothedY)
            }
            
            // Detect gestures
            if (thumbTip != null && thumbTip.inFrameLikelihood > 0.5f) {
                detectGestures(indexTip, thumbTip, imgW, imgH)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling pose: ${e.message}")
        }
    }
    
    private fun detectGestures(indexTip: PoseLandmark, thumbTip: PoseLandmark, imgW: Float, imgH: Float) {
        val now = System.currentTimeMillis()
        if (now - lastGestureTime < gestureDebounceMs) return
        
        try {
            // Calculate pinch distance (normalized)
            val dx = (indexTip.position.x - thumbTip.position.x) / imgW
            val dy = (indexTip.position.y - thumbTip.position.y) / imgH
            val distance = sqrt((dx * dx + dy * dy).toDouble()).toFloat()
            
            // Pinch threshold (normalized, ~8% of screen)
            val pinchThreshold = 0.08f
            
            if (distance < pinchThreshold) {
                if (currentGesture != "pinch") {
                    lastGestureTime = now
                    currentGesture = "pinch"
                    handler.post { onGestureDetected?.invoke("pinch") }
                    
                    // Perform click
                    if (now - lastClickTime > clickDebounceMs) {
                        lastClickTime = now
                        performClick()
                    }
                }
            } else {
                if (currentGesture != "open") {
                    currentGesture = "open"
                    handler.post { onGestureDetected?.invoke("open") }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error detecting gesture: ${e.message}")
        }
    }
    
    private fun performClick() {
        try {
            val screenX = smoothedX * displayWidth
            val screenY = smoothedY * displayHeight
            
            Log.d(TAG, ">>> CLICK at ($screenX, $screenY)")
            
            accessibilityService?.performClick(screenX, screenY)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error performing click: ${e.message}")
        }
    }
    
    // ==========================================
    // CURSOR OVERLAY
    // ==========================================
    
    private fun showCursorOverlay() {
        if (isOverlayVisible) return
        
        try {
            windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            
            // Create cursor view
            cursorView = ImageView(this)
            val cursorDrawable = createCursorDrawable()
            cursorView?.setImageDrawable(cursorDrawable)
            cursorView?.measure(
                View.MeasureSpec.makeMeasureSpec(48, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(48, View.MeasureSpec.EXACTLY)
            )
            cursorView?.layout(0, 0, 48, 48)
            
            // Window params
            val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            cursorParams = WindowManager.LayoutParams(
                48, 48,
                layoutType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = (smoothedX * displayWidth).toInt()
                y = (smoothedY * displayHeight).toInt()
            }
            
            windowManager?.addView(cursorView, cursorParams)
            isOverlayVisible = true
            
            Log.d(TAG, ">>> Cursor overlay SHOWN at (${cursorParams?.x}, ${cursorParams?.y})")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error showing cursor: ${e.message}")
        }
    }
    
    private fun hideCursorOverlay() {
        try {
            if (cursorView != null && windowManager != null && isOverlayVisible) {
                windowManager?.removeView(cursorView)
                cursorView = null
                cursorParams = null
                isOverlayVisible = false
                Log.d(TAG, "Cursor overlay hidden")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error hiding cursor: ${e.message}")
        }
    }
    
    private fun updateCursorOverlay(normalizedX: Float, normalizedY: Float) {
        if (!isOverlayVisible || cursorParams == null || windowManager == null) return
        
        // Calculate screen position
        val screenX = (normalizedX * displayWidth).toInt()
        val screenY = (normalizedY * displayHeight).toInt()
        
        try {
            cursorParams?.x = screenX - 4  // Offset for cursor tip
            cursorParams?.y = screenY - 4
            windowManager?.updateViewLayout(cursorView, cursorParams)
        } catch (e: Exception) {
            // View might be detached
        }
    }
    
    private fun createCursorDrawable(): Drawable {
        val size = 36
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        
        // Mouse pointer arrow shape
        val path = Path().apply {
            moveTo(2f, 2f)
            lineTo(2f, 28f)
            lineTo(9f, 21f)
            lineTo(14f, 32f)
            lineTo(18f, 30f)
            lineTo(13f, 19f)
            lineTo(22f, 19f)
            close()
        }
        
        // Shadow
        val shadowPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#66000000")
            style = Paint.Style.FILL
        }
        canvas.save()
        canvas.translate(2f, 2f)
        canvas.drawPath(path, shadowPaint)
        canvas.restore()
        
        // White fill
        val fillPaint = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawPath(path, fillPaint)
        
        // Black outline
        val outlinePaint = Paint().apply {
            isAntiAlias = true
            color = Color.BLACK
            style = Paint.Style.STROKE
            strokeWidth = 1.5f
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(path, outlinePaint)
        
        return BitmapDrawable(resources, bitmap)
    }
    
    override fun onDestroy() {
        Log.d(TAG, "=== CameraForegroundService onDestroy ===")
        
        isRunning = false
        instance = null
        
        // Hide overlay
        hideCursorOverlay()
        
        // Release camera
        try {
            cameraProvider?.unbindAll()
            cameraProvider = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing camera: ${e.message}")
        }
        
        // Shutdown executor
        cameraExecutor?.shutdown()
        cameraExecutor?.awaitTermination(1, TimeUnit.SECONDS)
        cameraExecutor = null
        
        // Close pose detector
        try {
            poseDetector?.close()
            poseDetector = null
        } catch (e: Exception) {
            Log.e(TAG, "Error closing pose detector: ${e.message}")
        }
        
        // Clear callbacks
        onGestureDetected = null
        onPositionUpdate = null
        onFpsUpdate = null
        
        super.onDestroy()
    }
}
