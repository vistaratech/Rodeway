import 'dart:convert';
import 'package:cleadr/src/util/functions.dart';
import 'package:cleadr/src/util/place.dart';
import 'package:flutter/foundation.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service managing persistence and reactivity for active navigation,
/// route preview, destination pin, and screen transition states across app sessions.
class NavigationStateService extends ChangeNotifier {
  static final NavigationStateService instance = NavigationStateService._internal();
  NavigationStateService._internal();

  static const String _prefsKey = 'rodeway_navigation_state';

  Place? _activePlace;
  LatLng? _destinationLocation;
  bool _isRoutePreview = false;
  bool _isNavigating = false;
  String _currentNavMode = 'maps';
  bool _isInitialized = false;

  Place? get activePlace => _activePlace;
  LatLng? get destinationLocation => _destinationLocation;
  bool get isRoutePreview => _isRoutePreview;
  bool get isNavigating => _isNavigating;
  String get currentNavMode => _currentNavMode;
  bool get hasActiveDestination => _destinationLocation != null && _activePlace != null && _activePlace!.name != null;
  bool get isInitialized => _isInitialized;

  /// Initialise and load persisted navigation state from SharedPreferences.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_prefsKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final map = json.decode(rawJson) as Map<String, dynamic>;
        if (map['place'] != null) {
          _activePlace = Place.fromJson(map['place'] as Map<String, dynamic>);
        }
        if (map['lat'] != null && map['lng'] != null) {
          _destinationLocation = LatLng(
            latitude: (map['lat'] as num).toDouble(),
            longitude: (map['lng'] as num).toDouble(),
          );
        }
        _isRoutePreview = (map['isRoutePreview'] as bool?) ?? false;
        _isNavigating = (map['isNavigating'] as bool?) ?? false;
        _currentNavMode = (map['currentNavMode'] as String?) ?? 'maps';
        debugLog('NavigationStateService: Restored active state for place "${_activePlace?.name}"');
      }
    } catch (e) {
      debugLog('NavigationStateService: Error loading state: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Update and persist the selected destination.
  Future<void> setDestination(Place place, LatLng location, {bool isRoutePreview = false}) async {
    _activePlace = place;
    _destinationLocation = location;
    _isRoutePreview = isRoutePreview;
    await _save();
    notifyListeners();
  }

  /// Toggle route preview state.
  Future<void> setRoutePreview(bool isPreview) async {
    _isRoutePreview = isPreview;
    await _save();
    notifyListeners();
  }

  /// Update active navigation mode/state.
  Future<void> setNavigating(bool isNav, {String? mode}) async {
    _isNavigating = isNav;
    if (mode != null) {
      _currentNavMode = mode;
    }
    await _save();
    notifyListeners();
  }

  /// Update active navigation mode.
  Future<void> setNavMode(String mode) async {
    _currentNavMode = mode;
    await _save();
    notifyListeners();
  }

  /// Clear active destination and route preview.
  Future<void> clearDestination() async {
    _activePlace = null;
    _destinationLocation = null;
    _isRoutePreview = false;
    _isNavigating = false;
    await _save();
    notifyListeners();
  }

  /// Persist current state to SharedPreferences.
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_destinationLocation == null || _activePlace == null) {
        await prefs.remove(_prefsKey);
        debugLog('NavigationStateService: Cleared state from storage.');
        return;
      }
      final map = {
        'place': _activePlace!.toJson(),
        'lat': _destinationLocation!.latitude,
        'lng': _destinationLocation!.longitude,
        'isRoutePreview': _isRoutePreview,
        'isNavigating': _isNavigating,
        'currentNavMode': _currentNavMode,
      };
      await prefs.setString(_prefsKey, json.encode(map));
      debugLog('NavigationStateService: Saved navigation state to storage.');
    } catch (e) {
      debugLog('NavigationStateService: Error saving state: $e');
    }
  }
}
