import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Hand Tracking Engine with proper coordinate mapping
/// Converts camera coordinates to screen coordinates with X-axis mirroring
class HandTrackingEngine {
  // Camera frame dimensions (typical front camera)
  static const double cameraWidth = 480.0;
  static const double cameraHeight = 640.0;
  
  // Screen dimensions (set from device)
  double screenWidth = 1080.0;
  double screenHeight = 2400.0;
  
  // Smoothing parameters (EMA - Exponential Moving Average)
  static const double smoothingAlpha = 0.15; // Lower = smoother but more lag
  static const double oneEuroMinCutoff = 1.0;
  static const double oneEuroBeta = 0.007;
  static const double oneEuroDcutoff = 1.0;
  
  // Current smoothed position
  double _smoothedX = 0.5;
  double _smoothedY = 0.5;
  
  // Previous raw position for velocity calculation
  double _prevRawX = 0.5;
  double _prevRawY = 0.5;
  
  // Previous filtered position for One Euro Filter
  double _prevFilteredX = 0.5;
  double _prevFilteredY = 0.5;
  
  // Timestamps
  DateTime _lastUpdateTime = DateTime.now();
  
  // Gesture thresholds
  static const double pinchThreshold = 40.0;
  static const double fistThreshold = 1.2;
  
  /// Update screen dimensions
  void updateScreenDimensions(double width, double height) {
    screenWidth = width;
    screenHeight = height;
  }
  
  /// Convert camera coordinates to normalized screen coordinates
  /// cameraX: X coordinate from camera (0 to cameraWidth)
  /// cameraY: Y coordinate from camera (0 to cameraHeight)
  /// Returns: Normalized coordinates (0.0 to 1.0)
  CoordinateResult mapCameraToScreen(double cameraX, double cameraY) {
    try {
      // Step 1: Normalize camera coordinates to 0-1 range
      final normalizedX = (cameraX / cameraWidth).clamp(0.0, 1.0);
      final normalizedY = (cameraY / cameraHeight).clamp(0.0, 1.0);
      
      // Step 2: Mirror X axis for natural mirror behavior
      // (Front camera shows mirrored view, we want natural feel)
      final mirroredX = 1.0 - normalizedX;
      
      // Step 3: Apply smoothing filter
      final smoothed = applySmoothing(mirroredX, normalizedY);
      
      // Step 4: Convert to screen coordinates
      final screenX = smoothed.x * screenWidth;
      final screenY = smoothed.y * screenHeight;
      
      return CoordinateResult(
        normalizedX: smoothed.x,
        normalizedY: smoothed.y,
        screenX: screenX,
        screenY: screenY,
      );
    } catch (e) {
      debugPrint('Coordinate mapping error: $e');
      return CoordinateResult(
        normalizedX: 0.5,
        normalizedY: 0.5,
        screenX: screenWidth / 2,
        screenY: screenHeight / 2,
      );
    }
  }
  
  /// Apply EMA (Exponential Moving Average) smoothing
  SmoothedResult applySmoothing(double rawX, double rawY) {
    final now = DateTime.now();
    final dt = now.difference(_lastUpdateTime).inMicroseconds / 1000000.0;
    _lastUpdateTime = now;
    
    if (dt <= 0) {
      return SmoothedResult(x: _smoothedX, y: _smoothedY);
    }
    
    // One Euro Filter implementation for better low-latency smoothing
    final filteredX = _oneEuroFilter1D(
      rawX, 
      _prevRawX, 
      _prevFilteredX, 
      dt
    );
    final filteredY = _oneEuroFilter1D(
      rawY, 
      _prevRawY, 
      _prevFilteredY, 
      dt
    );
    
    // Update previous values
    _prevRawX = rawX;
    _prevRawY = rawY;
    _prevFilteredX = filteredX;
    _prevFilteredY = filteredY;
    
    // Store smoothed values
    _smoothedX = filteredX;
    _smoothedY = filteredY;
    
    return SmoothedResult(x: filteredX, y: filteredY);
  }
  
