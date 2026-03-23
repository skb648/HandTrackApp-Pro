import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:airtouch_ultimate/core/constants/app_theme.dart';
import 'package:airtouch_ultimate/core/services/hand_tracking_engine.dart';
import 'package:airtouch_ultimate/core/services/overlay_service.dart';
import 'package:airtouch_ultimate/core/services/accessibility_service_controller.dart';
import 'package:airtouch_ultimate/core/services/foreground_service_controller.dart';
import 'package:airtouch_ultimate/core/services/background_tracking_service.dart';
import 'package:airtouch_ultimate/core/constants/gesture_constants.dart';
import 'package:airtouch_ultimate/core/utils/gesture_classifier.dart';
import 'package:airtouch_ultimate/features/dashboard/dashboard_screen.dart';

/// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.primary900,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Global error handler - prevents crashes
  FlutterError.onError = (details) {
    debugPrint('🔴 Flutter Error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔴 Platform Error: $error');
    return true;
  };

  runApp(const AirTouchUltimateApp());
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// MAIN APP WIDGET WITH LIFECYCLE MANAGEMENT
/// ═══════════════════════════════════════════════════════════════════════════════
class AirTouchUltimateApp extends StatefulWidget {
  const AirTouchUltimateApp({super.key});

  @override
  State<AirTouchUltimateApp> createState() => _AirTouchUltimateAppState();
}

class _AirTouchUltimateAppState extends State<AirTouchUltimateApp> with WidgetsBindingObserver {
  late final AppState _appState;
  late final HandTrackingEngine _engine;
  late final OverlayService _overlay;
  late final ForegroundServiceController _foregroundService;
  late final BackgroundTrackingService _backgroundService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize services
    _appState = AppState();
    _engine = HandTrackingEngine();
    _overlay = OverlayService();
    _foregroundService = ForegroundServiceController.instance;
    _backgroundService = BackgroundTrackingService();
    
    // Connect services
    _appState.setServices(_engine, _overlay, _foregroundService, _backgroundService);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('📱 App paused - Background service keeps tracking alive');
        break;
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed');
        _appState.checkPermissions();
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 App detached');
        _appState.cleanup();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState.cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _appState),
        Provider.value(value: _engine),
        Provider.value(value: _overlay),
        Provider.value(value: _foregroundService),
        Provider.value(value: _backgroundService),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'AirTouch Ultimate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const DashboardScreen(),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// APPLICATION STATE - CRASH-PROOF IMPLEMENTATION
/// ═══════════════════════════════════════════════════════════════════════════════
class AppState extends ChangeNotifier {
  // Permission states
  bool _hasCameraPermission = false;
  bool _hasOverlayPermission = false;
  bool _hasAccessibilityPermission = false;
  bool _permissionsChecked = false;

  // Tracking state
  bool _isTracking = false;
  bool _isInitialized = false;
  bool _isGestureActionsEnabled = true;
  bool _isInitializing = false;

  // Stats
  int _gestureCount = 0;
  String _lastGesture = 'None';
  double _currentFps = 0;
  double _handAngle = 0;

  // Cursor state
  Offset _cursorPosition = Offset.zero;
  CursorState _cursorState = CursorState.normal;

  // Services
  HandTrackingEngine? _engine;
  OverlayService? _overlay;
  ForegroundServiceController? _foregroundService;
  BackgroundTrackingService? _backgroundService;

  // Disposal flag
  bool _disposed = false;

  // Getters
  bool get hasCameraPermission => _hasCameraPermission;
  bool get hasOverlayPermission => _hasOverlayPermission;
  bool get hasAccessibilityPermission => _hasAccessibilityPermission;
  bool get permissionsChecked => _permissionsChecked;
  bool get isTracking => _isTracking;
  bool get isInitialized => _isInitialized;
  bool get isGestureActionsEnabled => _isGestureActionsEnabled;
  bool get isInitializing => _isInitializing;
  int get gestureCount => _gestureCount;
  String get lastGesture => _lastGesture;
  double get currentFps => _currentFps;
  double get handAngle => _handAngle;
  Offset get cursorPosition => _cursorPosition;
  CursorState get cursorState => _cursorState;

  void setServices(
    HandTrackingEngine engine,
    OverlayService overlay,
    ForegroundServiceController foregroundService,
    BackgroundTrackingService backgroundService,
  ) {
    _engine = engine;
    _overlay = overlay;
    _foregroundService = foregroundService;
    _backgroundService = backgroundService;
  }

  /// Check permissions - MUST be called before camera access
  Future<void> checkPermissions() async {
    if (_disposed) return;

    try {
      _hasCameraPermission = await Permission.camera.status.isGranted;
      _hasOverlayPermission = await Permission.systemAlertWindow.status.isGranted;
      _hasAccessibilityPermission = await AccessibilityServiceController.instance.checkServiceEnabled();
      _permissionsChecked = true;
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('Permission check error: $e');
    }
  }

