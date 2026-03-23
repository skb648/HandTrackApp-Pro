import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:airtouch_ultimate/core/constants/gesture_constants.dart';
import 'package:airtouch_ultimate/core/utils/ema_smoothing.dart';

/// Gesture classifier that analyzes hand landmarks to detect gestures
class GestureClassifier {
  final double pinchThreshold;
  final double dragPinchThreshold;
  final int fistMinFoldedFingers;
  final int openPalmMinExtendedFingers;
  final double swipeVelocityThreshold;

  GestureClassifier({
    this.pinchThreshold = GestureConstants.pinchThreshold,
    this.dragPinchThreshold = GestureConstants.dragPinchThreshold,
    this.fistMinFoldedFingers = GestureConstants.fistMinFoldedFingers,
    this.openPalmMinExtendedFingers = GestureConstants.openPalmMinExtendedFingers,
    this.swipeVelocityThreshold = GestureConstants.swipeVelocityThreshold,
  });

  /// Classify gesture from hand landmarks
  /// Returns GestureEvent if a gesture is detected, null otherwise
  GestureEvent? classify(List<Point3D> landmarks, {bool isLeftHand = true}) {
    if (landmarks.length != 21) {
      return null;
    }

    // Get key landmarks
    final thumbTip = landmarks[HandLandmark.thumbTip.index];
    final indexTip = landmarks[HandLandmark.indexTip.index];
    final middleTip = landmarks[HandLandmark.middleTip.index];
    final ringTip = landmarks[HandLandmark.ringTip.index];
    final wrist = landmarks[HandLandmark.wrist.index];

    // Calculate pinch distances
    final indexPinchDist = thumbTip.distanceTo(indexTip);
    final middlePinchDist = thumbTip.distanceTo(middleTip);
    final ringPinchDist = thumbTip.distanceTo(ringTip);

    // Detect pinch gestures (priority order)
    // 1. Index + Thumb pinch = Click
    if (indexPinchDist < pinchThreshold) {
      // Verify index is extended (not folded)
      if (_isFingerExtended(landmarks, HandLandmark.indexTip)) {
        return GestureEvent(
          type: GestureType.click,
          position: indexTip,
        );
      }
    }

    // 2. Middle + Thumb pinch = Back
    if (middlePinchDist < pinchThreshold) {
      // Verify middle is extended
      if (_isFingerExtended(landmarks, HandLandmark.middleTip)) {
        return GestureEvent(
          type: GestureType.back,
          position: middleTip,
        );
      }
    }

    // 3. Ring + Thumb pinch = Recents
    if (ringPinchDist < pinchThreshold) {
      // Verify ring is extended
      if (_isFingerExtended(landmarks, HandLandmark.ringTip)) {
        return GestureEvent(
          type: GestureType.recents,
          position: ringTip,
        );
      }
    }

    // 4. Fist detection = Drag start
    final fistResult = _detectFist(landmarks);
    if (fistResult.isFist) {
      return GestureEvent(
        type: GestureType.drag,
        position: landmarks[HandLandmark.middleMcp.index],
        isFistClosed: true,
        fistProgress: fistResult.progress,
      );
    }

    // 5. Open palm = Scroll/Swipe mode
    final isOpenPalm = _detectOpenPalm(landmarks);
    if (isOpenPalm) {
      return GestureEvent(
        type: GestureType.scroll,
        position: indexTip,
        isOpenPalm: true,
      );
    }

    return null;
  }

  /// Check if a finger is extended
  bool _isFingerExtended(List<Point3D> landmarks, HandLandmark tipLandmark) {
    final tip = landmarks[tipLandmark.index];
    final pip = landmarks[tipLandmark.index - 1]; // PIP joint
    final mcp = landmarks[tipLandmark.index - 2]; // MCP joint

    // Finger is extended if tip is farther from wrist than PIP
    final wrist = landmarks[HandLandmark.wrist.index];
    final tipDist = tip.distanceTo(wrist);
    final pipDist = pip.distanceTo(wrist);

    return tipDist > pipDist;
  }

