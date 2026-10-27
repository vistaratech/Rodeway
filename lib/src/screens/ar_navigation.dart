import 'dart:async';
import 'dart:ui';
import 'package:cleadr/src/services/ble_service.dart';
import 'package:cleadr/src/services/location_service.dart';
import 'package:cleadr/src/util/constants.dart';
import 'package:cleadr/src/util/functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class ARNavigationScreen extends StatefulWidget {
  const ARNavigationScreen({super.key});

  @override
  State<ARNavigationScreen> createState() => _ARNavigationScreenState();
}

class _ARNavigationScreenState extends State<ARNavigationScreen> {
  bool _isLoading = true;
  bool _hasCameraPermission = true;

  late final UnityWidget _unityWidget;
  UnityWidgetController? _unityWidgetController;
  StreamSubscription<NavInfoEvent>? _navInfoSubscription;

  late final String _unityGameObject;
  late final String _unityMethodName;

  List<Lane>? _lanes;

  String? _rawManeuver;
  String? _maneuver;
  int? _distance;
  int? _targetLane;

  // Route path line
  bool _routePathSent = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
    try {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          if (mounted) {
            setState(() {
              _hasCameraPermission = false;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugLog("ARNavigationScreen: Camera permission check error: $e");
    }

    if (mounted) {
      _initUnity();
    }
  }

  @override
  void dispose() {
    _navInfoSubscription?.cancel();
    _unityWidgetController?.pause();
    _unityWidgetController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCameraPermission) {
      return _buildCameraPermissionFallback();
    }

    if (_isLoading) {
      return _buildCameraLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Live Camera View (Unity AR / Native AVFoundation Camera View)
          Positioned.fill(
            child: _unityWidget,
          ),

          // AR Navigation HUD Overlay (Turn cues, distance, target lane)
          Positioned.fill(
            child: _buildArHudOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.cyanAccent.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "STARTING AR CAMERA",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Calibrating road view & navigation sensors...",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPermissionFallback() {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 54,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera Access Required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AR Navigation needs camera access to render 3D turn arrows and route paths over the live road view.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Enable Camera Permission'),
                      onPressed: () async {
                        final req = await Permission.camera.request();
                        if (req.isGranted) {
                          setState(() {
                            _hasCameraPermission = true;
                            _isLoading = true;
                          });
                          _initUnity();
                        } else {
                          await openAppSettings();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _initUnity() {
    _unityWidget = UnityWidget(
      onUnityCreated: (controller) {
        _unityWidgetController = controller;
        controller.resume();

        // Send route path once Unity is ready
        _fetchAndSendRoutePath();
      },
      useAndroidViewSurface: true,
      fullscreen: true,
      runImmediately: true,
    );

    _navInfoSubscription?.cancel();
    _navInfoSubscription = GoogleMapsNavigator.setNavInfoListener(
      _onNavInfoEvent,
      numNextStepsToPreview: null,
    );

    _unityGameObject = "Flutter Unity Manager";
    _unityMethodName = "Render";

    _isLoading = false;
    setState(() {});
  }

  void _flutterToUnityJsonMessage(Map<String, dynamic> jsonMessage) {
    if (_unityWidgetController == null) return;
    debugLog("_flutterToUnityJsonMessage() - Sent: $jsonMessage");
    _unityWidgetController!.postJsonMessage(
        _unityGameObject, _unityMethodName, jsonMessage);
  }

  /// Send a message to a specific Unity method (not the default Render method).
  void _sendToUnityMethod(String methodName, Map<String, dynamic> data) {
    if (_unityWidgetController == null) return;
    debugLog("_sendToUnityMethod($methodName) - Sent: $data");
    _unityWidgetController!.postJsonMessage(
        _unityGameObject, methodName, data);
  }

  /// Fetch route polyline from the Google Navigation SDK and send to Unity.
  Future<void> _fetchAndSendRoutePath() async {
    try {
      final segments = await GoogleMapsNavigator.getRouteSegments();
      if (segments.isEmpty) {
        debugLog("_fetchAndSendRoutePath() - No route segments available");
        return;
      }

      // Collect all lat/lng coordinates from route segments
      final List<Map<String, double>> coordinates = [];
      for (final segment in segments) {
        if (segment.latLngs != null) {
          for (final latLng in segment.latLngs!) {
            if (latLng != null) {
              coordinates.add({
                'lat': latLng.latitude,
                'lng': latLng.longitude,
              });
            }
          }
        }
      }

      if (coordinates.isEmpty) {
        debugLog("_fetchAndSendRoutePath() - No coordinates in route segments");
        return;
      }

      debugLog("_fetchAndSendRoutePath() - Sending ${coordinates.length} coordinates to Unity");

      _sendToUnityMethod("UpdateRoutePath", {
        'coordinates': coordinates,
      });

      _routePathSent = true;
    } catch (e) {
      debugLog("_fetchAndSendRoutePath() - Error: $e");
    }
  }

  /// Send current device GPS location to Unity for coordinate conversion.
  Future<void> _sendDeviceLocation() async {
    try {
      final position = await LocationService().getCurrentPosition();
      _sendToUnityMethod("UpdateDeviceLocation", {
        'lat': position.latitude,
        'lng': position.longitude,
      });
    } catch (e) {
      debugLog("_sendDeviceLocation() - Error: $e");
    }
  }

  // Find the closest recommended lane
  int? _findTargetLane() {
    if (_lanes != null) {
      if (_lanes!.length > 1 && _lanes!.length < TARGET_LANE_LIMIT + 1) {
        // tflite limitation: max TARGET_LANE_LIMIT lanes
        // Iterate through "lanes" (_lanes)
        for (int lane = 0; lane < _lanes!.length; lane++) {
          // Iterate through "laneDirections"
          for (int laneDirection = 0;
              laneDirection < _lanes![lane].laneDirections.length;
              laneDirection++) {
            if (_lanes![lane].laneDirections[laneDirection].isRecommended ==
                true) {
              // Case: First lane
              if (lane == 0) {
                // Check after lane (lane + 1), whether isRecommended == false
                for (int laneDirection2 = 0;
                    laneDirection2 < _lanes![lane + 1].laneDirections.length;
                    laneDirection2++) {
                  if (_lanes![lane + 1]
                          .laneDirections[laneDirection2]
                          .isRecommended ==
                      false) {
                    return lane + 1;
                  }
                }
              }

              // Case: Last lane
              else if (lane == _lanes!.length - 1) {
                // Check before lane (lane - 1), whether isRecommended == false
                for (int laneDirection2 = 0;
                    laneDirection2 < _lanes![lane - 1].laneDirections.length;
                    laneDirection2++) {
                  if (_lanes![lane - 1]
                          .laneDirections[laneDirection2]
                          .isRecommended ==
                      false) {
                    return lane + 1;
                  }
                }
              }

              // Default case
              else {
                for (int laneDirection2 = 0;
                    laneDirection2 < _lanes![lane + 1].laneDirections.length;
                    laneDirection2++) {
                  if (_lanes![lane + 1]
                          .laneDirections[laneDirection2]
                          .isRecommended ==
                      false) {
                    return lane + 1;
                  }
                }

                for (int laneDirection2 = 0;
                    laneDirection2 < _lanes![lane - 1].laneDirections.length;
                    laneDirection2++) {
                  if (_lanes![lane - 1]
                          .laneDirections[laneDirection2]
                          .isRecommended ==
                      false) {
                    return lane + 1;
                  }
                }
              }
            }
          }
        }
      }
    }

    return null;
  }

  void _onNavInfoEvent(NavInfoEvent event) {
    if (event.navInfo.currentStep == null) return;

    _lanes = event.navInfo.currentStep?.lanes;

    final rawManeuver = event.navInfo.currentStep?.maneuver.name ?? '';
    _distance = event.navInfo.distanceToCurrentStepMeters;
    _targetLane = _findTargetLane();

    // Map Google Navigation SDK maneuver name to what Unity expects
    final lower = rawManeuver.toLowerCase();
    if (lower.contains('left') || lower.contains('counterclockwise')) {
      _maneuver = 'turnLeft';
    } else if (lower.contains('right') || lower.contains('clockwise')) {
      _maneuver = 'turnRight';
    } else {
      _maneuver = 'straight';
    }

    _rawManeuver = rawManeuver;

    _flutterToUnityJsonMessage({
      "maneuver": _maneuver,
      "distance": _distance,
      "target_lane": _targetLane,
    });

    if (mounted) {
      setState(() {});
    }

    // Send BLE turn command to ESP32 (triggered when within 120m/100m)
    BleService.instance.processManeuver(
      rawManeuver,
      distanceMeters: _distance,
    );

    // Send device location to Unity on each nav update for accurate line positioning
    _sendDeviceLocation();

    // Re-fetch route path if the route changed (rerouting)
    if (event.navInfo.routeChanged) {
      _routePathSent = false;
    }

    // Send route path if not yet sent
    if (!_routePathSent) {
      _fetchAndSendRoutePath();
    }
  }

  String _formatManeuverText(String raw) {
    final upper = raw.toUpperCase();
    if (upper.contains('LEFT') || upper.contains('COUNTERCLOCKWISE')) return 'Turn Left';
    if (upper.contains('RIGHT') || upper.contains('CLOCKWISE')) return 'Turn Right';
    if (upper.contains('UTURN')) return 'Make U-Turn';
    if (upper.contains('MERGE')) return 'Merge';
    if (upper.contains('RAMP')) return 'Take Ramp';
    if (upper.contains('ROUNDABOUT')) return 'Enter Roundabout';
    if (upper.contains('STRAIGHT')) return 'Continue Straight';
    return 'Follow Route';
  }

  IconData _getManeuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turnLeft':
        return Icons.turn_left_rounded;
      case 'turnRight':
        return Icons.turn_right_rounded;
      default:
        return Icons.straight_rounded;
    }
  }

  Color _getManeuverColor(String? maneuver) {
    switch (maneuver) {
      case 'turnLeft':
        return const Color(0xFF00E5FF);
      case 'turnRight':
        return const Color(0xFFFF9100);
      default:
        return const Color(0xFF00E676);
    }
  }

  Widget _buildArHudOverlay() {
    final maneuverText = _rawManeuver != null
        ? _formatManeuverText(_rawManeuver!)
        : (_maneuver == 'turnLeft'
            ? 'Turn Left'
            : (_maneuver == 'turnRight' ? 'Turn Right' : 'Continue Straight'));
    final maneuverColor = _getManeuverColor(_maneuver);
    final maneuverIcon = _getManeuverIcon(_maneuver);
    final distanceStr = _distance != null
        ? (_distance! >= 1000
            ? "${(_distance! / 1000.0).toStringAsFixed(1)} km"
            : "$_distance m")
        : "-- m";

    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Stack(
            children: [
              // 1. Top-Left: AR Status Pill
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.15),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00E676),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "AR VISION LIVE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Top-Center: Floating HUD Navigation Card
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 42.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: maneuverColor.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: maneuverColor.withValues(alpha: 0.2),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: maneuverColor.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: maneuverColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                maneuverIcon,
                                color: maneuverColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  distanceStr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: maneuverColor.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  maneuverText,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (_targetLane != null) ...[
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "LANE",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Text(
                                      "$_targetLane",
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Center Screen: AR Horizon Reticle & 3D Guidance Arrow
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subtle AR Reticle Brackets
                    Opacity(
                      opacity: 0.45,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.cyanAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Approaching Turn Chevron Indicator
                    if (_distance != null &&
                        _distance! <= 250 &&
                        _maneuver != null &&
                        _maneuver != 'straight') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: maneuverColor.withValues(alpha: 0.8),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: maneuverColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(maneuverIcon, color: maneuverColor, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              "TURN IN $distanceStr",
                              style: TextStyle(
                                color: maneuverColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
