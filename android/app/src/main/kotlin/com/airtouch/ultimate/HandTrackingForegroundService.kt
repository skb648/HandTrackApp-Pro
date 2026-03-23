package com.airtouch.ultimate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * HAND TRACKING FOREGROUND SERVICE - ANDROID 16+ COMPATIBLE
 * ═══════════════════════════════════════════════════════════════════════════════
 * 
 * Keeps the hand tracking process alive with a persistent notification.
 * Uses foregroundServiceType="camera" for Android 14+ compatibility.
 */
class HandTrackingForegroundService : Service() {

    companion object {
        private const val TAG = "HandTrackingService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "airtouch_tracking_channel"
        private const val CHANNEL_NAME = "Hand Tracking Service"

        const val ACTION_START = "com.airtouch.ultimate.action.START"
        const val ACTION_STOP = "com.airtouch.ultimate.action.STOP"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): HandTrackingForegroundService = this@HandTrackingForegroundService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.i(TAG, "✅ HandTrackingForegroundService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startForegroundService()
            ACTION_STOP -> stopForegroundService()
        }
        return START_STICKY
    }

    private fun startForegroundService() {
        if (isRunning) {
            Log.d(TAG, "Service already running")
            return
        }

        Log.i(TAG, "🚀 Starting foreground service")

        val notification = createNotification()

        try {
            // ═══════════════════════════════════════════════════════════
            // ANDROID 14+ REQUIRES FOREGROUND SERVICE TYPE
            // ═══════════════════════════════════════════════════════════
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }

            isRunning = true
            Log.i(TAG, "✅ Foreground service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start foreground service: ${e.message}")
        }
    }

    private fun stopForegroundService() {
        Log.i(TAG, "🛑 Stopping foreground service")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        stopSelf()
        isRunning = false
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps hand tracking active while using other apps"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }

    private fun createNotification(): Notification {
        // Intent to open the app when notification is tapped
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Stop intent
        val stopIntent = Intent(this, HandTrackingForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.foreground_service_notification_title))
            .setContentText(getString(R.string.foreground_service_notification_text))
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop Tracking",
                stopPendingIntent
            )
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    override fun onDestroy() {
        Log.i(TAG, "❌ HandTrackingForegroundService destroyed")
        isRunning = false
        super.onDestroy()
    }
}
