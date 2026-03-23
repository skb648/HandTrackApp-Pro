import 'dart:math';

/// ═══════════════════════════════════════════════════════════════════════════════
/// EXPONENTIAL MOVING AVERAGE (EMA) SMOOTHING
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Formula: smoothed = alpha × raw + (1 - alpha) × previous_smoothed
///
/// Alpha values:
/// - 0.1 = Very smooth, slow response (good for jittery input)
/// - 0.2 = Balanced smoothness and responsiveness
/// - 0.3 = More responsive, less smooth
/// - 0.5 = Fast response, minimal smoothing
class EMASmoother {
  double _smoothedValue = 0;
  bool _isInitialized = false;
  final double alpha;

  EMASmoother({this.alpha = 0.2});

  /// Update with new raw value, returns smoothed value and delta
  (double, double) update(double rawValue, double timestamp) {
    if (!_isInitialized) {
      _smoothedValue = rawValue;
      _isInitialized = true;
      return (_smoothedValue, 0.0);
    }
    
    final prevValue = _smoothedValue;
    _smoothedValue = alpha * rawValue + (1 - alpha) * _smoothedValue;
    
    return (_smoothedValue, (_smoothedValue - prevValue).abs());
  }

  double get current => _smoothedValue;
  bool get isInitialized => _isInitialized;

  void reset() {
    _smoothedValue = 0;
    _isInitialized = false;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// ONE EURO FILTER - Adaptive low-pass filter
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Better than EMA for cursor smoothing:
/// - Adapts cutoff frequency based on speed
/// - Low latency for fast movements
/// - High smoothing for slow movements (reduces jitter)
class OneEuroFilter {
  final double minCutoff;
  final double beta;
  final double dCutoff;

  double _prevValue = 0;
  double _prevDerivative = 0;
  DateTime? _prevTime;
  bool _initialized = false;

  OneEuroFilter({
    this.minCutoff = 1.0,
    this.beta = 0.007,
    this.dCutoff = 1.0,
  });

  double filter(double value, DateTime timestamp) {
    if (!_initialized) {
      _prevValue = value;
      _prevTime = timestamp;
      _initialized = true;
      return value;
    }

    final deltaTime = timestamp.difference(_prevTime!).inMicroseconds / 1e6;
    if (deltaTime <= 0) return _prevValue;

    // Calculate derivative (speed)
    final derivative = (value - _prevValue) / deltaTime;
    final filteredDerivative = _exponentialSmoothing(derivative, _prevDerivative, _alpha(dCutoff, deltaTime));
    _prevDerivative = filteredDerivative;

    // Adaptive cutoff based on speed
    final cutoff = minCutoff + beta * filteredDerivative.abs();
    final filteredValue = _exponentialSmoothing(value, _prevValue, _alpha(cutoff, deltaTime));

    _prevValue = filteredValue;
    _prevTime = timestamp;

    return filteredValue;
  }

  double _alpha(double cutoff, double deltaTime) {
    final te = 1.0 / (2 * pi * cutoff);
    return 1.0 / (1.0 + te / deltaTime);
  }

  double _exponentialSmoothing(double current, double prev, double alpha) {
    return alpha * current + (1 - alpha) * prev;
  }

  void reset() {
    _initialized = false;
    _prevValue = 0;
    _prevDerivative = 0;
    _prevTime = null;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// 3D POINT - Hand landmark coordinate
/// ═══════════════════════════════════════════════════════════════════════════════
class Point3D {
  final double x;
  final double y;
  final double z;

  const Point3D(this.x, this.y, this.z);
  factory Point3D.zero() => const Point3D(0, 0, 0);

  double distanceTo(Point3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  double distanceTo2D(Point3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() => 'Point3D(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// LANDMARK SMOOTHER - Smooths all 21 hand landmarks
/// ═══════════════════════════════════════════════════════════════════════════════
class LandmarkSmoother {
  final List<EMASmoother> _smoothers;
  final int pointCount;

  LandmarkSmoother({
    this.pointCount = 21,
    double alpha = 0.25,
  }) : _smoothers = List.generate(pointCount * 3, (_) => EMASmoother(alpha: alpha));

  List<Point3D> smooth(List<Point3D> rawPoints) {
    if (rawPoints.length != pointCount) return rawPoints;

    return List.generate(pointCount, (i) {
      final raw = rawPoints[i];
      final xSmooth = _smoothers[i * 3].update(raw.x, 0).$1;
      final ySmooth = _smoothers[i * 3 + 1].update(raw.y, 0).$1;
      final zSmooth = _smoothers[i * 3 + 2].update(raw.z, 0).$1;
      return Point3D(xSmooth, ySmooth, zSmooth);
    });
  }

  void reset() {
    for (final smoother in _smoothers) {
      smoother.reset();
    }
  }
}
