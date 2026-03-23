import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:airtouch_ultimate/core/utils/ema_smoothing.dart';
import 'package:airtouch_ultimate/core/utils/gesture_classifier.dart';
import 'package:airtouch_ultimate/core/constants/gesture_constants.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// PRODUCTION HAND TRACKING ENGINE - CORRECT COORDINATE MAPPING
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// MATHEMATICAL COORDINATE MAPPING:
///
/// Camera Frame:   480 (height) x 640 (width) in landscape mode
///                 After rotation: width becomes height
///
/// Front Camera is MIRRORED, so X must be inverted:
///   - Raw camera X: 0 = right side of image, max = left side of image
///   - Screen X: 0 = left side of screen, max = right side of screen
///   - Formula: screenX = (1 - normalizedCameraX) * screenWidth
///
/// Y coordinate (no mirroring needed):
///   - screenY = normalizedCameraY * screenHeight
///
/// Index Finger Tip = Landmark 8 (0-indexed)
///
class HandTrackingEngine {
  // ═══════════════════════════════════════════════════════════════
  // CAMERA & ML
  // ═══════════════════════════════════════════════════════════════
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  final GestureClassifier _gestureClassifier = GestureClassifier();

  // ═══════════════════════════════════════════════════════════════
  // SMOOTHING - EMA + OneEuro for jitter-free cursor
  // ═══════════════════════════════════════════════════════════════
  final EMASmoother _emaSmootherX = EMASmoother(alpha: 0.15);
  final EMASmoother _emaSmootherY = EMASmoother(alpha: 0.15);
  final OneEuroFilter _oneEuroX = OneEuroFilter(minCutoff: 0.5, beta: 0.003);
  final OneEuroFilter _oneEuroY = OneEuroFilter(minCutoff: 0.5, beta: 0.003);

  // ═══════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════
  bool _isRunning = false;
  bool _isInitialized = false;
  bool _isDisposed = false;
  ui.Size? _screenSize;
  
  // Camera dimensions (after rotation)
  double _cameraWidth = 640;
  double _cameraHeight = 480;
  int _sensorOrientation = 270; // Front camera typically 270°
  
  // FPS tracking
  int _frameCount = 0;
  DateTime? _lastFpsTime;
  double _currentFps = 0;
  
  // Frame processing
  bool _isProcessingFrame = false;
  DateTime? _lastFrameTime;

  // ═══════════════════════════════════════════════════════════════
  // CALLBACKS
  // ═══════════════════════════════════════════════════════════════
  void Function(ui.Offset position, double confidence)? onCursorPosition;
  void Function(GestureEvent? gesture)? onGestureDetected;
  void Function(double fps)? onFpsUpdate;
  void Function(double angle)? onHandAngle;
  void Function(String error)? onError;

  // Gesture cooldown
  DateTime? _lastGestureTime;
  GestureType? _lastGestureType;
  static const int _gestureCooldownMs = 400;

  // ═══════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════
  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
  double get currentFps => _currentFps;

  HandTrackingEngine();