  /// Detect if hand is making a fist
  _FistResult _detectFist(List<Point3D> landmarks) {
    final wrist = landmarks[HandLandmark.wrist.index];
    int foldedCount = 0;
    double totalProgress = 0;

    // Check each finger (excluding thumb)
    final fingerTips = [
      HandLandmark.indexTip,
      HandLandmark.middleTip,
      HandLandmark.ringTip,
      HandLandmark.pinkyTip,
    ];

    for (final tipLandmark in fingerTips) {
      final tip = landmarks[tipLandmark.index];
      final pip = landmarks[tipLandmark.index - 1];
      final mcp = landmarks[tipLandmark.index - 2];

      // Calculate fold progress (0 = extended, 1 = fully folded)
      final tipToWrist = tip.distanceTo(wrist);
      final mcpToWrist = mcp.distanceTo(wrist);
      final foldProgress = 1.0 - (tipToWrist / mcpToWrist).clamp(0.0, 1.0);
      totalProgress += foldProgress;

      // Finger is folded if tip is closer to wrist than MCP
      if (tipToWrist < mcpToWrist * 0.8) {
        foldedCount++;
      }
    }

    final avgProgress = totalProgress / fingerTips.length;

    return _FistResult(
      isFist: foldedCount >= fistMinFoldedFingers,
      progress: avgProgress,
      foldedCount: foldedCount,
    );
  }

  /// Detect if hand is open (all fingers extended)
  bool _detectOpenPalm(List<Point3D> landmarks) {
    final wrist = landmarks[HandLandmark.wrist.index];
    int extendedCount = 0;

    // Check each finger (excluding thumb)
    final fingerTips = [
      HandLandmark.indexTip,
      HandLandmark.middleTip,
      HandLandmark.ringTip,
      HandLandmark.pinkyTip,
    ];

    for (final tipLandmark in fingerTips) {
      final tip = landmarks[tipLandmark.index];
      final tipToWrist = tip.distanceTo(wrist);

      // Finger is extended if tip is far from wrist
      // This threshold may need calibration
      if (tipToWrist > 0.25) {
        extendedCount++;
      }
    }

    return extendedCount >= openPalmMinExtendedFingers;
  }

  /// Calculate swipe direction from velocity
  static SwipeDirection? getSwipeDirection(double vx, double vy, double threshold) {
    if (vx.abs() < threshold && vy.abs() < threshold) {
      return null;
    }

    if (vx.abs() > vy.abs()) {
      return vx > 0 ? SwipeDirection.right : SwipeDirection.left;
    } else {
      return vy > 0 ? SwipeDirection.down : SwipeDirection.up;
    }
  }

  /// Get finger angle (for advanced gesture detection)
  static double getFingerAngle(List<Point3D> landmarks, HandLandmark tipLandmark) {
    final mcp = landmarks[tipLandmark.index - 2];
    final tip = landmarks[tipLandmark.index];
    
    return atan2(tip.y - mcp.y, tip.x - mcp.x);
  }

  /// Check if thumb is extended
  static bool isThumbExtended(List<Point3D> landmarks, bool isLeftHand) {
    final thumbTip = landmarks[HandLandmark.thumbTip.index];
    final thumbIp = landmarks[HandLandmark.thumbIp.index];
    final thumbMcp = landmarks[HandLandmark.thumbMcp.index];
    final indexMcp = landmarks[HandLandmark.indexMcp.index];

    // Thumb is extended if tip is away from index finger MCP
    final distanceToIndex = thumbTip.distanceTo(indexMcp);
    
    return distanceToIndex > 0.1; // Threshold may need adjustment
  }
}

/// Result of fist detection
class _FistResult {
  final bool isFist;
  final double progress;
  final int foldedCount;

  _FistResult({
    required this.isFist,
    required this.progress,
    required this.foldedCount,
  });
}

/// Gesture event emitted when a gesture is detected
class GestureEvent {
  final GestureType type;
  final DateTime timestamp;
  final Point3D? position;
  final SwipeDirection? swipeDirection;
  final double? swipeDistance;
  final bool isFistClosed;
  final double fistProgress;
  final bool isOpenPalm;

  GestureEvent({
    required this.type,
    DateTime? timestamp,
    this.position,
    this.swipeDirection,
    this.swipeDistance,
    this.isFistClosed = false,
    this.fistProgress = 0,
    this.isOpenPalm = false,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'GestureEvent(type: $type, position: $position)';
}

/// Hand data from tracking
class HandData {
  final List<Point3D> landmarks;
  final bool isLeftHand;
  final double confidence;
  final DateTime timestamp;
  final ui.Rect boundingBox;

  HandData({
    required this.landmarks,
    required this.isLeftHand,
    required this.confidence,
    required this.boundingBox,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Point3D operator [](HandLandmark landmark) => landmarks[landmark.index];
  
  /// Get cursor position (index fingertip)
  Point3D get cursorPosition => landmarks[HandLandmark.indexTip.index];
  
  /// Get palm center
  Point3D get palmCenter {
    final wrist = landmarks[HandLandmark.wrist.index];
    final middleMcp = landmarks[HandLandmark.middleMcp.index];
    return Point3D(
      (wrist.x + middleMcp.x) / 2,
      (wrist.y + middleMcp.y) / 2,
      (wrist.z + middleMcp.z) / 2,
    );
  }
}
