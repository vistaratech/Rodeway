import 'dart:async';
import 'package:cleadr/src/screens/loading.dart';
import 'package:cleadr/src/services/ble_service.dart';
import 'package:cleadr/src/services/location_service.dart';
import 'package:cleadr/src/util/constants.dart';
import 'package:cleadr/src/util/functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

class ARNavigationScreen extends StatefulWidget {
  const ARNavigationScreen({super.key});

  @override
  State<ARNavigationScreen> createState() => _ARNavigationScreenState();
}

class _ARNavigationScreenState extends State<ARNavigationScreen> {
  bool _isLoading = true;

  late final UnityWidget _unityWidget;
  UnityWidgetController? _unityWidgetController;
  StreamSubscription<NavInfoEvent>? _navInfoSubscription;

  late final String _unityGameObject;
  late final String _unityMethodName;

  List<Lane>? _lanes;

  String? _maneuver;
  int? _distance;
  int? _targetLane;

  // Route path line
  bool _routePathSent = false;

  @override
  void initState() {
    super.initState();
    _initUnity();
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
    return _isLoading
        ? const LoadingScreen()
        : _unityWidget;
  }

  void _initUnity() {
    _unityWidget = UnityWidget(onUnityCreated: (controller) {
      _unityWidgetController = controller;
      controller.resume();

      // Send route path once Unity is ready
      _fetchAndSendRoutePath();
    });

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
    _lanes = event.navInfo.currentStep!.lanes;

    _maneuver = event.navInfo.currentStep!.maneuver.name;
    _distance = event.navInfo.distanceToCurrentStepMeters;
    _targetLane = _findTargetLane();

    _flutterToUnityJsonMessage({
      "maneuver": _maneuver,
      "distance": _distance,
      "target_lane": _targetLane,
    });

    // Send BLE turn command to ESP32 (triggered when within 120m/100m)
    BleService.instance.processManeuver(
      _maneuver,
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
}
