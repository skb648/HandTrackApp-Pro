import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// FOREGROUND SERVICE CONTROLLER
/// ═══════════════════════════════════════════════════════════════════════════════
class ForegroundServiceController {
  static const MethodChannel _channel = MethodChannel('com.airtouch.ultimate/foreground');
  
  static final ForegroundServiceController instance = ForegroundServiceController._internal();
  ForegroundServiceController._internal();

  /// Start foreground service
  Future<bool> startService() async {
    try {
      return await _channel.invokeMethod<bool>('startService') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Stop foreground service
  Future<bool> stopService() async {
    try {
      return await _channel.invokeMethod<bool>('stopService') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if service is running
  Future<bool> isServiceRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isServiceRunning') ?? false;
    } catch (e) {
      return false;
    }
  }
}
