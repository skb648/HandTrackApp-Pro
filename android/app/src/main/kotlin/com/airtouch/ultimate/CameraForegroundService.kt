package com.airtouch.ultimate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
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
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.Observer
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.sqrt

/**
 * Camera Foreground Service - Native CameraX + ML Kit Pose Detection
 * 
 * Runs camera using CameraX in a native foreground service.
 * Survives app minimization.
 */
class CameraForegroundService : Service(), LifecycleOwner {
    
    companion object {
        private const val TAG = "AirTouchCameraService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "airtouch_camera_service"
        
        @Volatile
        var instance: CameraForegroundService? = null
        
        @Volatile
        var cursorX: Float = 0.5f
            private set
        
        @Volatile
        var cursorY: Float = 0.5f
            private set
        
        @Volatile
        var screenWidth: Int = 1080
            private set
        
        @Volatile
        var screenHeight: Int = 2400
            private set
        
        @Volatile
        var currentGesture: String = "none"
            private set
        
        @Volatile
        var isRunning: Boolean = false
            private set
        
        var onGestureDetected: ((String) -> Unit)? = null
        var onPositionUpdate: ((Float, Float) -> Unit)? = null
    }
    
    private lateinit var lifecycleRegistry: LifecycleRegistry
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraExecutor: ExecutorService? = null
    private var poseDetector: PoseDetector? = null
    private var windowManager: WindowManager? = null
    private var cursorView: ImageView? = null
    private var cursorParams: WindowManager.LayoutParams? = null
    private var isOverlayVisible = false
    private var displayWidth: Int = 1080
    private var displayHeight: Int = 2400
    private var smoothedX: Float = 0.5f
    private var smoothedY: Float = 0.5f
    private val smoothingAlpha = 0.35f
    private var lastGestureTime: Long = 0
    private val gestureDebounceMs: Long = 250
    private var lastClickTime: Long = 0
    private val clickDebounceMs: Long = 400
    private val handler = Handler(Looper.getMainLooper())
    
    override val lifecycle: Lifecycle
        get() = lifecycleRegistry
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CameraForegroundService onCreate")
        
        lifecycleRegistry = LifecycleRegistry(this)
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
        
