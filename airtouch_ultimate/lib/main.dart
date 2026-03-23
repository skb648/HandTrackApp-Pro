import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vibration/vibration.dart';

// ==========================================
// CRASH-PROOF AIRTOUCH ULTIMATE v5.0
// Android 16+ Compliant
// Defensive Initialization Pattern
// ==========================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exception}');
  };
  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  runZonedGuarded(() {
    runApp(const AirTouchUltimateApp());
  }, (error, stackTrace) {
    debugPrint('Uncaught error: $error');
  });
}

class AirTouchUltimateApp extends StatelessWidget {
  const AirTouchUltimateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirTouch Ultimate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A1A),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  static const _controlChannel = MethodChannel('com.airtouch.ultimate/control');
  
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  List<CameraDescription> _cameras = [];
  
  PoseDetector? _poseDetector;
  bool _isPoseDetectorInitialized = false;
  
  bool _isTracking = false;
  bool _isInitializing = false;
  
  bool _hasCameraPermission = false;
  bool _canDrawOverlays = false;
  bool _hasAccessibility = false;
  
  Offset _cursorPosition = const Offset(0.5, 0.5);
  String _currentGesture = 'none';
  
  Size _screenSize = const Size(1080, 2400);
  int _cameraWidth = 480;
  int _cameraHeight = 640;
  
  String? _errorMessage;
  
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  double _currentFps = 0;
  
  double _smoothedX = 0.5;
  double _smoothedY = 0.5;
  static const _smoothingAlpha = 0.25;
  
  DateTime _lastGestureTime = DateTime.now();
  static const _gestureDebounceMs = 300;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionStatus();
    _enableWakelock();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  Future<void> _checkPermissionStatus() async {
    try {
      final cameraStatus = await Permission.camera.status;
      
      bool canDraw = false;
      try {
        canDraw = await _controlChannel.invokeMethod('canDrawOverlays') ?? false;
      } catch (e) {
        debugPrint('Overlay check error: $e');
      }
      
      bool hasAccessibility = false;
      try {
        hasAccessibility = await _controlChannel.invokeMethod('isAccessibilityEnabled') ?? false;
      } catch (e) {
        debugPrint('Accessibility check error: $e');
      }
      
      if (mounted) {
        setState(() {
          _hasCameraPermission = cameraStatus.isGranted;
          _canDrawOverlays = canDraw;
          _hasAccessibility = hasAccessibility;
        });
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
    }
  }
  
  Future<bool> _requestAllPermissions() async {
    try {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _showError('Camera permission is required');
        return false;
      }
      
      try {
        final canDraw = await _controlChannel.invokeMethod('canDrawOverlays') ?? false;
        if (!canDraw) {
          await _controlChannel.invokeMethod('requestOverlayPermission');
          await Future.delayed(const Duration(milliseconds: 500));
          
          final nowCanDraw = await _controlChannel.invokeMethod('canDrawOverlays') ?? false;
          if (!nowCanDraw) {
            _showError('Overlay permission is required for cursor display');
            return false;
          }
        }
      } catch (e) {
        debugPrint('Overlay permission error: $e');
      }
      
      try {
        final hasAccessibility = await _controlChannel.invokeMethod('isAccessibilityEnabled') ?? false;
        if (!hasAccessibility) {
          _showError('Please enable Accessibility Service for clicking');
          await _controlChannel.invokeMethod('openAccessibilitySettings');
          return false;
        }
      } catch (e) {
        debugPrint('Accessibility check error: $e');
      }
      
      await _checkPermissionStatus();
      return _hasCameraPermission && _canDrawOverlays && _hasAccessibility;
    } catch (e) {
      _showError('Permission request failed: $e');
      return false;
    }
  }

  Future<bool> _initializeCamera() async {
    if (_cameraController != null && _isCameraInitialized) return true;
    
    try {
      debugPrint('Initializing camera...');
      
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No camera found on this device');
        return false;
      }
      
      CameraDescription? frontCamera;
      for (final camera in _cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }
      frontCamera ??= _cameras.first;
      
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );
      
      await _cameraController!.initialize();
      
      final size = _cameraController!.value.previewSize;
      if (size != null) {
        _cameraWidth = size.width.toInt();
        _cameraHeight = size.height.toInt();
      }
      
      if (mounted) setState(() => _isCameraInitialized = true);
      
      debugPrint('Camera initialized: ${_cameraWidth}x$_cameraHeight');
      return true;
    } catch (e) {
      _showError('Camera initialization failed: $e');
      _cameraController?.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
      return false;
    }
  }
  
  Future<void> _disposeCamera() async {
    try {
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
        _cameraController = null;
        _isCameraInitialized = false;
      }
    } catch (e) {
      debugPrint('Camera dispose error: $e');
    }
  }

  Future<bool> _initializePoseDetector() async {
    if (_poseDetector != null && _isPoseDetectorInitialized) return true;
    
    try {
      debugPrint('Initializing pose detector...');
      
      final options = PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      );
      
      _poseDetector = PoseDetector(options: options);
      _isPoseDetectorInitialized = true;
      
      debugPrint('Pose detector initialized');
      return true;
    } catch (e) {
      _showError('ML Kit initialization failed: $e');
      _poseDetector?.close();
      _poseDetector = null;
      _isPoseDetectorInitialized = false;
      return false;
    }
  }
  
  Future<void> _disposePoseDetector() async {
    try {
      _poseDetector?.close();
      _poseDetector = null;
      _isPoseDetectorInitialized = false;
    } catch (e) {
      debugPrint('Pose detector dispose error: $e');
    }
  }

  Future<void> _startTracking() async {
    if (_isInitializing || _isTracking) return;
    
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });
    
    try {
      debugPrint('=== STARTING TRACKING ===');
      
      final hasPermissions = await _requestAllPermissions();
      if (!hasPermissions) {
        debugPrint('Permissions not granted');
        if (mounted) setState(() => _isInitializing = false);
        return;
      }
      
      final cameraReady = await _initializeCamera();
      if (!cameraReady) {
        if (mounted) setState(() => _isInitializing = false);
        return;
      }
      
      final detectorReady = await _initializePoseDetector();
      if (!detectorReady) {
        await _disposeCamera();
        if (mounted) setState(() => _isInitializing = false);
        return;
      }
      
      try {
        await _controlChannel.invokeMethod('showOverlay');
      } catch (e) {
        debugPrint('Overlay error: $e');
      }
      
      if (_cameraController != null && 
          _cameraController!.value.isInitialized &&
          !_cameraController!.value.isStreamingImages) {
        await _cameraController!.startImageStream(_processCameraImage);
      }
      
      debugPrint('=== TRACKING STARTED ===');
      
      if (mounted) {
        setState(() {
          _isTracking = true;
          _isInitializing = false;
        });
      }
      
      _vibrate();
    } catch (e) {
      debugPrint('Start tracking error: $e');
      _showError('Failed to start: $e');
      if (mounted) setState(() => _isInitializing = false);
    }
  }
  
  Future<void> _stopTracking() async {
    if (!_isTracking) return;
    
    try {
      debugPrint('=== STOPPING TRACKING ===');
      
      await _disposeCamera();
      
      try {
        await _controlChannel.invokeMethod('hideOverlay');
      } catch (e) {
        debugPrint('Hide overlay error: $e');
      }
      
      await _disposePoseDetector();
      
      if (mounted) setState(() => _isTracking = false);
      
      _vibrate();
      debugPrint('=== TRACKING STOPPED ===');
    } catch (e) {
      debugPrint('Stop tracking error: $e');
      _showError('Error stopping: $e');
    }
  }

  void _processCameraImage(CameraImage image) {
    if (!_isTracking) return;
    
    _frameCount++;
    final now = DateTime.now();
    if (now.difference(_lastFpsUpdate).inMilliseconds >= 1000) {
      if (mounted) setState(() => _currentFps = _frameCount.toDouble());
      _frameCount = 0;
      _lastFpsUpdate = now;
    }
    
    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage == null || _poseDetector == null) return;
      
      _poseDetector!.processImage(inputImage).then((poses) {
        if (poses.isEmpty || !_isTracking) return;
        _handlePose(poses.first);
      }).catchError((e) {
        debugPrint('Pose processing error: $e');
      });
    } catch (e) {
      debugPrint('Image processing error: $e');
    }
  }
  
  InputImage? _convertToInputImage(CameraImage image) {
    try {
      final camera = _cameraController?.description;
      if (camera == null) return null;
      
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
      if (rotation == null) return null;
      
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;
      
      final plane = image.planes.first;
      
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('InputImage conversion error: $e');
      return null;
    }
  }

  void _handlePose(Pose pose) {
    try {
      final indexTip = pose.landmarks[PoseLandmarkType.rightIndex];
      final thumbTip = pose.landmarks[PoseLandmarkType.rightThumb];
      final wrist = pose.landmarks[PoseLandmarkType.rightWrist];
      
      if (indexTip == null) return;
      
      final cameraW = _cameraWidth.toDouble();
      final cameraH = _cameraHeight.toDouble();
      
      double normalizedX = (indexTip.x / cameraW).clamp(0.0, 1.0);
      double normalizedY = (indexTip.y / cameraH).clamp(0.0, 1.0);
      
      _smoothedX = _smoothingAlpha * normalizedX + (1 - _smoothingAlpha) * _smoothedX;
      _smoothedY = _smoothingAlpha * normalizedY + (1 - _smoothingAlpha) * _smoothedY;
      
      if (mounted) {
        setState(() {
          _cursorPosition = Offset(_smoothedX, _smoothedY);
        });
      }
      
      _controlChannel.invokeMethod('updateCursorPosition', {
        'x': _smoothedX,
        'y': _smoothedY,
      }).catchError((e) {
        debugPrint('Cursor update error: $e');
      });
      
      if (thumbTip != null && wrist != null) {
        _detectGestures(indexTip, thumbTip, wrist);
      }
    } catch (e) {
      debugPrint('Pose handling error: $e');
    }
  }
  
  void _detectGestures(PoseLandmark indexTip, PoseLandmark thumbTip, PoseLandmark wrist) {
    final now = DateTime.now();
    if (now.difference(_lastGestureTime).inMilliseconds < _gestureDebounceMs) return;
    
    try {
      final pinchDistance = _calculateDistance(indexTip, thumbTip);
      final pinchThreshold = (_cameraWidth * 0.1).toDouble();
      
      if (pinchDistance < pinchThreshold) {
        if (_currentGesture != 'pinch') {
          _lastGestureTime = now;
          if (mounted) setState(() => _currentGesture = 'pinch');
          _performClick();
        }
        return;
      }
      
      if (_currentGesture != 'open') {
        if (mounted) setState(() => _currentGesture = 'open');
      }
    } catch (e) {
      debugPrint('Gesture detection error: $e');
    }
  }
  
  double _calculateDistance(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  Future<void> _performClick() async {
    try {
      final screenX = _smoothedX * _screenSize.width;
      final screenY = _smoothedY * _screenSize.height;
      
      await _controlChannel.invokeMethod('performClick', {
        'x': screenX,
        'y': screenY,
      });
      
      _vibrate();
    } catch (e) {
      debugPrint('Click error: $e');
    }
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Wakelock error: $e');
    }
  }
  
  void _vibrate() {
    try {
      Vibration.vibrate(duration: 50);
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }
  
  void _showError(String message) {
    debugPrint('ERROR: $message');
    if (mounted) {
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    debugPrint('MainScreen dispose');
    if (_isTracking) _stopTracking();
    _disposeCamera();
    _disposePoseDetector();
    try {
      WakelockPlus.disable();
    } catch (e) {}
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isTracking ? _buildTrackingView() : _buildStartView(),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/icon/ic_launcher.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF6C63FF),
                  child: const Icon(Icons.back_hand_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AirTouch Ultimate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Hand Gesture Controller v5.0', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          _buildStatusIndicator(),
        ],
      ),
    );
  }
  
  Widget _buildStatusIndicator() {
    Color color = _isTracking ? Colors.green : (_isInitializing ? Colors.orange : Colors.grey);
    String text = _isTracking ? 'Active' : (_isInitializing ? 'Starting...' : 'Stopped');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  
  Widget _buildStartView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.touch_app_rounded, size: 70, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 32),
            const Text('Ready to Control', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Text('Tap START to begin hand tracking.\nMove your index finger to control cursor.\nPinch thumb & index to click.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade400, height: 1.5)),
            const SizedBox(height: 24),
            _buildPermissionStatus(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPermissionStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildPermissionRow('Camera', _hasCameraPermission, () async {
            await Permission.camera.request();
            _checkPermissionStatus();
          }),
          const SizedBox(height: 8),
          _buildPermissionRow('Overlay', _canDrawOverlays, () async {
            try {
              await _controlChannel.invokeMethod('requestOverlayPermission');
              await Future.delayed(const Duration(milliseconds: 500));
              _checkPermissionStatus();
            } catch (e) {
              _showError('Could not request overlay permission');
            }
          }),
          const SizedBox(height: 8),
          _buildPermissionRow('Accessibility', _hasAccessibility, () async {
            try {
              await _controlChannel.invokeMethod('openAccessibilitySettings');
            } catch (e) {
              _showError('Could not open settings');
            }
          }),
        ],
      ),
    );
  }
  
  Widget _buildPermissionRow(String name, bool isGranted, VoidCallback onRequest) {
    return Row(
      children: [
        Icon(isGranted ? Icons.check_circle : Icons.radio_button_unchecked, color: isGranted ? Colors.green : Colors.grey, size: 20),
        const SizedBox(width: 8),
        Text(name, style: TextStyle(color: isGranted ? Colors.white : Colors.grey, fontSize: 14)),
        const Spacer(),
        if (!isGranted) TextButton(onPressed: onRequest, child: const Text('Grant')),
      ],
    );
  }
  
  Widget _buildTrackingView() {
    return Stack(
      children: [
        if (_cameraController != null && _cameraController!.value.isInitialized)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..scale(-1.0, 1.0),
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
        Positioned(
          left: _cursorPosition.dx * _screenSize.width - 24,
          top: _cursorPosition.dy * _screenSize.height - 24,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6C63FF), width: 2),
            ),
            child: Icon(_currentGesture == 'pinch' ? Icons.touch_app : Icons.back_hand, color: const Color(0xFF6C63FF)),
          ),
        ),
        Positioned(
          top: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('FPS: ${_currentFps.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                Text('Gesture: $_currentGesture', style: TextStyle(color: _currentGesture == 'pinch' ? Colors.green : Colors.white, fontSize: 12)),
                Text('Cursor: ${(_smoothedX * 100).toStringAsFixed(0)}%, ${(_smoothedY * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isInitializing ? null : (_isTracking ? _stopTracking : _startTracking),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isTracking ? Colors.red.shade600 : const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isInitializing)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              else
                Icon(_isTracking ? Icons.stop : Icons.play_arrow, size: 24),
              const SizedBox(width: 8),
              Text(_isInitializing ? 'Starting...' : (_isTracking ? 'STOP CURSOR' : 'START CURSOR'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
