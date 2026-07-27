import 'dart:async';

import 'package:cleadr/src/util/functions.dart';
import 'package:geolocator/geolocator.dart';

/// Centralized location service that provides stable, filtered GPS positions.
///
/// Solves GPS jumping by:
/// 1. Requesting best-for-navigation accuracy (forces GPS hardware)
/// 2. Applying a distance filter to ignore micro-jitter
/// 3. Rejecting low-accuracy readings (>30m horizontal accuracy)
/// 4. Using exponential moving average (EMA) smoothing
/// 5. Rejecting impossible teleportation jumps (>200 km/h equivalent)
class LocationService {
  // Singleton
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // ── Configuration ──────────────────────────────────────────────────────

  /// Minimum distance (meters) between updates to reduce jitter.
  static const int _distanceFilterMeters = 5;

  /// Maximum acceptable horizontal accuracy (meters).
  /// Readings worse than this are discarded.
  static const double _maxAccuracyMeters = 30.0;

  /// Maximum plausible speed in m/s (~200 km/h).
  /// Readings implying faster travel are rejected as teleportation.
  static const double _maxSpeedMs = 55.56;

  /// EMA smoothing factor (0..1). Higher = more weight on new readings.
  static const double _emaSmoothingAlpha = 0.3;

  // ── State ──────────────────────────────────────────────────────────────

  Position? _lastValidPosition;
  double? _smoothedLat;
  double? _smoothedLng;
  DateTime? _lastTimestamp;

  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  // ── Public API ─────────────────────────────────────────────────────────

  /// Stream of stable, filtered positions.
  Stream<Position> get positionStream => _positionController.stream;

  /// Returns the last known valid (filtered) position, or null.
  Position? get lastKnownPosition => _lastValidPosition;

  /// One-shot: get the current position with high accuracy.
  /// Falls back to the last valid position if the new reading is rejected.
  Future<Position> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0, // One-shot, no filter needed here
      ),
    );

    if (_isValid(position)) {
      _applySmoothing(position);
      return _toSmoothedPosition(position);
    }

    // If the new reading is bad but we have a previous good one, return that
    if (_lastValidPosition != null) {
      debugLog('LocationService: rejected low-quality reading '
          '(accuracy: ${position.accuracy}m), returning last valid position');
      return _lastValidPosition!;
    }

    // First ever reading — accept it even if imperfect
    _initSmoothing(position);
    return position;
  }

  /// Start listening for continuous position updates (e.g. during navigation).
  void startListening() {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: _distanceFilterMeters,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(_onPositionUpdate);

    debugLog('LocationService: started continuous position listening');
  }

  /// Stop continuous position updates.
  void stopListening() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    debugLog('LocationService: stopped continuous position listening');
  }

  /// Reset all state (e.g. when leaving navigation).
  void reset() {
    stopListening();
    _lastValidPosition = null;
    _smoothedLat = null;
    _smoothedLng = null;
    _lastTimestamp = null;
  }

  // ── Internal ───────────────────────────────────────────────────────────

  void _onPositionUpdate(Position position) {
    if (!_isValid(position)) {
      debugLog('LocationService: dropped position — '
          'accuracy: ${position.accuracy}m');
      return;
    }

    _applySmoothing(position);
    final smoothed = _toSmoothedPosition(position);
    _positionController.add(smoothed);
  }

  /// Validates a position reading against accuracy and speed thresholds.
  bool _isValid(Position position) {
    // 1. Accuracy gate
    if (position.accuracy > _maxAccuracyMeters) {
      debugLog('LocationService: accuracy ${position.accuracy}m '
          'exceeds threshold ${_maxAccuracyMeters}m');
      return false;
    }

    // 2. Speed / teleportation gate
    if (_lastValidPosition != null && _lastTimestamp != null) {
      final distanceM = Geolocator.distanceBetween(
        _lastValidPosition!.latitude,
        _lastValidPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      final elapsedSec =
          position.timestamp.difference(_lastTimestamp!).inMilliseconds / 1000;

      if (elapsedSec > 0) {
        final speedMs = distanceM / elapsedSec;
        if (speedMs > _maxSpeedMs) {
          debugLog('LocationService: teleportation detected — '
              '${distanceM.toStringAsFixed(0)}m in '
              '${elapsedSec.toStringAsFixed(1)}s '
              '(${(speedMs * 3.6).toStringAsFixed(0)} km/h)');
          return false;
        }
      }
    }

    return true;
  }

  /// Initialise the EMA with the first valid position.
  void _initSmoothing(Position position) {
    _smoothedLat = position.latitude;
    _smoothedLng = position.longitude;
    _lastValidPosition = position;
    _lastTimestamp = position.timestamp;
  }

  /// Apply exponential moving average to smooth out jitter.
  void _applySmoothing(Position position) {
    if (_smoothedLat == null || _smoothedLng == null) {
      _initSmoothing(position);
      return;
    }

    _smoothedLat =
        _emaSmoothingAlpha * position.latitude + (1 - _emaSmoothingAlpha) * _smoothedLat!;
    _smoothedLng =
        _emaSmoothingAlpha * position.longitude + (1 - _emaSmoothingAlpha) * _smoothedLng!;
    _lastValidPosition = position;
    _lastTimestamp = position.timestamp;
  }

  /// Construct a Position with the smoothed lat/lng but original metadata.
  Position _toSmoothedPosition(Position raw) {
    return Position(
      latitude: _smoothedLat ?? raw.latitude,
      longitude: _smoothedLng ?? raw.longitude,
      timestamp: raw.timestamp,
      accuracy: raw.accuracy,
      altitude: raw.altitude,
      altitudeAccuracy: raw.altitudeAccuracy,
      heading: raw.heading,
      headingAccuracy: raw.headingAccuracy,
      speed: raw.speed,
      speedAccuracy: raw.speedAccuracy,
    );
  }
}