        instance = this
        getScreenDimensions()
        smoothedX = 0.5f
        smoothedY = 0.5f
        cursorX = 0.5f
        cursorY = 0.5f
        screenWidth = displayWidth
        screenHeight = displayHeight
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "CameraForegroundService onStartCommand")
        
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        
        val notification = createNotification()
        
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, notification, 64) // FOREGROUND_SERVICE_TYPE_CAMERA = 64
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground: ${e.message}")
            startForeground(NOTIFICATION_ID, notification)
        }
        
        isRunning = true
        
        initPoseDetector()
        initCamera()
        handler.postDelayed({ showCursorOverlay() }, 500)
        
        return START_STICKY
    }
    
    private fun getScreenDimensions() {
        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bounds = wm.currentWindowMetrics.bounds
                displayWidth = bounds.width()
                displayHeight = bounds.height()
            } else {
                val metrics = DisplayMetrics()
                @Suppress("DEPRECATION")
                wm.defaultDisplay.getRealMetrics(metrics)
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
            
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val stopIntent = Intent(this, CameraForegroundService::class.java).apply {
            action = "STOP"
        }
        
        val stopPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.getService(this, 0, stopIntent, PendingIntent.FLAG_IMMUTABLE)
        } else {
            PendingIntent.getService(this, 0, stopIntent, 0)
        }
        
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
            val options = PoseDetectorOptions.Builder()
                .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
                .setPreferredHardwareConfigs(PoseDetectorOptions.CPU)
                .build()
            
            poseDetector = PoseDetection.getClient(options)
            Log.d(TAG, "Pose detector initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init pose detector: ${e.message}")
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
            
            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setTargetResolution(Size(640, 480))
                .build()
            
            imageAnalysis.setAnalyzer(cameraExecutor!!) { imageProxy ->
                processFrame(imageProxy)
            }
            
            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                .build()
            
            cameraProvider?.bindToLifecycle(
                this,
                cameraSelector,
                imageAnalysis
            )
            
            Log.d(TAG, "Camera bound successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error binding camera: ${e.message}")
        }
    }
    
    private fun processFrame(imageProxy: ImageProxy) {
        if (!isRunning || poseDetector == null) {
            imageProxy.close()
            return
        }
        
        try {
            val mediaImage = imageProxy.image
            if (mediaImage == null) {
                imageProxy.close()
                return
            }
            
            val rotation = imageProxy.imageInfo.rotationDegrees
            val inputImage = InputImage.fromMediaImage(mediaImage, rotation)
            
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
            Log.e(TAG, "Error processing frame: ${e.message}")
            imageProxy.close()
        }
    }
    
    private fun handlePose(pose: Pose, imageWidth: Int, imageHeight: Int, rotation: Int) {
        try {
            val rightIndex = pose.getPoseLandmark(PoseLandmark.RIGHT_INDEX)
            val rightThumb = pose.getPoseLandmark(PoseLandmark.RIGHT_THUMB)
            
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
            
            val landmarkX = indexTip.position.x
            val landmarkY = indexTip.position.y
            
            val imgW = if (rotation == 90 || rotation == 270) imageHeight else imageWidth
            val imgH = if (rotation == 90 || rotation == 270) imageWidth else imageHeight
            
            var normalizedX = (landmarkX / imgW).coerceIn(0f, 1f)
            var normalizedY = (landmarkY / imgH).coerceIn(0f, 1f)
            
            normalizedX = 1f - normalizedX
            
            smoothedX = smoothingAlpha * normalizedX + (1 - smoothingAlpha) * smoothedX
            smoothedY = smoothingAlpha * normalizedY + (1 - smoothingAlpha) * smoothedY
            
            cursorX = smoothedX
            cursorY = smoothedY
            
            updateCursorOverlay(smoothedX, smoothedY)
            onPositionUpdate?.invoke(smoothedX, smoothedY)
            
            if (thumbTip != null && thumbTip.inFrameLikelihood > 0.5f) {
                detectGestures(indexTip, thumbTip)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling pose: ${e.message}")
        }
    }
    
    private fun detectGestures(indexTip: PoseLandmark, thumbTip: PoseLandmark) {
        val now = System.currentTimeMillis()
        if (now - lastGestureTime < gestureDebounceMs) return
        
        try {
            val dx = indexTip.position.x - thumbTip.position.x
            val dy = indexTip.position.y - thumbTip.position.y
            val distance = sqrt((dx * dx + dy * dy).toDouble()).toFloat()
            
            val pinchThreshold = 50f
            
            if (distance < pinchThreshold) {
                if (currentGesture != "pinch") {
                    lastGestureTime = now
                    currentGesture = "pinch"
                    onGestureDetected?.invoke("pinch")
                    
                    if (now - lastClickTime > clickDebounceMs) {
                        lastClickTime = now
                        performClick()
                    }
                }
            } else {
                if (currentGesture != "open") {
                    currentGesture = "open"
                    onGestureDetected?.invoke("open")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error detecting gestures: ${e.message}")
        }
    }
    
    private fun performClick() {
        try {
            val screenX = smoothedX * displayWidth
            val screenY = smoothedY * displayHeight
            
            Log.d(TAG, "Click at ($screenX, $screenY)")
            
            AirTouchAccessibilityService.instance?.performClick(screenX, screenY)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error performing click: ${e.message}")
        }
    }
    
    private fun showCursorOverlay() {
        if (isOverlayVisible) return
        
        try {
            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            
            cursorView = ImageView(this)
            val cursorDrawable = createCursorDrawable()
            cursorView?.setImageDrawable(cursorDrawable)
            cursorView?.measure(
                View.MeasureSpec.makeMeasureSpec(56, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(56, View.MeasureSpec.EXACTLY)
            )
            cursorView?.layout(0, 0, 56, 56)
            
            val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            cursorParams = WindowManager.LayoutParams(
                56, 56,
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
            
            Log.d(TAG, "Cursor overlay shown")
            
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
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error hiding cursor: ${e.message}")
        }
    }
    
    private fun updateCursorOverlay(normalizedX: Float, normalizedY: Float) {
        if (!isOverlayVisible || cursorParams == null || windowManager == null) return
        
        val screenX = (normalizedX * displayWidth).toInt()
        val screenY = (normalizedY * displayHeight).toInt()
        
        handler.post {
            try {
                cursorParams?.x = screenX - 4
                cursorParams?.y = screenY - 4
                windowManager?.updateViewLayout(cursorView, cursorParams)
            } catch (e: Exception) {
                // View might be detached
            }
        }
    }
    
    private fun createCursorDrawable(): Drawable {
        val size = 40
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        
        val path = Path().apply {
            moveTo(2f, 2f)
            lineTo(2f, 32f)
            lineTo(10f, 24f)
            lineTo(16f, 36f)
            lineTo(20f, 34f)
            lineTo(14f, 22f)
            lineTo(24f, 22f)
            close()
        }
        
        val shadowPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#88000000")
            style = Paint.Style.FILL
        }
        canvas.save()
        canvas.translate(2f, 2f)
        canvas.drawPath(path, shadowPaint)
        canvas.restore()
        
        val fillPaint = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawPath(path, fillPaint)
        
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
        Log.d(TAG, "CameraForegroundService onDestroy")
        
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        
        isRunning = false
        instance = null
        
        hideCursorOverlay()
        
        try {
            cameraProvider?.unbindAll()
            cameraProvider = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing camera: ${e.message}")
        }
        
        cameraExecutor?.shutdown()
        cameraExecutor = null
        
        try {
            poseDetector?.close()
            poseDetector = null
        } catch (e: Exception) {
            Log.e(TAG, "Error closing pose detector: ${e.message}")
        }
        
        onGestureDetected = null
        onPositionUpdate = null
        
        super.onDestroy()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}
