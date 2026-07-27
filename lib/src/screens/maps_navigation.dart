import 'dart:async';

import 'package:cleadr/src/services/ble_service.dart';
import 'package:cleadr/src/services/location_service.dart';
import 'package:cleadr/src/util/functions.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

class MapsNavigationScreen extends StatefulWidget {
  final bool isMinified;
  final LatLng destinationLocation;
  final MapType mapType;

  const MapsNavigationScreen({
    super.key,
    required this.isMinified,
    required this.destinationLocation,
    this.mapType = MapType.normal,
  });

  @override
  State<MapsNavigationScreen> createState() => _MapsNavigationScreenState();
}

class _MapsNavigationScreenState extends State<MapsNavigationScreen> {
  bool _isLoading = true;
  StreamSubscription<NavInfoEvent>? _navInfoSubscription;

  late final GoogleMapsNavigationView _navigationView;
  GoogleNavigationViewController? _navigationViewController;

  @override
  void initState() {
    super.initState();
    _initNavigator();
  }

  @override
  void didUpdateWidget(MapsNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapType != widget.mapType && _navigationViewController != null) {
      _navigationViewController!.setMapType(mapType: widget.mapType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Scaffold(backgroundColor: Color(0xFFF8FAFC))
        :
        // Maps navigation
        _navigationView;
  }

  Future<void> _initNavigator() async {
    if (mounted) {
      // Get current location (filtered & smoothed)
      Position currentPosition = await LocationService().getCurrentPosition();

      // Navigation session
      await GoogleMapsNavigator.initializeNavigationSession();
      _navigationView = GoogleMapsNavigationView(
        initialMapType: widget.mapType,
        initialNavigationUIEnabledPreference:
            NavigationUIEnabledPreference.automatic,
        initialCameraPosition: CameraPosition(
          target: LatLng(
            latitude: currentPosition.latitude,
            longitude: currentPosition.longitude,
          ),
        ),
        onViewCreated: _onViewCreated,
      );

      _isLoading = false;
      setState(() {});
    }
  }

  Future<void> _onViewCreated(GoogleNavigationViewController controller) async {
    _navigationViewController = controller;
    await controller.setMapType(mapType: widget.mapType);

    await GoogleMapsNavigator.setDestinations(
      Destinations(
        waypoints: <NavigationWaypoint>[
          NavigationWaypoint.withLatLngTarget(
            title: "Destination",
            target: widget.destinationLocation,
          )
        ],
        displayOptions: NavigationDisplayOptions(
          showDestinationMarkers: true,
          showStopSigns: true,
          showTrafficLights: true,
        ),
        routingOptions:
            RoutingOptions(travelMode: NavigationTravelMode.driving),
      ),
    );

    await controller.setNavigationUIEnabled(true);
    await controller.setMyLocationEnabled(true);
    await controller.settings.setMyLocationButtonEnabled(false);
    await controller.setSpeedometerEnabled(true);
    await controller.setSpeedLimitIconEnabled(true);
    if (widget.isMinified) {
      await controller.setNavigationHeaderEnabled(false);
      await controller.setNavigationFooterEnabled(false);
    } else {
      await controller.setNavigationTripProgressBarEnabled(true);
    }

    await GoogleMapsNavigator.startGuidance();
    await controller.followMyLocation(CameraPerspective.tilted);

    // Listen to nav info events for BLE turn commands
    _navInfoSubscription?.cancel();
    _navInfoSubscription = GoogleMapsNavigator.setNavInfoListener(
      _onNavInfoEvent,
      numNextStepsToPreview: null,
    );

    setState(() {});
  }

  /// Handle nav info events — sends BLE commands for turn indicators.
  void _onNavInfoEvent(NavInfoEvent event) {
    if (event.navInfo.currentStep == null) return;

    final maneuver = event.navInfo.currentStep!.maneuver.name;
    final distanceMeters = event.navInfo.distanceToCurrentStepMeters;
    debugLog('MapsNav BLE: maneuver=$maneuver, distance=$distanceMeters');

    BleService.instance.processManeuver(
      maneuver,
      distanceMeters: distanceMeters,
    );
  }

  @override
  void dispose() {
    _navInfoSubscription?.cancel();
    super.dispose();
  }
}
