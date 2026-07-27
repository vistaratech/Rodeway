import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

enum DroneType { tello, mavlink, simulator }

enum DroneFlightState {
  disarmed,
  armed,
  takingOff,
  inFlight,
  autoMission,
  rtl,
  landing,
}

class DroneWaypoint {
  final int id;
  final LatLng location;
  double altitude; // In meters

  DroneWaypoint({
    required this.id,
    required this.location,
    this.altitude = 10.0,
  });
}

class DroneService extends ChangeNotifier {
  static final DroneService instance = DroneService._internal();
  DroneService._internal();

  DroneType selectedType = DroneType.tello;
  DroneFlightState flightState = DroneFlightState.disarmed;
  bool isConnected = false;

  // Telemetry data
  double altitude = 0.0; // meters
  double speed = 0.0; // m/s
  double pitch = 0.0; // degrees
  double roll = 0.0; // degrees
  double yaw = 0.0; // degrees
  int batteryPercent = 95;
  int satellitesCount = 14;
  String currentStatus = 'Disarmed & Ready';

  // Mission waypoints
  final List<DroneWaypoint> waypoints = [];

  void setDroneType(DroneType type) {
    selectedType = type;
    notifyListeners();
  }

  void connect() {
    isConnected = true;
    currentStatus = 'Connected to ${selectedType.name.toUpperCase()}';
    notifyListeners();
  }

  void disconnect() {
    isConnected = false;
    flightState = DroneFlightState.disarmed;
    currentStatus = 'Disconnected';
    notifyListeners();
  }

  void toggleArm() {
    if (flightState == DroneFlightState.disarmed) {
      flightState = DroneFlightState.armed;
      currentStatus = 'Motors Armed';
    } else {
      flightState = DroneFlightState.disarmed;
      currentStatus = 'Motors Disarmed';
    }
    notifyListeners();
  }

  void takeoff() {
    if (flightState == DroneFlightState.disarmed) {
      flightState = DroneFlightState.armed;
    }
    flightState = DroneFlightState.takingOff;
    currentStatus = 'Taking off to 10m...';
    altitude = 10.0;
    notifyListeners();

    Timer(const Duration(seconds: 2), () {
      flightState = DroneFlightState.inFlight;
      currentStatus = 'Hovering at 10m';
      notifyListeners();
    });
  }

  void startMission() {
    if (waypoints.isEmpty) return;
    flightState = DroneFlightState.autoMission;
    currentStatus = 'Executing Waypoint Mission (${waypoints.length} points)';
    notifyListeners();
  }

  void returnToHome() {
    flightState = DroneFlightState.rtl;
    currentStatus = 'Returning to Launch Site (RTL)';
    notifyListeners();

    Timer(const Duration(seconds: 3), () {
      altitude = 0.0;
      flightState = DroneFlightState.disarmed;
      currentStatus = 'Landed at Home Site';
      notifyListeners();
    });
  }

  void emergencyLand() {
    flightState = DroneFlightState.landing;
    currentStatus = 'Emergency Landing Triggered!';
    notifyListeners();

    Timer(const Duration(seconds: 2), () {
      altitude = 0.0;
      flightState = DroneFlightState.disarmed;
      currentStatus = 'Landed safely';
      notifyListeners();
    });
  }

  void addWaypoint(LatLng point) {
    final newWp = DroneWaypoint(
      id: waypoints.length + 1,
      location: point,
      altitude: 10.0,
    );
    waypoints.add(newWp);
    notifyListeners();
  }

  void updateWaypointAltitude(int index, double alt) {
    if (index >= 0 && index < waypoints.length) {
      waypoints[index].altitude = alt;
      notifyListeners();
    }
  }

  void clearWaypoints() {
    waypoints.clear();
    notifyListeners();
  }
}
