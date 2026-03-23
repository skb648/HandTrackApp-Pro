import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vibration/vibration.dart';

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
  static const _methodChannel = MethodChannel('com.airtouch.ultimate/control');
  static const _eventChannel = EventChannel('com.airtouch.ultimate/events');
  
  bool _isTracking = false;
  bool _isInitializing = false;
  bool _hasPermissions = false;
  
  double _cursorX = 0.5;
  double _cursorY = 0.5;
  String _gesture = 'none';
  double _fps = 0;
  
  StreamSubscription<dynamic>? _eventSubscription;
  EventChannel.EventSink? _eventSink;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    WakelockPlus.enable();
    _listenToEvents();
  }
  
  void _listenToEvents() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final type = event['type'];
        if (type == 'position') {
          setState(() {
            _cursorX = (event['x'] as num?)?.toDouble() ?? 0.5;
            _cursorY = (event['y'] as num?)?.toDouble() ?? 1.5;
          });
        } else if (type == 'gesture') {
          setState(() {
            _gesture = event['gesture'] as String? ?? 'none';
          });
        }
      }
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }
  
  Future<void> _checkPermissions() async {
    try {
      final cameraStatus = await Permission.camera.status;
      
      bool canDrawOverlays = false;
      try {
        canDrawOverlays = await _methodChannel.invokeMethod('canDrawOverlays') ?? false;
      } catch (e) {
        debugPrint('Overlay check error: $e');
      }
      
      bool hasAccessibility = false;
      try {
        hasAccessibility = await _methodChannel.invokeMethod('isAccessibilityEnabled') ?? false;
      } catch (e) {
        debugPrint('Accessibility check error: $e');
      }
      
      if (mounted) {
        setState(() {
          _hasPermissions = cameraStatus.isGranted && canDrawOverlays && hasAccessibility;
        });
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
    }
  }
  
  Future<void> _startTracking() async {
    if (_isTracking || _isInitializing) return;
    
    setState(() => _isInitializing = true);
    
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _showError('Camera permission required');
        setState(() => _isInitializing = false);
        return;
      }
      
      // Check overlay permission
      bool canDraw = await _methodChannel.invokeMethod('canDrawOverlays') ?? false;
      if (!canDraw) {
        await _methodChannel.invokeMethod('requestOverlayPermission');
        await Future.delayed(const Duration(milliseconds: 500));
        canDraw = await _methodChannel.invokeMethod('canDrawOverlays') ?? false;
        if (!canDraw) {
          _showError('Overlay permission required for cursor');
          setState(() => _isInitializing = false);
          return;
        }
      }
      
      // Check accessibility
      bool hasAccess = await _methodChannel.invokeMethod('isAccessibilityEnabled') ?? false;
      if (!hasAccess) {
        await _methodChannel.invokeMethod('openAccessibilitySettings');
        _showError('Please enable AirTouch Accessibility Service');
        setState(() => _isInitializing = false);
        return;
      }
      
      // Start native tracking service
      final result = await _methodChannel.invokeMethod('startTracking');
      
      if (result == true) {
        setState(() {
          _isTracking = true;
          _isInitializing = false;
        });
        _vibrate();
      } else {
        _showError('Failed to start tracking');
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      _showError('Error: $e');
      setState(() => _isInitializing = false);
    }
  }
  
  Future<void> _stopTracking() async {
    if (!_isTracking) return;
    
    try {
      await _methodChannel.invokeMethod('stopTracking');
      setState(() => _isTracking = false);
      _vibrate();
    } catch (e) {
      _showError('Error stopping: $e');
    }
  }
  
  void _vibrate() {
    try {
      Vibration.vibrate(duration: 50);
    } catch (e) {}
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  @override
  void dispose() {
    if (_isTracking) _stopTracking();
    _eventSubscription?.cancel();
    try { WakelockPlus.disable(); } catch (e) {}
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF0a0A1A)],
          ),
        ),
        child: SafeArea(
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/icon/ic_launcher.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF6C63FF),
                  child: const Icon(Icons.back_hand, color: Colors.white),
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
                Text('Hand Gesture Controller v5.1', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_isTracking ? Colors.green : Colors.grey).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isTracking ? 'ACTIVE' : 'STOPPED',
              style: TextStyle(
                color: _isTracking ? Colors.green : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.touch_app, size: 70, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 32),
            const Text('Ready to Control', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Text(
              'Tap START to begin hand tracking.\n'
              'Move your index finger to control cursor.\n'
              'Pinch thumb & index to click.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400, height: 1.5),
            ),
            const SizedBox(height: 24),
            _buildPermissionStatus(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPermissionStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildPermRow('Camera', _hasPermissions),
          const SizedBox(height: 8),
          _buildPermRow('Overlay', _hasPermissions),
          const SizedBox(height: 8),
          _buildPermRow('Accessibility', _hasPermissions),
        ],
      ),
    );
  }
  
  Widget _buildPermRow(String name, bool granted) {
    return Row(
      children: [
        Icon(granted ? Icons.check_circle : Icons.circle_outlined, color: granted ? Colors.green : Colors.grey, size: 20),
        const SizedBox(width: 8),
        Text(name, style: TextStyle(color: granted ? Colors.white : Colors.grey, fontSize: 14)),
      ],
    );
  }
  
  Widget _buildTrackingView() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Stats
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FPS: ${_fps.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Gesture: ${_gesture.toUpperCase()}', style: TextStyle(color: _gesture == 'pinch' ? Colors.green : Colors.white, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('X: ${(_cursorX * 100).toStringAsFixed(0)}%  Y: ${(_cursorY * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          ),
          
          // Center indicator
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                  ),
                  child: const Icon(Icons.back_hand, size: 50, color: Color(0xFF6C63FF)),
                ),
                const SizedBox(height: 16),
                const Text('Tracking Active', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Camera running in background\nMove your hand to control cursor', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                Icon(_isTracking ? Icons.stop : Icons.play_arrow, size: 24),
              const SizedBox(width: 8),
              Text(_isInitializing ? 'STARTING...' : (_isTracking ? 'STOP TRACKING' : 'START TRACKING'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
