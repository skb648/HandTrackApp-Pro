import 'package:flutter/material.dart';
import 'package:airtouch_ultimate/core/constants/app_theme.dart';

/// Gesture definitions and constants for AirTouch Ultimate
class GestureConstants {
  GestureConstants._();

  // ═══════════════════════════════════════════════════════════════
  // DETECTION THRESHOLDS
  // ═══════════════════════════════════════════════════════════════

  /// Pinch detection threshold (normalized distance: 0-1)
  /// Lower = more sensitive, Higher = less sensitive
  static const double pinchThreshold = 0.05;
  
  /// Pinch threshold for drag gesture (slightly more relaxed)
  static const double dragPinchThreshold = 0.08;

  /// Minimum folded fingers for fist detection
  static const int fistMinFoldedFingers = 3;

  /// Minimum extended fingers for open palm detection
  static const int openPalmMinExtendedFingers = 4;

  /// Swipe velocity threshold (pixels per second)
  static const double swipeVelocityThreshold = 150.0;

  /// Swipe distance threshold (normalized)
  static const double swipeDistanceThreshold = 0.1;

  /// Gesture hold duration (milliseconds)
  static const int gestureHoldDuration = 200;

  /// Double gesture cooldown (milliseconds)
  static const int gestureCooldown = 500;

  // ═══════════════════════════════════════════════════════════════
  // EMA SMOOTHING PARAMETERS
  // ═══════════════════════════════════════════════════════════════

  /// Default EMA alpha for cursor smoothing
  /// Range: 0.0 - 1.0 (Lower = smoother, Higher = more responsive)
  static const double emaAlphaDefault = 0.25;
  
  /// Responsive EMA alpha (faster cursor, more jitter)
  static const double emaAlphaResponsive = 0.4;
  
  /// Smooth EMA alpha (slower cursor, less jitter)
  static const double emaAlphaSmooth = 0.15;

  /// EMA alpha for landmark smoothing
  static const double emaAlphaLandmark = 0.3;

  // ═══════════════════════════════════════════════════════════════
  // HAND TRACKING PARAMETERS
  // ═══════════════════════════════════════════════════════════════

  /// Target FPS for hand tracking
  static const int targetFPS = 30;

  /// Minimum hand detection confidence
  static const double minHandConfidence = 0.5;

  /// Minimum hand presence confidence
  static const double minHandPresence = 0.5;

  /// Minimum tracking confidence
  static const double minTrackingConfidence = 0.5;

  /// Camera frame width for processing
  static const int cameraFrameWidth = 640;

  /// Camera frame height for processing
  static const int cameraFrameHeight = 480;

  // ═══════════════════════════════════════════════════════════════
  // CURSOR PARAMETERS
  // ═══════════════════════════════════════════════════════════════

  /// Cursor size in pixels
  static const double cursorSize = 32.0;

  /// Cursor click animation duration (ms)
  static const int cursorClickDuration = 150;

  /// Cursor trail length
  static const int cursorTrailLength = 5;

  /// Haptic feedback enabled by default
  static const bool hapticFeedbackEnabled = true;
}

/// Enum representing all gesture types
enum GestureType {
  click(
    name: 'Click / Tap',
    badge: 'Index + Thumb Pinch',
    icon: '👆',
    color: AppTheme.gestureClick,
    description: 'Bring your index fingertip and thumb tip together to perform a tap at the cursor location.',
  ),
  back(
    name: 'Go Back',
    badge: 'Middle + Thumb Pinch',
    icon: '↩️',
    color: AppTheme.gestureBack,
    description: 'Pinch your middle fingertip and thumb together to trigger the Android Back action.',
  ),
  recents(
    name: 'Recent Apps',
    badge: 'Ring + Thumb Pinch',
    icon: '🗂️',
    color: AppTheme.gestureRecents,
    description: 'Pinch your ring fingertip and thumb together to open the Android Recent Apps overview.',
  ),
  scroll(
    name: 'Scroll / Swipe',
    badge: 'Flat Palm Swipe',
    icon: '✋',
    color: AppTheme.gestureScroll,
    description: 'With your hand open and flat, swipe Up, Down, Left, or Right to scroll the current page.',
  ),
  drag(
    name: 'Drag & Drop',
    badge: 'Fist → Move → Open',
    icon: '✊',
    color: AppTheme.gestureDrag,
    description: 'Close your hand into a fist to grab, move to drag the item, then open your hand to drop.',
  ),
  none(
    name: 'None',
    badge: '',
    icon: '',
    color: AppTheme.textMuted,
    description: '',
  );

  final String name;
  final String badge;
  final String icon;
  final Color color;
  final String description;

  const GestureType({
    required this.name,
    required this.badge,
    required this.icon,
    required this.color,
    required this.description,
  });
}

/// Hand landmark indices (MediaPipe format - 21 landmarks)
enum HandLandmark {
  wrist(0),
  thumbCmc(1),
  thumbMcp(2),
  thumbIp(3),
  thumbTip(4),
  indexMcp(5),
  indexPip(6),
  indexDip(7),
  indexTip(8),
  middleMcp(9),
  middlePip(10),
  middleDip(11),
  middleTip(12),
  ringMcp(13),
  ringPip(14),
  ringDip(15),
  ringTip(16),
  pinkyMcp(17),
  pinkyPip(18),
  pinkyDip(19),
  pinkyTip(20);

