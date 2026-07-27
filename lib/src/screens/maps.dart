import 'dart:ui';
import 'package:cleadr/src/screens/maps_search.dart';
import 'package:cleadr/src/screens/navigation.dart';
import 'package:cleadr/src/services/location_service.dart';
import 'package:cleadr/src/services/services.dart';
import 'package:cleadr/src/util/functions.dart';
import 'package:cleadr/src/util/place.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  bool _isLoading = true;
  bool _isRoutePreview = false;
  String? _initError;

  late LatLng _currentLocation;
  LatLng? _destinationLocation;

  double _zoom = 15.0;
  late final GoogleMapsNavigationView _navigationView;
  late final GoogleNavigationViewController _navigationViewController;
  Marker? _waypointMarker;
  late Place _destinationPlace;

  @override
  void initState() {
    super.initState();
    _initNavigator();
  }

  @override
  void dispose() {
    _disposeNavigator();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show error state if initialization failed
    if (_initError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Map Initialization Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _initError!,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _initError = null;
                      _isLoading = true;
                    });
                    _initNavigator();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _isLoading

        // Smooth background transition while map initializes (prevents double LoadingScreen splash)
        ? const Scaffold(backgroundColor: Color(0xFFF8FAFC))
        : Stack(
            children: [
              // Maps Screen
              _navigationView,

              _destinationLocation != null
                  ? _isRoutePreview == false

                      // Place Details Card
                      ? _destinationPlace.PlaceDetailsCard(() {
                          _removeWaypointMarker();
                          setState(() {});
                        })

                      // Route Preview Card
                      : _destinationPlace.RoutePreviewCard(
                          context,
                          () {
                            _removeRoutePreview();
                            _removeWaypointMarker();
                            setState(() {});
                          },
                        )
                  : Container(),

              // Clear Pin Button (Shown when a pin/destination is active)
              _destinationLocation != null
                  ? Positioned(
                      left: 16,
                      bottom: 215,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () async {
                                  await _removeRoutePreview();
                                  await _removeWaypointMarker();
                                  _destinationPlace = Place();
                                  setState(() {});
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14.0, vertical: 10.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_off_rounded,
                                        color: Color(0xFFEA4335),
                                        size: 20,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Clear Pin",
                                        style: TextStyle(
                                          color: Color(0xFFEA4335),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(),

              // Bottom My Location Button
              Positioned(
                right: 16,
                bottom: _destinationLocation != null ? 215 : 24,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () async {
                            Position currentPosition =
                                await LocationService().getCurrentPosition();
                            _currentLocation = LatLng(
                              latitude: currentPosition.latitude,
                              longitude: currentPosition.longitude,
                            );
                            _navigationViewController.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: _currentLocation,
                                  zoom: 16.0,
                                ),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Icon(
                              Icons.my_location_rounded,
                              color: Color(0xFF4285F4),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              _destinationLocation != null

                  // Route, Start
                  ? Positioned(
                      right: 16,
                      bottom: 24,
                      child: FloatingActionButton.extended(
                        elevation: 4.0,
                        backgroundColor: _isRoutePreview == false
                            // Route colour
                            ? const Color(0xFF4285F4)
                            // Start colour
                            : const Color(0xFF34A853),
                        icon: Icon(
                          _isRoutePreview == false
                              ? Icons.directions_rounded
                              : Icons.navigation_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          _isRoutePreview == false ? "Directions" : "Start AR",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () {
                          if (_isRoutePreview == false) {
                            // Route button
                            _showRoutePreview();
                            _isRoutePreview = true;
                            setState(() {});
                          } else {
                            // Start button
                            _disposeNavigator();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    // Navigation Screen
                                    NavigationScreen(
                                  destinationLocation: _destinationLocation!,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    )
                  : Container(),

              // Search
              MapsSearchScreen(
                onDestinationClicked: _onDestinationClicked,
                destinationPlace: _destinationPlace,
              ),
            ],
          );
  }

  Future<void> _initNavigator() async {
    if (mounted) {
      try {
        // Get current location (filtered & smoothed)
        debugLog("MapsScreen: Getting current position...");
        Position currentPosition = await LocationService().getCurrentPosition();
        _currentLocation = LatLng(
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
        );
        debugLog("MapsScreen: Position obtained: ${currentPosition.latitude}, ${currentPosition.longitude}");

        // Initialise maps session and view
        debugLog("MapsScreen: Initializing navigation session...");
        await GoogleMapsNavigator.initializeNavigationSession();
        debugLog("MapsScreen: Navigation session initialized.");

        _navigationView = GoogleMapsNavigationView(
          initialNavigationUIEnabledPreference:
              NavigationUIEnabledPreference.disabled, // Maps only session

          initialCameraPosition:
              CameraPosition(target: _currentLocation, zoom: _zoom),
          initialCompassEnabled: false,
          initialMapToolbarEnabled: false,
          initialZoomControlsEnabled: false,

          onViewCreated: _onViewCreated,
          onCameraMove: _onCameraMove,
          onMapClicked:
              _onDestinationClicked, // TODO: _onMapClicked - Snaps to closest place pin
          onMapLongClicked: _onDestinationClicked,
        );

        // Initialise _destinationPlace
        _destinationPlace = Place();

        _isLoading = false;
        setState(() {});
        debugLog("MapsScreen: Initialization complete.");
      } catch (e, stackTrace) {
        debugLog("MapsScreen: _initNavigator FAILED: $e");
        debugLog("MapsScreen: StackTrace: $stackTrace");

        // Show error state in-place (do NOT redirect to CleadrApp — that causes a T&C loop)
        if (mounted) {
          setState(() {
            _initError = e.toString();
          });
        }
      }
    }
  }

  Future<void> _disposeNavigator() async {
    await _removeRoutePreview();
    await GoogleMapsNavigator.clearDestinations();
    await GoogleMapsNavigator.cleanup();
  }

  Future<void> _onViewCreated(GoogleNavigationViewController controller) async {
    _navigationViewController = controller;
    await controller.setMyLocationEnabled(true);
    await controller.settings.setMyLocationButtonEnabled(false);
  }

  void _onCameraMove(CameraPosition cameraPosition) {
    _zoom = cameraPosition.zoom;
    debugLog("_zoom: $_zoom");
  }

  Future<void> _onDestinationClicked(LatLng destinationLocation) async {
    // Update _destinationLocation, _waypointMarker, and new camera position
    _destinationLocation = destinationLocation;
    await _updateWaypointMarker(destinationLocation);
    await _navigationViewController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: destinationLocation,
          zoom: _zoom,
        ),
      ),
    );

    // Update _destinationPlace and route estimation
    String distanceStr, durationStr;
    int duration;
    DateTime startTime, endTime;

    // Place Details
    _destinationPlace = await Services.fetchPlaceDetails(destinationLocation);

    // Place Route Estimation
    (distanceStr, durationStr, duration) =
        await Services.fetchPlaceRouteEstimation(
      _currentLocation,
      destinationLocation,
    );
    startTime = DateTime.now();
    endTime = startTime.add(Duration(seconds: duration));

    _destinationPlace.distanceStr = distanceStr;
    _destinationPlace.durationStr = durationStr;
    _destinationPlace.duration = duration;
    _destinationPlace.startTime = startTime;
    _destinationPlace.endTime = endTime;

    setState(() {});
  }

  Future<void> _updateWaypointMarker(LatLng destinationLocation) async {
    // Destination marker options
    final MarkerOptions markerOptions = MarkerOptions(
      position: LatLng(
        latitude: _destinationLocation!.latitude,
        longitude: _destinationLocation!.longitude,
      ),
    );

    // New or Update _waypointMarker
    if (_waypointMarker == null) {
      _waypointMarker = (await _navigationViewController
              .addMarkers(<MarkerOptions>[markerOptions]))
          .first;
    } else {
      _waypointMarker = (await _navigationViewController.updateMarkers(
              <Marker>[_waypointMarker!.copyWith(options: markerOptions)]))
          .first;
    }
  }

  Future<void> _removeWaypointMarker() async {
    // Update _destinationLocation
    _destinationLocation = null;

    // Update _waypointMarker
    if (_waypointMarker != null) {
      await _navigationViewController.removeMarkers([_waypointMarker!]);
      _waypointMarker = null;
    }
  }

  Future<void> _showRoutePreview() async {
    await GoogleMapsNavigator.setDestinations(
      Destinations(
        waypoints: <NavigationWaypoint>[
          NavigationWaypoint.withLatLngTarget(
            title: "${_destinationPlace.name}",
            target: _destinationLocation,
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

    await _navigationViewController.showRouteOverview();
    setState(() {});
  }

  Future<void> _removeRoutePreview() async {
    await GoogleMapsNavigator.cleanup();
    _isRoutePreview = false;
  }
}
