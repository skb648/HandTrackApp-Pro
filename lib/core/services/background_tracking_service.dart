import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// BACKGROUND TRACKING SERVICE - ANDROID 16+ COMPATIBLE
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Ensures hand tracking continues when app is minimized.
/// Uses flutter_background_service with proper foreground notification.
class BackgroundTrackingService {
  static final BackgroundTrackingService _instance = BackgroundTrackingService._internal();
  factory BackgroundTrackingService() => _instance;
  BackgroundTrackingService._internal();

  static const String _notificationChannelId = 'airtouch_tracking_channel';
  static const int _notificationId = 1001;

  bool _isInitialized = false;
  bool _isRunning = false;
  final StreamController<Map<String, dynamic>> _dataController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  bool get isRunning => _isRunning;

  /// Initialize background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        foregroundServiceNotificationId: _notificationId,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'AirTouch Ultimate',
        initialNotificationContent: 'Hand tracking is active',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    _isInitialized = true;
    debugPrint('[BackgroundService] ✅ Initialized');
  }

  /// Start the background service
  Future<bool> startService() async {
    if (!_isInitialized) await initialize();

    final service = FlutterBackgroundService();
    final started = await service.startService();

    if (started) {
      _isRunning = true;
      debugPrint('[BackgroundService] ✅ Started');

      // Listen to data from background
      service.on('tracking_data').listen((event) {
        if (event != null) {
          _dataController.add(Map<String, dynamic>.from(event));
        }
      });
    }

    return started;
  }

  /// Stop the background service
  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    _isRunning = false;
    debugPrint('[BackgroundService] 🛑 Stopped');
  }

  /// Send data to background service
  void sendToBackground(String event, Map<String, dynamic> data) {
    final service = FlutterBackgroundService();
    service.invoke(event, data);
  }

  /// Background service entry point
  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });

      service.on('stop').listen((event) {
        service.stopSelf();
      });

      service.on('updateNotification').listen((event) {
        if (event != null) {
          service.setForegroundNotificationInfo(
            title: event['title'] ?? 'AirTouch Ultimate',
            content: event['content'] ?? 'Hand tracking is active',
          );
        }
      });
    }

    // Keep service alive with periodic updates
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "AirTouch Ultimate - Tracking",
          content: "Hand tracking is active in background",
        );
      }

      service.invoke('tracking_data', {
        'status': 'running',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }

  void dispose() {
    _dataController.close();
  }
}