  /// One Euro Filter for single dimension
  double _oneEuroFilter1D(double x, double prevX, double prevFiltered, double dt) {
    // Calculate derivative (velocity)
    final dx = (x - prevX) / dt;
    
    // Filter the derivative
    final edx = _lowPassFilter(dx, 0.0, oneEuroDcutoff, dt);
    
    // Calculate adaptive cutoff frequency
    final cutoff = oneEuroMinCutoff + oneEuroBeta * edx.abs();
    
    // Filter the main signal
    return _lowPassFilter(x, prevFiltered, cutoff, dt);
  }
  
  /// Simple low-pass filter
  double _lowPassFilter(double x, double prevFiltered, double cutoff, double dt) {
    final tau = 1.0 / (2.0 * math.pi * cutoff);
    final alpha = 1.0 / (1.0 + tau / dt);
    return prevFiltered + alpha * (x - prevFiltered);
  }
  
  /// Detect pinch gesture (thumb tip close to index finger tip)
  GestureResult detectPinchGesture(
    double thumbTipX, double thumbTipY,
    double indexTipX, double indexTipY,
  ) {
    final distance = _calculateDistance(thumbTipX, thumbTipY, indexTipX, indexTipY);
    final isPinching = distance < pinchThreshold;
    
    return GestureResult(
      gestureType: isPinching ? GestureType.pinch : GestureType.none,
      confidence: isPinching ? 1.0 - (distance / pinchThreshold) : 0.0,
      distance: distance,
    );
  }
  
  /// Detect fist gesture (all fingers closed)
  GestureResult detectFistGesture(
    double indexTipX, double indexTipY,
    double indexMcpX, double indexMcpY,
    double wristX, double wristY,
  ) {
    // Calculate distance from index tip to wrist
    final tipToWrist = _calculateDistance(indexTipX, indexTipY, wristX, wristY);
    
    // Calculate distance from index MCP to wrist (reference length)
    final mcpToWrist = _calculateDistance(indexMcpX, indexMcpY, wristX, wristY);
    
    // If tip is close to wrist relative to MCP, it's a fist
    final ratio = tipToWrist / (mcpToWrist > 0 ? mcpToWrist : 1.0);
    final isFist = ratio < fistThreshold;
    
    return GestureResult(
      gestureType: isFist ? GestureType.fist : GestureType.none,
      confidence: isFist ? 1.0 - (ratio / fistThreshold) : 0.0,
    );
  }
  
  /// Calculate Euclidean distance between two points
  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Reset smoothing state
  void reset() {
    _smoothedX = 0.5;
    _smoothedY = 0.5;
    _prevRawX = 0.5;
    _prevRawY = 0.5;
    _prevFilteredX = 0.5;
    _prevFilteredY = 0.5;
    _lastUpdateTime = DateTime.now();
  }
}

/// Result of coordinate mapping
class CoordinateResult {
  final double normalizedX; // 0.0 to 1.0
  final double normalizedY; // 0.0 to 1.0
  final double screenX;     // Actual screen X coordinate
  final double screenY;     // Actual screen Y coordinate
  
  const CoordinateResult({
    required this.normalizedX,
    required this.normalizedY,
    required this.screenX,
    required this.screenY,
  });
}

/// Result of smoothing filter
class SmoothedResult {
  final double x;
  final double y;
  
  const SmoothedResult({required this.x, required this.y});
}

/// Gesture types
enum GestureType {
  none,
  pinch,
  fist,
  wave,
  swipeLeft,
  swipeRight,
}

/// Result of gesture detection
class GestureResult {
  final GestureType gestureType;
  final double confidence; // 0.0 to 1.0
  final double distance;
  
  const GestureResult({
    required this.gestureType,
    required this.confidence,
    this.distance = 0.0,
  });
}