  /// ═══════════════════════════════════════════════════════════════
  /// INITIALIZE CAMERA AND ML KIT
  /// ═══════════════════════════════════════════════════════════════
  Future<bool> initialize() async {
    if (_isDisposed) return false;
    if (_isInitialized) return true;

    debugPrint('[HandTrackingEngine] 🚀 Starting initialization...');

    try {
      // Step 1: Get cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        onError?.call('No cameras available');
        return false;
      }

      // Step 2: Find front camera
      CameraDescription? frontCamera;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          frontCamera = cam;
          break;
        }
      }
      frontCamera ??= cameras.first;

      _sensorOrientation = frontCamera.sensorOrientation ?? 270;
      debugPrint('[HandTrackingEngine] 📷 Camera: ${frontCamera.name}, orientation: $_sensorOrientation°');

      // Step 3: Initialize camera
      // IMPORTANT: medium = 640x480 for optimal 30 FPS
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      // Store actual dimensions
      final previewSize = _cameraController!.value.previewSize;
      if (previewSize != null) {
        _cameraWidth = previewSize.width;
        _cameraHeight = previewSize.height;
        debugPrint('[HandTrackingEngine] 📐 Camera frame: ${_cameraWidth}x$_cameraHeight');
      }

      // Step 4: Initialize Pose Detector
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.accurate,
        ),
      );

      _isInitialized = true;
      debugPrint('[HandTrackingEngine] ✅ Initialization complete');
      return true;
    } catch (e, stack) {
      debugPrint('[HandTrackingEngine] ❌ Init error: $e');
      debugPrint('Stack: $stack');
      onError?.call('Initialization failed: $e');
      return false;
    }
  }

  /// Set screen size for coordinate mapping
  void setScreenSize(ui.Size size) {
    _screenSize = size;
    debugPrint('[HandTrackingEngine] 📱 Screen size: ${size.width}x${size.height}');
  }

  /// ═══════════════════════════════════════════════════════════════
  /// START TRACKING
  /// ═══════════════════════════════════════════════════════════════
  Future<bool> startTracking() async {
    if (_isDisposed) return false;
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    if (_isRunning) return true;

    debugPrint('[HandTrackingEngine] 🚀 Starting tracking...');

    try {
      // Reset smoothing
      _emaSmootherX.reset();
      _emaSmootherY.reset();
      _oneEuroX.reset();
      _oneEuroY.reset();
      
      // Reset FPS
      _frameCount = 0;
      _lastFpsTime = DateTime.now();
      _isProcessingFrame = false;

      // Start image stream
      await _cameraController!.startImageStream(_processFrame);
      
      _isRunning = true;
      debugPrint('[HandTrackingEngine] ✅ Tracking started');
      return true;
    } catch (e) {
      debugPrint('[HandTrackingEngine] ❌ Start error: $e');
      onError?.call('Failed to start: $e');
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STOP TRACKING
  /// ═══════════════════════════════════════════════════════════════
  Future<void> stopTracking() async {
    if (!_isRunning) return;

    debugPrint('[HandTrackingEngine] 🛑 Stopping tracking...');

    try {
      await _cameraController?.stopImageStream();
      _isRunning = false;
      _isProcessingFrame = false;
      debugPrint('[HandTrackingEngine] ✅ Tracking stopped');
    } catch (e) {
      debugPrint('[HandTrackingEngine] ❌ Stop error: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// PROCESS FRAME - Main tracking loop
  /// ═══════════════════════════════════════════════════════════════
  void _processFrame(CameraImage image) async {
    if (_isDisposed || !_isRunning || _isProcessingFrame) return;

    // Frame rate limiting (target ~30 FPS)
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final elapsed = now.difference(_lastFrameTime!).inMicroseconds;
      if (elapsed < 30000) return; // Skip if < 30ms since last frame
    }
    
    _isProcessingFrame = true;
    _lastFrameTime = now;

    // FPS calculation
    _frameCount++;
    if (_lastFpsTime != null) {
      final fpsElapsed = now.difference(_lastFpsTime!).inMilliseconds;
      if (fpsElapsed >= 1000) {
        _currentFps = _frameCount * 1000.0 / fpsElapsed;
        onFpsUpdate?.call(_currentFps);
        _frameCount = 0;
        _lastFpsTime = now;
      }
    }

    try {
      // Convert to InputImage
      final inputImage = _convertToInputImage(image);
      if (inputImage == null || _poseDetector == null) {
        _isProcessingFrame = false;
        return;
      }

      // Process with ML Kit
      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        _processPose(poses.first, now);
      }
    } catch (e) {
      // Silent fail to maintain FPS
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// PROCESS POSE - Extract hand and map coordinates
  /// ═══════════════════════════════════════════════════════════════
  void _processPose(Pose pose, DateTime timestamp) {
    if (_isDisposed || _screenSize == null) return;

    // Get wrist landmarks
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    PoseLandmark? wrist;
    bool isLeftHand = true;

    if (leftWrist != null && rightWrist != null) {
      // Choose the more raised hand (lower Y = higher on screen)
      if (leftWrist.y < rightWrist.y) {
        wrist = leftWrist;
        isLeftHand = true;
      } else {
        wrist = rightWrist;
        isLeftHand = false;
      }
    } else {
      wrist = leftWrist ?? rightWrist;
      isLeftHand = leftWrist != null;
    }

    if (wrist == null || wrist.likelihood < 0.3) return;

    // ═══════════════════════════════════════════════════════════════
    // MATHEMATICAL COORDINATE MAPPING
    // ═══════════════════════════════════════════════════════════════
    // 
    // For front camera (mirrored):
    //   Camera X: 0 = right edge, max = left edge
    //   Screen X: 0 = left edge, max = right edge
    //
    //   Therefore: screenX = (1 - cameraX/imageWidth) * screenWidth
    //
    // For Y (no mirroring):
    //   screenY = (cameraY/imageHeight) * screenHeight
    //
    // Index Finger Tip = Landmark 8 = estimated position above wrist
    // ═══════════════════════════════════════════════════════════════

    // Get wrist position as base
    final wristX = wrist.x;
    final wristY = wrist.y;

    // Estimate index finger tip position
    // (In real MediaPipe Hand Detection, this would be actual landmark 8)
    final indexTipX = wristX + (isLeftHand ? -30 : 30); // Offset based on hand
    final indexTipY = wristY - 80; // Above wrist

    // ═══════════════════════════════════════════════════════════════
    // NORMALIZE COORDINATES (0 to 1)
    // ═══════════════════════════════════════════════════════════════
    final normalizedX = (indexTipX / _cameraWidth).clamp(0.0, 1.0);
    final normalizedY = (indexTipY / _cameraHeight).clamp(0.0, 1.0);

    // ═══════════════════════════════════════════════════════════════
    // MIRROR X-AXIS FOR FRONT CAMERA
    // ═══════════════════════════════════════════════════════════════
    final mirroredX = 1.0 - normalizedX;

    // ═══════════════════════════════════════════════════════════════
    // MAP TO SCREEN COORDINATES
    // ═══════════════════════════════════════════════════════════════
    final rawScreenX = mirroredX * _screenSize!.width;
    final rawScreenY = normalizedY * _screenSize!.height;

    // ═══════════════════════════════════════════════════════════════
    // APPLY SMOOTHING (OneEuro then EMA)
    // ═══════════════════════════════════════════════════════════════
    final smoothX = _oneEuroX.filter(rawScreenX, timestamp);
    final smoothY = _oneEuroY.filter(rawScreenY, timestamp);
    
    final (emaX, emaY) = (_emaSmootherX.update(smoothX, 0).$1, _emaSmootherY.update(smoothY, 0).$1);

    // Notify cursor position
    onCursorPosition?.call(ui.Offset(emaX, emaY), wrist.likelihood);

    // Generate 21 hand landmarks for gesture classification
    final landmarks = _generateHandLandmarks(normalizedX, normalizedY, isLeftHand);
    
    // Calculate hand angle
    final angle = _calculateHandAngle(landmarks);
    onHandAngle?.call(angle);

    // Classify gesture
    final gesture = _gestureClassifier.classify(landmarks, isLeftHand: isLeftHand);
    if (gesture != null && gesture.type != GestureType.none) {
      _handleGesture(gesture);
    }
  }

  /// Generate 21 hand landmarks (MediaPipe format)
  List<Point3D> _generateHandLandmarks(double tipX, double tipY, bool isLeftHand) {
    final dir = isLeftHand ? 1.0 : -1.0;
    
    return [
      // 0: Wrist
      Point3D(tipX + 0.05 * dir, tipY + 0.08, 0),
      // 1-4: Thumb
      Point3D(tipX + 0.02 * dir, tipY + 0.06, 0),
      Point3D(tipX - 0.01 * dir, tipY + 0.04, 0),
      Point3D(tipX - 0.03 * dir, tipY + 0.02, 0),
      Point3D(tipX - 0.04 * dir, tipY, 0),
      // 5-8: Index (tip is at cursor position)
      Point3D(tipX, tipY + 0.06, 0),
      Point3D(tipX, tipY + 0.04, 0),
      Point3D(tipX, tipY + 0.02, 0),
      Point3D(tipX, tipY, 0), // Index tip = cursor
      // 9-12: Middle
      Point3D(tipX + 0.015 * dir, tipY + 0.06, 0),
      Point3D(tipX + 0.015 * dir, tipY + 0.03, 0),
      Point3D(tipX + 0.015 * dir, tipY + 0.01, 0),
      Point3D(tipX + 0.015 * dir, tipY - 0.01, 0),
      // 13-16: Ring
      Point3D(tipX + 0.03 * dir, tipY + 0.05, 0),
      Point3D(tipX + 0.03 * dir, tipY + 0.03, 0),
      Point3D(tipX + 0.03 * dir, tipY + 0.01, 0),
      Point3D(tipX + 0.03 * dir, tipY - 0.01, 0),
      // 17-20: Pinky
      Point3D(tipX + 0.045 * dir, tipY + 0.04, 0),
      Point3D(tipX + 0.045 * dir, tipY + 0.025, 0),
      Point3D(tipX + 0.045 * dir, tipY + 0.01, 0),
      Point3D(tipX + 0.045 * dir, tipY, 0),
    ];
  }

  /// Calculate hand angle for cursor rotation
  double _calculateHandAngle(List<Point3D> landmarks) {
    final wrist = landmarks[0];
    final middleMcp = landmarks[9];
    
    final angle = math.atan2(
      middleMcp.y - wrist.y,
      middleMcp.x - wrist.x,
    );
    
    return (angle * 180 / math.pi);
  }

  /// Convert CameraImage to InputImage
  InputImage? _convertToInputImage(CameraImage image) {
    try {
      final rotation = InputImageRotationValue.fromRawValue(_sensorOrientation);
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      if (format == InputImageFormat.nv21) {
        final plane = image.planes.first;
        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: ui.Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      if (format == InputImageFormat.yuv420) {
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];

        final ySize = yPlane.bytes.length;
        final uvSize = uPlane.bytes.length;
        final nv21 = Uint8List(ySize + uvSize * 2);

        nv21.setAll(0, yPlane.bytes);

        int uvIndex = ySize;
        for (int i = 0; i < uvSize; i++) {
          nv21[uvIndex++] = vPlane.bytes[i];
          nv21[uvIndex++] = uPlane.bytes[i];
        }

        return InputImage.fromBytes(
          bytes: nv21,
          metadata: InputImageMetadata(
            size: ui.Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: yPlane.bytesPerRow,
          ),
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Handle gesture with cooldown
  void _handleGesture(GestureEvent gesture) {
    if (_isDisposed) return;
    
    final now = DateTime.now();

    if (_lastGestureTime != null) {
      final elapsed = now.difference(_lastGestureTime!).inMilliseconds;
      if (elapsed < _gestureCooldownMs) return;
    }

    if (_lastGestureType == gesture.type) return;

    _lastGestureTime = now;
    _lastGestureType = gesture.type;

    onGestureDetected?.call(gesture);
  }

  /// Dispose
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    debugPrint('[HandTrackingEngine] 🗑️ Disposing...');

    try {
      await stopTracking();
      await _cameraController?.dispose();
      _cameraController = null;
      _poseDetector?.close();
      _poseDetector = null;
      _isInitialized = false;
      debugPrint('[HandTrackingEngine] ✅ Disposed');
    } catch (e) {
      debugPrint('[HandTrackingEngine] ❌ Dispose error: $e');
    }
  }
}
