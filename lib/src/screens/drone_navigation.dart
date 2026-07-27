import 'package:cleadr/src/services/drone_service.dart';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

class DroneNavigationScreen extends StatefulWidget {
  final LatLng destinationLocation;
  final MapType mapType;

  const DroneNavigationScreen({
    super.key,
    required this.destinationLocation,
    this.mapType = MapType.normal,
  });

  @override
  State<DroneNavigationScreen> createState() => _DroneNavigationScreenState();
}

class _DroneNavigationScreenState extends State<DroneNavigationScreen> {
  final DroneService _drone = DroneService.instance;

  @override
  void initState() {
    super.initState();
    _drone.addListener(_onDroneStateChanged);
  }

  @override
  void dispose() {
    _drone.removeListener(_onDroneStateChanged);
    super.dispose();
  }

  void _onDroneStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          // Background Placeholder / Map Simulation Overlay
          Positioned.fill(
            child: Container(
              color: const Color(0xFF161B22),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_sharp,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Drone Autopilot Map Interface',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap anywhere to add Waypoints (W1, W2, W3...)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Waypoints Overlay List on Map
          if (_drone.waypoints.isNotEmpty)
            Positioned(
              left: 16,
              top: 140,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.alt_route, color: Colors.cyanAccent, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Mission Waypoints (${_drone.waypoints.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _drone.clearWaypoints,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _drone.waypoints.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final wp = entry.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'W${wp.id}: ${wp.altitude.toStringAsFixed(0)}m',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

          // Top Telemetry Header Bar
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: _buildTelemetryBar(),
          ),

          // Attitude Horizon Display (Top Right)
          Positioned(
            top: 140,
            right: 16,
            child: _buildAttitudeHorizonWidget(),
          ),

          // Bottom Autopilot Control Panel
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _buildAutopilotControlPanel(),
          ),
        ],
      ),
    );
  }

  // ── Top Telemetry HUD Bar ──

  Widget _buildTelemetryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Connection Indicator
              GestureDetector(
                onTap: _showDroneTypeSelectorDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_drone.isConnected ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _drone.isConnected ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _drone.isConnected ? Icons.sensors : Icons.sensors_off,
                        color: _drone.isConnected ? Colors.greenAccent : Colors.orangeAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _drone.selectedType.name.toUpperCase(),
                        style: TextStyle(
                          color: _drone.isConnected ? Colors.greenAccent : Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _drone.currentStatus,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Battery Indicator
              Row(
                children: [
                  const Icon(Icons.battery_charging_full, color: Colors.lightGreenAccent, size: 16),
                  const SizedBox(width: 2),
                  Text(
                    '${_drone.batteryPercent}%',
                    style: const TextStyle(
                      color: Colors.lightGreenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Satellite Indicator
              Row(
                children: [
                  const Icon(Icons.satellite_alt, color: Colors.lightBlueAccent, size: 15),
                  const SizedBox(width: 2),
                  Text(
                    '${_drone.satellitesCount}',
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          // Altitude & Speed Gauges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGaugeItem('ALTITUDE', '${_drone.altitude.toStringAsFixed(1)} m', Icons.height, Colors.amberAccent),
              _buildGaugeItem('SPEED', '${_drone.speed.toStringAsFixed(1)} m/s', Icons.speed, Colors.cyanAccent),
              _buildGaugeItem('STATE', _drone.flightState.name.toUpperCase(), Icons.flight_takeoff, Colors.purpleAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeItem(String title, String val, IconData icon, Color accentColor) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: accentColor, size: 13),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            color: accentColor,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── Artificial Horizon Widget ──

  Widget _buildAttitudeHorizonWidget() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.75),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flight, color: Colors.cyanAccent, size: 28),
            const SizedBox(height: 2),
            Text(
              'HORIZON',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Autopilot Control Panel ──

  Widget _buildAutopilotControlPanel() {
    final isArmed = _drone.flightState != DroneFlightState.disarmed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waypoint Add Quick Bar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final dummyPt = LatLng(
                      latitude: widget.destinationLocation.latitude + (_drone.waypoints.length * 0.001),
                      longitude: widget.destinationLocation.longitude + (_drone.waypoints.length * 0.001),
                    );
                    _drone.addWaypoint(dummyPt);
                  },
                  icon: const Icon(Icons.add_location_alt, size: 16),
                  label: const Text('+ Add Waypoint', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                    foregroundColor: Colors.cyanAccent,
                    side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _drone.startMission,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('AUTO MISSION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.25),
                  foregroundColor: Colors.greenAccent,
                  side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Action Control Buttons Row
          Row(
            children: [
              // ARM / DISARM
              Expanded(
                child: _buildActionButton(
                  label: isArmed ? 'DISARM' : 'ARM',
                  icon: isArmed ? Icons.power_settings_new : Icons.lock_open,
                  color: isArmed ? Colors.orangeAccent : Colors.greenAccent,
                  onTap: _drone.toggleArm,
                ),
              ),
              const SizedBox(width: 6),
              // TAKEOFF
              Expanded(
                child: _buildActionButton(
                  label: 'TAKEOFF',
                  icon: Icons.flight_takeoff,
                  color: Colors.lightBlueAccent,
                  onTap: _drone.takeoff,
                ),
              ),
              const SizedBox(width: 6),
              // RTL
              Expanded(
                child: _buildActionButton(
                  label: 'RTL (HOME)',
                  icon: Icons.home_work,
                  color: Colors.purpleAccent,
                  onTap: _drone.returnToHome,
                ),
              ),
              const SizedBox(width: 6),
              // EMERGENCY LAND
              Expanded(
                child: _buildActionButton(
                  label: 'LAND',
                  icon: Icons.flight_land,
                  color: Colors.redAccent,
                  onTap: _drone.emergencyLand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Drone Type Selector Dialog ──

  void _showDroneTypeSelectorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Row(
            children: [
              Icon(Icons.flight, color: Colors.cyanAccent),
              SizedBox(width: 8),
              Text('Select Drone Connector', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypeOption(DroneType.tello, 'Ryze Tello Wi-Fi SDK', 'Direct UDP 192.168.10.1:8889'),
              const SizedBox(height: 8),
              _buildTypeOption(DroneType.mavlink, 'MAVLink Standard Drone', 'ArduPilot / Pixhawk / Skydio'),
              const SizedBox(height: 8),
              _buildTypeOption(DroneType.simulator, 'SITL Software Simulator', 'PC Desktop Simulator (127.0.0.1:14550)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeOption(DroneType type, String title, String subtitle) {
    final isSel = _drone.selectedType == type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _drone.setDroneType(type);
          _drone.connect();
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSel ? Colors.cyan.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? Colors.cyanAccent : Colors.white12),
          ),
          child: Row(
            children: [
              Icon(
                isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSel ? Colors.cyanAccent : Colors.white38,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
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
