import 'dart:async';
import 'dart:ui';
import 'package:cleadr/src/screens/maps_navigation.dart';
import 'package:cleadr/src/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

class SmartNavigationScreen extends StatefulWidget {
  final LatLng destinationLocation;
  final MapType mapType;

  const SmartNavigationScreen({
    super.key,
    required this.destinationLocation,
    this.mapType = MapType.normal,
  });

  @override
  State<SmartNavigationScreen> createState() => _SmartNavigationScreenState();
}

class _SmartNavigationScreenState extends State<SmartNavigationScreen> {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<NavInfoEvent>? _navInfoSubscription;

  double _currentSpeedKmH = 0.0;
  String _currentManeuver = 'Proceed to route';
  int _distanceToNextManeuver = 0;

  @override
  void initState() {
    super.initState();
    _startSpeedTracking();
    _listenNavEvents();
  }

  void _startSpeedTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (!mounted) return;
        // speed is in m/s, convert to km/h
        final speedKmH = (position.speed * 3.6).clamp(0.0, 180.0);
        setState(() {
          _currentSpeedKmH = speedKmH;
        });
      },
    );
  }

  void _listenNavEvents() {
    _navInfoSubscription?.cancel();
    _navInfoSubscription = GoogleMapsNavigator.setNavInfoListener(
      (NavInfoEvent event) {
        if (!mounted || event.navInfo.currentStep == null) return;
        final step = event.navInfo.currentStep!;
        final maneuver = step.maneuver.name;
        final distanceMeters = event.navInfo.distanceToCurrentStepMeters;

        setState(() {
          _currentManeuver = _formatManeuverText(maneuver);
          _distanceToNextManeuver = distanceMeters ?? 0;
        });

        // Trigger BLE signal processing
        BleService.instance.processManeuver(
          maneuver,
          distanceMeters: distanceMeters,
        );
      },
      numNextStepsToPreview: null,
    );
  }

  String _formatManeuverText(String rawManeuver) {
    if (rawManeuver.contains('RIGHT')) return 'Turn Right';
    if (rawManeuver.contains('LEFT')) return 'Turn Left';
    if (rawManeuver.contains('UTURN')) return 'Make U-Turn';
    if (rawManeuver.contains('MERGE')) return 'Merge';
    if (rawManeuver.contains('RAMP')) return 'Take Ramp';
    if (rawManeuver.contains('ROUNDABOUT')) return 'Enter Roundabout';
    if (rawManeuver.contains('STRAIGHT')) return 'Continue Straight';
    return 'Head to Route';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _navInfoSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Underlying 3D Maps View
          MapsNavigationScreen(
            isMinified: false,
            destinationLocation: widget.destinationLocation,
            mapType: widget.mapType,
          ),

          // Smart Navigation Timeline Card (Matching reference design image)
          Positioned(
            top: 54,
            left: 16,
            width: MediaQuery.of(context).size.width * 0.76 > 310
                ? 310
                : MediaQuery.of(context).size.width * 0.76,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFC).withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left-side Timeline Graphic
                        Column(
                          children: [
                            const SizedBox(height: 2),
                            // Node 1: Destination (Blue Circle with Outer Ring)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),

                            // Dotted Line 1
                            _buildDottedLine(height: 34),

                            // Node 2: Active Turn Maneuver (Glowing Ring)
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF3B82F6),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),

                            // Dotted Line 2
                            _buildDottedLine(height: 34),

                            // Node 3: Speed (Filled Blue Circle)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 16),

                        // Right-side Content Labels
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Item: Your Destination
                              const Text(
                                'Your Destination',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Middle Item: Turn Maneuver & Distance
                              Text(
                                _distanceToNextManeuver > 0
                                    ? '$_currentManeuver in ${_distanceToNextManeuver}m'
                                    : _currentManeuver,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),

                              const SizedBox(height: 34),

                              // Bottom Item: Speed readout
                              Text(
                                '${_currentSpeedKmH.toStringAsFixed(0)} km/h',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 14),

                    // Bottom Card Header & Subtitle
                    const Text(
                      'Smart Navigation',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Navigate with precision using real-time route guidance tools.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildDottedLine({required double height}) {
    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (_) => Container(
            width: 2,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}
