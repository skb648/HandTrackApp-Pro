import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:airtouch_ultimate/core/constants/gesture_constants.dart';
import 'package:airtouch_ultimate/core/utils/gesture_classifier.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// OVERLAY SERVICE - SYSTEM-LEVEL FLOATING CURSOR
/// ═══════════════════════════════════════════════════════════════════════════════
class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.airtouch.ultimate/overlay');

  bool _isCursorVisible = false;
  bool _isDisposed = false;
  CursorState _cursorState = CursorState.normal;
  Offset _cursorPosition = Offset.zero;

  StreamController<OverlayTouchEvent>? _touchEventController;

  bool get isCursorVisible => _isCursorVisible;
  CursorState get cursorState => _cursorState;
  Offset get cursorPosition => _cursorPosition;

  Stream<OverlayTouchEvent> get touchEvents {
    _touchEventController ??= StreamController<OverlayTouchEvent>.broadcast();
    return _touchEventController!.stream;
  }

  /// Check overlay permission
  Future<bool> hasOverlayPermission() async {
    if (_isDisposed) return false;
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request overlay permission
  Future<bool> requestOverlayPermission() async {
    if (_isDisposed) return false;
    try {
      return await _channel.invokeMethod<bool>('requestOverlayPermission') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Initialize
  Future<bool> initialize() async {
    if (_isDisposed) return false;
    try {
      return await _channel.invokeMethod<bool>('initialize') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Show cursor at position
  Future<bool> showCursor({Offset? initialPosition}) async {
    if (_isDisposed) return false;
    if (_isCursorVisible) return true;

    try {
      final result = await _channel.invokeMethod<bool>('showCursor', {
        'x': initialPosition?.dx,
        'y': initialPosition?.dy,
      });
      if (result == true) {
        _isCursorVisible = true;
        _cursorPosition = initialPosition ?? Offset.zero;
      }
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Hide cursor
  Future<bool> hideCursor() async {
    if (_isDisposed) return false;
    if (!_isCursorVisible) return true;

    try {
      final result = await _channel.invokeMethod<bool>('hideCursor');
      if (result == true) {
        _isCursorVisible = false;
      }
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update cursor position (normalized 0-1)
  Future<bool> updateCursorPosition(double x, double y) async {
    if (_isDisposed || !_isCursorVisible) return false;
    _cursorPosition = Offset(x, y);
    try {
      return await _channel.invokeMethod<bool>('updateCursorPosition', {'x': x, 'y': y}) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update cursor position (absolute pixels)
  Future<bool> updateCursorPositionAbsolute(double x, double y) async {
    if (_isDisposed || !_isCursorVisible) return false;
    _cursorPosition = Offset(x, y);
    try {
      return await _channel.invokeMethod<bool>('updateCursorPositionAbsolute', {'x': x, 'y': y}) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update cursor state
  Future<bool> updateCursorState(CursorState state) async {
    if (_isDisposed || !_isCursorVisible) return false;
    _cursorState = state;
    try {
      return await _channel.invokeMethod<bool>('updateCursorState', {'state': state.name}) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update cursor rotation
  Future<bool> updateCursorRotation(double angleDegrees) async {
    if (_isDisposed || !_isCursorVisible) return false;
    try {
      return await _channel.invokeMethod<bool>('updateCursorRotation', {'angle': angleDegrees}) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get screen size
  Future<Size> getScreenSize() async {
    if (_isDisposed) return Size.zero;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getScreenSize');
      if (result != null) {
        return Size(
          (result['width'] as num?)?.toDouble() ?? 0,
          (result['height'] as num?)?.toDouble() ?? 0,
        );
      }
    } catch (e) {}
    return Size.zero;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    hideCursor();
    _touchEventController?.close();
  }
}

class OverlayTouchEvent {
  final double x;
  final double y;
  final TouchAction action;
  final DateTime timestamp;

  OverlayTouchEvent({
    required this.x,
    required this.y,
    required this.action,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum TouchAction { down, move, up, unknown }
