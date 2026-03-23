import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:airtouch_ultimate/core/constants/app_theme.dart';
import 'package:airtouch_ultimate/core/constants/app_typography.dart';
import 'package:airtouch_ultimate/core/constants/gesture_constants.dart';
import 'package:airtouch_ultimate/core/services/hand_tracking_engine.dart';
import 'package:airtouch_ultimate/core/services/overlay_service.dart';
import 'package:airtouch_ultimate/core/services/accessibility_service_controller.dart';
import 'package:airtouch_ultimate/core/services/foreground_service_controller.dart';
import 'package:airtouch_ultimate/core/services/background_tracking_service.dart';
import 'package:airtouch_ultimate/main.dart';
import 'package:airtouch_ultimate/features/gesture_guide/gesture_guide_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    
    try {
      final appState = context.read<AppState>();
      await appState.checkPermissions();
    } catch (e) {
      debugPrint('Init error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().checkPermissions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleStart() async {
    final appState = context.read<AppState>();

    await appState.checkPermissions();

    if (!appState.hasCameraPermission) {
      _showPermDialog('Camera Permission', 'Camera is needed to track your hand.', () async {
        final ok = await appState.requestCameraPermission();
        if (ok && mounted) { Navigator.pop(context); _handleStart(); }
      });
      return;
    }

    if (!appState.hasOverlayPermission) {
      _showPermDialog('Overlay Permission', 'Overlay is needed to show the cursor.', () async {
        final ok = await appState.requestOverlayPermission();
        if (ok && mounted) { Navigator.pop(context); _handleStart(); }
      });
      return;
    }

    if (!appState.hasAccessibilityPermission) {
      _showA11yDialog();
      return;
    }

    await appState.toggleTracking();
  }

  void _showPermDialog(String title, String msg, VoidCallback onAction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primary800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: AppTypography.cardTitle),
        content: Text(msg, style: AppTypography.bodySmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Grant'),
          ),
        ],
      ),
    );
  }

  void _showA11yDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primary800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [Icon(Icons.accessibility_new, color: AppTheme.accent), const SizedBox(width: 12), Text('Accessibility', style: AppTypography.cardTitle)]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AirTouch needs Accessibility to perform gestures.', style: AppTypography.bodySmall),
            const SizedBox(height: 12),
            _step('1', 'Tap "Open Settings"'),
            _step('2', 'Find "AirTouch Ultimate"'),
            _step('3', 'Toggle it ON'),
            _step('4', 'Return here'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().openAccessibilitySettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _step(String n, String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.2), shape: BoxShape.circle), child: Center(child: Text(n, style: AppTypography.caption.copyWith(color: AppTheme.accent)))),
      const SizedBox(width: 12),
      Expanded(child: Text(t, style: AppTypography.bodySmall)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Consumer<AppState>(
            builder: (ctx, state, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _header(state),
                  const SizedBox(height: 24),
                  _permCard(state),
                  const SizedBox(height: 16),
                  _controlCard(state),
                  const SizedBox(height: 16),
                  _statsCard(state),
                  const SizedBox(height: 16),
                  _featureGrid(ctx),
                  const SizedBox(height: 16),
                  _gestureRef(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppState s) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('✋', style: AppTypography.emojiIconSmall))),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AirTouch', style: AppTypography.heading1),
          Text('Air Gesture Controller', style: AppTypography.caption.copyWith(color: AppTheme.textMuted)),
        ]),
      ]),
      _statusBadge(s),
    ],
  );

  Widget _statusBadge(AppState s) {
    final color = s.isTracking ? AppTheme.neonGreen : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(s.isTracking ? 'Active • ${s.currentFps.toStringAsFixed(0)} FPS' : 'Inactive', style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _permCard(AppState s) {
    final all = s.hasCameraPermission && s.hasOverlayPermission && s.hasAccessibilityPermission;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: all ? AppTheme.neonGreen.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: all ? AppTheme.neonGreen.withOpacity(0.3) : AppTheme.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(all ? Icons.check_circle : Icons.warning_amber, color: all ? AppTheme.neonGreen : AppTheme.warning, size: 20),
            const SizedBox(width: 8),
            Text(all ? 'All Permissions Granted' : 'Permissions Required', style: AppTypography.bodyMedium.copyWith(color: all ? AppTheme.neonGreen : AppTheme.warning, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          _permRow('Camera', s.hasCameraPermission, AppTheme.neonGreen),
          _permRow('Overlay', s.hasOverlayPermission, AppTheme.accent),
          _permRow('Accessibility', s.hasAccessibilityPermission, AppTheme.gestureClick),
        ],
      ),
    );
  }

  Widget _permRow(String n, bool g, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(g ? Icons.check_circle_outline : Icons.circle_outlined, color: g ? c : AppTheme.textMuted, size: 16),
      const SizedBox(width: 8),
      Text(n, style: AppTypography.bodySmall),
      const Spacer(),
      Text(g ? 'Granted' : 'Required', style: AppTypography.captionSmall.copyWith(color: g ? c : AppTheme.textMuted)),
    ]),
  );

  Widget _controlCard(AppState s) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppTheme.primary800, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: AppTheme.neonGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.mouse, color: AppTheme.neonGreen, size: 18)),
          const SizedBox(width: 12),
          Text('Cursor Control', style: AppTypography.cardTitle),
        ]),
        const SizedBox(height: 8),
        Text('Mouse pointer cursor with EMA smoothing. Follows your index finger in real-time.', style: AppTypography.bodySmall),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: s.isInitializing ? null : _handleStart,
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(color: s.isTracking ? AppTheme.error : AppTheme.neonGreen, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: s.isInitializing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s.isTracking ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(s.isTracking ? '⏹ Stop Cursor' : '▶ Start Cursor', style: AppTypography.button),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gesture Actions', style: AppTypography.bodyMedium),
            Switch(value: s.isGestureActionsEnabled, onChanged: (_) => s.toggleGestureActions(), activeColor: AppTheme.accent),
          ],
        ),
      ],
    ),
  );

  Widget _statsCard(AppState s) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppTheme.primary800, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.bar_chart_rounded, color: AppTheme.accent, size: 18)),
          const SizedBox(width: 12),
          Text('Live Stats', style: AppTypography.cardTitle),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(children: [Text(s.gestureCount.toString(), style: AppTypography.statValue.copyWith(color: AppTheme.gestureClick)), const SizedBox(height: 4), Text('GESTURES', style: AppTypography.captionSmall)])),
          Container(width: 1, height: 40, color: AppTheme.glassBorder),
          Expanded(child: Column(children: [Text(s.lastGesture, style: AppTypography.statValue.copyWith(color: AppTheme.gestureBack)), const SizedBox(height: 4), Text('LAST ACTION', style: AppTypography.captionSmall)])),
          Container(width: 1, height: 40, color: AppTheme.glassBorder),
          Expanded(child: Column(children: [Text(s.currentFps.toStringAsFixed(1), style: AppTypography.statValue.copyWith(color: AppTheme.gestureScroll)), const SizedBox(height: 4), Text('FPS', style: AppTypography.captionSmall)])),
        ]),
      ],
    ),
  );

  Widget _featureGrid(BuildContext ctx) => Row(children: [
    Expanded(child: _FeatureCard(icon: '⌨️', title: 'Air Keyboard', desc: 'Floating keyboard', badge: 'Laser', color: AppTheme.gestureClick, onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const GestureGuideScreen())))),
    const SizedBox(width: 12),
    Expanded(child: _FeatureCard(icon: '📖', title: 'Gesture Guide', desc: 'Learn gestures', badge: '5 gestures', color: AppTheme.gestureRecents, onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const GestureGuideScreen())))),
  ]);

  Widget _gestureRef() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppTheme.primary800, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: AppTheme.gestureScroll.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.back_hand_rounded, color: AppTheme.gestureScroll, size: 18)),
          const SizedBox(width: 12),
          Text('Quick Reference', style: AppTypography.cardTitle),
        ]),
        const SizedBox(height: 12),
        ...GestureMappings.all.map((g) => Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.glassBorderColor))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: g.type.color, shape: BoxShape.circle)), const SizedBox(width: 12), Text(g.gesture, style: AppTypography.bodySmall)]),
            Text('→ ${g.action}', style: AppTypography.bodyMedium.copyWith(color: g.type.color, fontWeight: FontWeight.w600)),
          ]),
        )),
      ],
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;
  final String badge;
  final Color color;
  final VoidCallback? onTap;

  const _FeatureCard({required this.icon, required this.title, required this.desc, required this.badge, required this.color, this.onTap});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: AppTypography.emojiIconSmall),
        const SizedBox(height: 8),
        Text(title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(desc, style: AppTypography.captionSmall),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.25), borderRadius: BorderRadius.circular(8)), child: Text(badge, style: AppTypography.badge.copyWith(color: color))),
      ]),
    ),
  );
}