  final int landmarkIndex;
  const HandLandmark(this.landmarkIndex);

  static HandLandmark fromIndex(int idx) {
    return HandLandmark.values.firstWhere(
      (e) => e.landmarkIndex == idx,
      orElse: () => HandLandmark.wrist,
    );
  }
}

/// Gesture mapping for quick reference display
class GestureMapping {
  final String gesture;
  final String action;
  final GestureType type;

  const GestureMapping({
    required this.gesture,
    required this.action,
    required this.type,
  });
}

/// Predefined gesture mappings
class GestureMappings {
  GestureMappings._();

  static const List<GestureMapping> all = [
    GestureMapping(
      gesture: 'Index + Thumb Pinch',
      action: 'Click / Tap',
      type: GestureType.click,
    ),
    GestureMapping(
      gesture: 'Middle + Thumb Pinch',
      action: 'Go Back',
      type: GestureType.back,
    ),
    GestureMapping(
      gesture: 'Ring + Thumb Pinch',
      action: 'Recent Apps',
      type: GestureType.recents,
    ),
    GestureMapping(
      gesture: 'Flat Palm Swipe',
      action: 'Scroll / Swipe',
      type: GestureType.scroll,
    ),
    GestureMapping(
      gesture: 'Fist → Move → Open',
      action: 'Drag & Drop',
      type: GestureType.drag,
    ),
  ];
}

/// Tutorial data for gesture guide
class GestureTutorialData {
  final String icon;
  final Color color;
  final String name;
  final String badge;
  final String description;
  final List<String> steps;
  final String proTip;

  const GestureTutorialData({
    required this.icon,
    required this.color,
    required this.name,
    required this.badge,
    required this.description,
    required this.steps,
    required this.proTip,
  });
}

/// Predefined gesture tutorial data
class GestureTutorials {
  GestureTutorials._();

  static const List<GestureTutorialData> all = [
    GestureTutorialData(
      icon: '👆',
      color: AppTheme.gestureClick,
      name: 'Click / Tap',
      badge: 'Index + Thumb Pinch',
      description: 'Bring your index fingertip and thumb tip together to perform a tap at the cursor location.',
      steps: [
        'Extend your index finger forward',
        'Hold thumb out to the side',
        'Pinch index finger + thumb together',
        'Release — the tap action fires',
      ],
      proTip: 'A quick pinch-release works best. Hold too long and it might register as a long-press.',
    ),
    GestureTutorialData(
      icon: '↩️',
      color: AppTheme.gestureBack,
      name: 'Go Back',
      badge: 'Middle + Thumb Pinch',
      description: 'Pinch your middle fingertip and thumb together to trigger the Android Back action.',
      steps: [
        'Extend your middle finger forward',
        'Hold thumb out to the side',
        'Pinch middle finger + thumb together',
        'Release — the Back action fires',
      ],
      proTip: 'The middle finger is taller — make sure you\'re not accidentally using the index.',
    ),
    GestureTutorialData(
      icon: '🗂️',
      color: AppTheme.gestureRecents,
      name: 'Recent Apps',
      badge: 'Ring + Thumb Pinch',
      description: 'Pinch your ring fingertip and thumb together to open the Android Recent Apps overview.',
      steps: [
        'Extend your ring finger forward',
        'Keep other fingers relaxed',
        'Pinch ring finger + thumb tip',
        'Hold briefly for Recents to open',
      ],
      proTip: 'The ring finger is naturally shorter — practice for accuracy.',
    ),
    GestureTutorialData(
      icon: '✋',
      color: AppTheme.gestureScroll,
      name: 'Scroll / Swipe',
      badge: 'Flat Palm Swipe',
      description: 'With your hand open and flat, swipe Up, Down, Left, or Right to scroll the current page.',
      steps: [
        'Open your hand flat (all fingers extended)',
        'Move your entire hand in one direction:',
        '⬆️ Up = scroll up  ⬇️ Down = scroll down',
        '⬅️ Left = swipe left  ➡️ Right = swipe right',
      ],
      proTip: 'Keep all fingers extended. A closed fist triggers Drag instead of Scroll.',
    ),
    GestureTutorialData(
      icon: '✊',
      color: AppTheme.gestureDrag,
      name: 'Drag & Drop',
      badge: 'Fist → Move → Open',
      description: 'Close your hand into a fist to grab, move to drag the item, then open your hand to drop.',
      steps: [
        'Move cursor over the item to drag',
        'Close hand into a tight fist (grab)',
        'Move your fist to the target location',
        'Open your hand to release (drop)',
      ],
      proTip: 'Closing at least 3 fingers counts as a fist. Make sure to open fully to drop.',
    ),
  ];
}

/// Cursor states for visual feedback
enum CursorState {
  normal,
  clicking,
  dragging,
  disabled,
}

/// Swipe directions
enum SwipeDirection {
  up,
  down,
  left,
  right,
}
