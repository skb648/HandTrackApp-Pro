# AirTouch Ultimate - Full-Scale Android System-Controller

<div align="center">
  <img src="docs/banner.png" alt="AirTouch Ultimate Banner" width="100%">
  
  **Control your entire Android OS using front-camera hand gestures**
  
  [![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
  [![Platform](https://img.shields.io/badge/Platform-Android-green.svg)](https://www.android.com)
  [![API](https://img.shields.io/badge/API-24%2B-brightgreen.svg)](https://android-arsenal.com/api?level=24)
</div>

---

## 🎯 Overview

AirTouch Ultimate is a production-grade Android system-utility application that enables complete device control through air hand gestures detected via the front camera. The app uses **MediaPipe/TensorFlow Lite** for real-time 21-point hand landmark detection with **EMA smoothing** for jitter-free cursor control.

### Key Features

- ✋ **5 Gesture Types**: Click, Back, Recents, Scroll, Drag & Drop
- 🎯 **EMA Smoothing**: Exponential Moving Average for smooth cursor movement
- 🔮 **Glassmorphism UI**: Modern dark theme with Deep Blue/Indigo palette
- ⌨️ **Dual Keyboard Modes**: Mobile (Laser) and Tablet (Spatial Zone)
- 🔔 **Foreground Service**: Persistent notification to prevent OS killing
- ♿ **Accessibility Service**: Native gesture dispatch for system-level control

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter UI Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────────┐ │
│  │  Dashboard  │  │  Gesture   │  │     Air Keyboard            │ │
│  │  (Command)  │  │   Guide    │  │  (Mobile/Tablet modes)      │ │
│  └──────┬──────┘  └──────┬──────┘  └─────────────┬───────────────┘ │
└─────────┼────────────────┼─────────────────────────┼─────────────────┘
          │                │                         │
          ▼                ▼                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Dart Service Layer                             │
│  ┌─────────────────────┐  ┌───────────────────────────────────────┐│
│  │ HandTrackingEngine  │  │ AccessibilityServiceController       ││
│  │ (MediaPipe/TFLite)  │  │ (Gesture Dispatch)                   ││
│  └──────────┬──────────┘  └──────────────────┬────────────────────┘│
│             │                               │                       │
│  ┌──────────▼──────────┐  ┌──────────────────▼────────────────────┐│
│  │   OverlayService    │  │ ForegroundServiceController          ││
│  │ (Cursor/Keyboard)   │  │ (Background Persistence)             ││
│  └─────────────────────┘  └──────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                              │ Platform Channels
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Native Android Layer (Kotlin)                   │
│  ┌─────────────────────┐  ┌───────────────────────────────────────┐│
│  │ HandTrackingManager │  │ AirTouchAccessibilityService         ││
│  │ (TFLite GPU/CPU)    │  │ (GestureDescription dispatchGesture) ││
│  └─────────────────────┘  └───────────────────────────────────────┘│
│  ┌─────────────────────┐  ┌───────────────────────────────────────┐│
│  │   OverlayManager    │  │ HandTrackingForegroundService        ││
│  │ (WindowManager)     │  │ (Persistent Notification)            ││
│  └─────────────────────┘  └───────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
airtouch_ultimate/
├── lib/
│   ├── main.dart                              # App entry point
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_theme.dart                 # Deep Blue/Indigo theme
│   │   │   ├── app_typography.dart            # Inter font system
│   │   │   └── gesture_constants.dart         # Gesture definitions
│   │   ├── services/
│   │   │   ├── hand_tracking_engine.dart      # MediaPipe integration
│   │   │   ├── overlay_service.dart           # Flutter overlay control
│   │   │   ├── accessibility_service_controller.dart
│   │   │   └── foreground_service_controller.dart
│   │   └── utils/
│   │       ├── ema_smoothing.dart             # EMA + OneEuro filter
│   │       └── gesture_classifier.dart        # Gesture classification
│   ├── features/
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart          # Main command center
│   │   ├── gesture_guide/
│   │   │   └── gesture_guide_screen.dart      # 5-step horizontal pager
│   │   └── air_keyboard/
│   │       └── air_keyboard_screen.dart       # Dual-mode keyboard
│   └── shared/
│       └── widgets/
├── android/app/src/main/
│   ├── AndroidManifest.xml                   # All permissions declared
│   ├── kotlin/com/airtouch/ultimate/
│   │   ├── MainActivity.kt                   # Platform channel handlers
│   │   ├── gesture/
│   │   │   ├── AirTouchAccessibilityService.kt
│   │   │   └── GestureExecutor.kt
│   │   ├── overlay/
│   │   │   └── OverlayManager.kt             # Cursor/keyboard overlay
│   │   ├── handtracking/
│   │   │   └── HandTrackingManager.kt        # TFLite model inference
│   │   └── services/
│   │       └── HandTrackingForegroundService.kt
│   └── res/
│       ├── xml/accessibility_service_config.xml
│       └── values/strings.xml
├── assets/
│   ├── fonts/Inter-*.ttf                     # Inter font family
│   └── models/hand_landmark.tflite           # MediaPipe hand model
└── pubspec.yaml
```

---

## 🖐️ Gesture Reference

| Gesture | Icon | Badge | Action |
|---------|------|-------|--------|
| **Index + Thumb Pinch** | 👆 | Click / Tap | Tap at cursor location |
| **Middle + Thumb Pinch** | ↩️ | Go Back | Android Back action |
| **Ring + Thumb Pinch** | 🗂️ | Recent Apps | Open Recents overview |
| **Flat Palm Swipe** | ✋ | Scroll / Swipe | Scroll in any direction |
| **Fist → Move → Open** | ✊ | Drag & Drop | Grab, move, release |

---

## 🔧 Technical Implementation

### EMA Smoothing Algorithm

```dart
// Exponential Moving Average for jitter reduction
smoothed = α × raw + (1 - α) × previous_smoothed

// Alpha values:
// 0.15 - Smooth (less jitter, more lag)
// 0.25 - Default (balanced)
// 0.40 - Responsive (more jitter, less lag)
```

### MediaPipe Hand Landmarks

The app tracks 21 hand landmarks:
- **0**: Wrist
- **1-4**: Thumb (CMC, MCP, IP, Tip)
- **5-8**: Index finger (MCP, PIP, DIP, Tip)
- **9-12**: Middle finger (MCP, PIP, DIP, Tip)
- **13-16**: Ring finger (MCP, PIP, DIP, Tip)
- **17-20**: Pinky (MCP, PIP, DIP, Tip)

### Accessibility Service Gestures

```kotlin
// Native gesture dispatch via AccessibilityService
val path = Path().apply { moveTo(x, y) }
val gesture = GestureDescription.Builder()
    .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
    .build()
service.dispatchGesture(gesture, null, null)
```

---

## 📋 Requirements

### Device Requirements
- **Android 7.0+ (API 24+)**
- **Front camera** (required for hand tracking)
- **2GB+ RAM** (recommended for smooth TFLite inference)

### Permissions Required
| Permission | Purpose |
|------------|---------|
| `CAMERA` | Hand tracking via front camera |
| `SYSTEM_ALERT_WINDOW` | Floating cursor overlay |
| `BIND_ACCESSIBILITY_SERVICE` | System gesture dispatch |
| `FOREGROUND_SERVICE` | Background tracking |
| `FOREGROUND_SERVICE_CAMERA` | Camera in foreground |
| `VIBRATE` | Haptic feedback |

---

## 🚀 Getting Started

### Prerequisites
1. Flutter SDK 3.16+ / Dart 3.2+
2. Android Studio Hedgehog or later
3. Android SDK 34
4. Kotlin 1.9+

### Installation

```bash
# Clone the repository
git clone https://github.com/your-repo/airtouch-ultimate.git
cd airtouch-ultimate

# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

### Post-Install Setup

1. **Grant Camera Permission** - Required for hand tracking
2. **Enable Overlay Permission** - Settings > Apps > AirTouch > Display over other apps
3. **Enable Accessibility Service** - Settings > Accessibility > AirTouch Ultimate

---

## 🎨 Design System

### Color Palette (Deep Blue/Indigo Theme)

| Name | Hex | Usage |
|------|-----|-------|
| Primary 900 | `#0A0E21` | Background |
| Primary 800 | `#0F1629` | Card backgrounds |
| Accent | `#6366F1` | Buttons, highlights |
| Neon Green | `#00FF88` | Cursor, status active |
| Gesture Click | `#6366F1` | Click/Tap gesture |
| Gesture Back | `#F97316` | Back gesture |
| Gesture Recents | `#8B5CF6` | Recents gesture |
| Gesture Scroll | `#10B981` | Scroll gesture |
| Gesture Drag | `#06B6D4` | Drag gesture |

### Typography (Inter)

| Style | Size | Weight |
|-------|------|--------|
| Display Large | 36sp | Black (900) |
| Heading 1 | 24sp | ExtraBold (800) |
| Heading 2 | 20sp | Bold (700) |
| Body Medium | 14sp | Regular (400) |
| Caption | 11sp | Medium (500) |
| Badge | 9sp | SemiBold (600) |

---

## 🔌 Platform Channels

### Hand Tracking Channel
```dart
// Method Channel: com.airtouch.ultimate/hand_tracking
// Event Channel: com.airtouch.ultimate/hand_tracking_stream

Methods:
- initialize() → bool
- startTracking() → bool
- stopTracking() → void

Events:
- landmarks: List<List<double>>  // 21 points × 3D coords
- handedness: String  // "left" | "right"
- confidence: double
```

### Overlay Channel
```dart
// Method Channel: com.airtouch.ultimate/overlay

Methods:
- hasOverlayPermission() → bool
- requestOverlayPermission() → bool
- showCursor({x, y}) → bool
- hideCursor() → bool
- updateCursorPosition(x, y) → bool
- updateCursorState(state) → bool
- showKeyboard(mode) → bool
- hideKeyboard() → bool
```

### Accessibility Channel
```dart
// Method Channel: com.airtouch.ultimate/accessibility

Methods:
- isServiceEnabled() → bool
- performTap(x, y) → bool
- performDoubleTap(x, y) → bool
- performLongPress(x, y, duration) → bool
- performSwipe(startX, startY, endX, endY, duration) → bool
- performScroll(direction, distance) → bool
- performGlobalAction(action) → bool  // "back", "home", "recents"
```

---

## 📱 Screenshots

| Dashboard | Gesture Guide | Air Keyboard |
|-----------|---------------|--------------|
| ![Dashboard](docs/dashboard.png) | ![Guide](docs/guide.png) | ![Keyboard](docs/keyboard.png) |

---

## 🧪 Testing

### UI Testing
```bash
flutter test test/widget_test.dart
```

### Integration Testing
```bash
flutter test integration_test/app_test.dart
```

### Performance Benchmarks
- Hand tracking: 30+ FPS on mid-range devices
- Gesture latency: < 100ms
- Memory usage: ~150MB
- APK size: ~60MB (with TFLite model)

---

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting PRs.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [MediaPipe](https://mediapipe.dev/) - Hand tracking model
- [TensorFlow Lite](https://www.tensorflow.org/lite) - On-device ML inference
- [Flutter](https://flutter.dev/) - Cross-platform UI framework
- [Inter Font](https://rsms.me/inter/) - Beautiful typeface

---

<div align="center">
  <strong>AirTouch Ultimate</strong> - Control Everything with Air Gestures ✋
</div>