  Future<bool> requestCameraPermission() async {
    if (_disposed) return false;
    try {
      final status = await Permission.camera.request();
      _hasCameraPermission = status.isGranted;
      if (!_disposed) notifyListeners();
      return _hasCameraPermission;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestOverlayPermission() async {
    if (_disposed) return false;
    try {
      final status = await Permission.systemAlertWindow.request();
      _hasOverlayPermission = status.isGranted;
      if (!_disposed) notifyListeners();
      return _hasOverlayPermission;
    } catch (e) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    if (_disposed) return;
    await AccessibilityServiceController.instance.openAccessibilitySettings();
  }

  /// Initialize tracking - CRASH-PROOF
  Future<bool> initializeTracking() async {
    if (_disposed) return false;
    if (_engine == null || _overlay == null || _foregroundService == null) return false;
    if (_isInitialized) return true;
    if (_isInitializing) return false;

    _isInitializing = true;
    if (!_disposed) notifyListeners();

    try {
      // CRITICAL: Check permissions BEFORE camera initialization
      await checkPermissions();

      if (!_hasCameraPermission || !_hasOverlayPermission) {
        _isInitializing = false;
        if (!_disposed) notifyListeners();
        return false;
      }

      // Initialize background service
      try {
        await _backgroundService?.initialize();
        await _backgroundService?.startService();
      } catch (e) {
        debugPrint('Background service error: $e');
      }

      // Initialize tracking engine
      final ok = await _engine!.initialize();
      if (!ok) {
        _isInitializing = false;
        if (!_disposed) notifyListeners();
        return false;
      }

      // Initialize overlay
      await _overlay!.initialize();

      // Start foreground service
      try {
        await _foregroundService!.startService();
      } catch (e) {
        debugPrint('Foreground service error: $e');
      }

      // Get screen size
      final screenSize = await _overlay!.getScreenSize();
      _engine!.setScreenSize(screenSize);

      // Set up callbacks
      _engine!.onCursorPosition = (pos, conf) {
        if (_disposed) return;
        _cursorPosition = pos;
        _overlay?.updateCursorPositionAbsolute(pos.dx, pos.dy);
      };

      _engine!.onGestureDetected = (gesture) {
        if (_disposed || !_isGestureActionsEnabled || gesture == null) return;
        _gestureCount++;
        _lastGesture = gesture.type.name.toUpperCase();
        if (!_disposed) notifyListeners();
        _executeGesture(gesture);
      };

      _engine!.onFpsUpdate = (fps) {
        if (_disposed) return;
        _currentFps = fps;
        if (!_disposed) notifyListeners();
      };

      _engine!.onHandAngle = (angle) {
        if (_disposed) return;
        _handAngle = angle;
        _overlay?.updateCursorRotation(angle);
      };

      _engine!.onError = (error) {
        debugPrint('Engine error: $error');
      };

      try {
        WakelockPlus.enable();
      } catch (_) {}

      _isInitialized = true;
      _isInitializing = false;
      if (!_disposed) notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Init error: $e');
      _isInitializing = false;
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  Future<bool> startTracking() async {
    if (_disposed) return false;
    if (_engine == null || _overlay == null) return false;
    if (_isTracking) return true;

    try {
      final screenSize = await _overlay!.getScreenSize();
      await _overlay!.showCursor(
        initialPosition: Offset(screenSize.width / 2, screenSize.height / 2),
      );

      final started = await _engine!.startTracking();
      if (started) {
        _isTracking = true;
        if (!_disposed) notifyListeners();
      }
      return started;
    } catch (e) {
      return false;
    }
  }

  Future<void> stopTracking() async {
    if (_disposed) return;
    if (_engine == null || _overlay == null) return;
    if (!_isTracking) return;

    try {
      await _engine!.stopTracking();
      await _overlay!.hideCursor();
      _isTracking = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('Stop error: $e');
    }
  }

  Future<void> toggleTracking() async {
    if (_disposed) return;
    if (_engine == null || _overlay == null || _foregroundService == null) return;

    if (_isTracking) {
      await stopTracking();
    } else {
      await checkPermissions();
      if (!_hasCameraPermission || !_hasOverlayPermission) return;

      if (!_isInitialized) {
        final ok = await initializeTracking();
        if (!ok) return;
      }

      await startTracking();
    }
  }

  void _executeGesture(GestureEvent gesture) {
    if (_disposed || _overlay == null) return;
    
    final accessibility = AccessibilityServiceController.instance;

    switch (gesture.type) {
      case GestureType.click:
        _overlay!.updateCursorState(CursorState.clicking);
        accessibility.performTap(_cursorPosition.dx, _cursorPosition.dy);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!_disposed) _overlay?.updateCursorState(CursorState.normal);
        });
        break;

      case GestureType.back:
        accessibility.performBack();
        break;

      case GestureType.recents:
        accessibility.openRecents();
        break;

      case GestureType.scroll:
        if (gesture.swipeDirection != null) {
          final direction = gesture.swipeDirection!.name; // Convert enum to string
          accessibility.performScroll(direction, gesture.swipeDistance ?? 300);
        }
        break;

      case GestureType.drag:
        _overlay!.updateCursorState(gesture.isFistClosed ? CursorState.dragging : CursorState.normal);
        break;

      case GestureType.none:
        break;
    }
  }

  void toggleGestureActions() {
    if (_disposed) return;
    _isGestureActionsEnabled = !_isGestureActionsEnabled;
    if (!_disposed) notifyListeners();
  }

  void resetStats() {
    if (_disposed) return;
    _gestureCount = 0;
    _lastGesture = 'None';
    if (!_disposed) notifyListeners();
  }

  Future<void> cleanup() async {
    if (_disposed) return;
    _disposed = true;

    try {
      await stopTracking();
      await _engine?.dispose();
      _overlay?.dispose();
      await _foregroundService?.stopService();
      await _backgroundService?.stopService();
      WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}
