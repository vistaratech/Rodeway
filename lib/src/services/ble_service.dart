import 'dart:async';
import 'dart:convert';

import 'package:cleadr/src/util/functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BLE connection states for UI reactivity.
enum BleConnectionState {
  disconnected,
  bluetoothOff,
  scanning,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Singleton service managing BLE connectivity to an ESP32 SuperMini.
///
/// Provides scan-by-UUID, connect, auto-reconnect, command dispatch,
/// duplicate prevention, and device ID persistence.
class BleService {
  // ── Singleton ──
  BleService._internal();
  static final BleService instance = BleService._internal();

  // ── ESP32 BLE UUIDs ──
  static final Uuid _serviceUuid =
      Uuid.parse('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final Uuid _characteristicUuid =
      Uuid.parse('beb5483e-36e1-4688-b7f5-ea07361b26a8');

  // ── SharedPreferences key ──
  static const String _savedDeviceIdKey = 'ble_last_device_id';

  // ── Reactive BLE instance ──
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // ── State ──
  final ValueNotifier<BleConnectionState> connectionState =
      ValueNotifier(BleConnectionState.disconnected);

  /// Notifies UI whenever a command is sent to ESP32 (e.g. 'RIGHT_ON', 'LEFT_ON', 'ALL_OFF')
  final ValueNotifier<String?> lastSentCommand = ValueNotifier(null);

  String? _connectedDeviceId;
  String? _connectedDeviceName;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  QualifiedCharacteristic? _writeCharacteristic;

  // ── Duplicate command prevention ──
  String? _lastBleCommand;

  // ── Auto-reconnect ──
  Timer? _reconnectTimer;
  bool _navigationActive = false;

  // ── Bluetooth adapter state monitoring ──
  StreamSubscription<BleStatus>? _bleStatusSubscription;
  bool _isBluetoothMonitorActive = false;

  /// The name of the currently (or last) connected device.
  String? get connectedDeviceName => _connectedDeviceName;

  // ─────────────────────────────────────────────
  //  Bluetooth Adapter State
  // ─────────────────────────────────────────────

  /// Checks if Bluetooth is ready (adapter powered on & permissions granted).
  ///
  /// If Bluetooth is off, sets state to [BleConnectionState.bluetoothOff]
  /// and waits up to [timeout] for the user to turn it on.
  /// Returns `true` if Bluetooth becomes ready, `false` otherwise.
  Future<bool> ensureBluetoothReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // 1. Request BT permissions (Android 12+ requires BLUETOOTH_SCAN & BLUETOOTH_CONNECT)
    final permissionsGranted = await _requestBluetoothPermissions();
    if (!permissionsGranted) {
      debugLog('BleService: Bluetooth permissions denied');
      _updateState(BleConnectionState.bluetoothOff);
      return false;
    }

    // 2. Check current adapter status
    final currentStatus = _ble.status;
    debugLog('BleService: Current BLE adapter status: $currentStatus');

    if (currentStatus == BleStatus.ready) {
      // Adapter is on and ready
      _startBluetoothMonitor();
      return true;
    }

    if (currentStatus == BleStatus.unsupported) {
      debugLog('BleService: BLE is not supported on this device');
      _updateState(BleConnectionState.error);
      return false;
    }

    // 3. Adapter is not ready (poweredOff, unauthorized, or unknown)
    _updateState(BleConnectionState.bluetoothOff);
    debugLog('BleService: Bluetooth is off — waiting up to ${timeout.inSeconds}s for user to enable...');

    // 4. Wait for adapter to come on, with timeout
    try {
      await _ble.statusStream
          .where((status) => status == BleStatus.ready)
          .first
          .timeout(timeout);

      debugLog('BleService: Bluetooth turned on ✓');
      _startBluetoothMonitor();
      return true;
    } on TimeoutException {
      debugLog('BleService: Timed out waiting for Bluetooth to turn on');
      // Stay in bluetoothOff state — user can tap again
      return false;
    } catch (e) {
      debugLog('BleService: Error waiting for Bluetooth: $e');
      return false;
    }
  }

  /// Request Bluetooth permissions needed for scanning and connecting.
  Future<bool> _requestBluetoothPermissions() async {
    try {
      // On Android 12+, we need BLUETOOTH_SCAN and BLUETOOTH_CONNECT.
      // On older Android, we need BLUETOOTH and location.
      // permission_handler maps Permission.bluetooth / bluetoothScan / bluetoothConnect
      // to the correct platform-level permissions.
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      debugLog('BleService: BT Scan permission: $scanStatus');
      debugLog('BleService: BT Connect permission: $connectStatus');

      if (scanStatus.isGranted && connectStatus.isGranted) {
        return true;
      }

      // If permanently denied, we can't do anything — user needs to go to settings
      if (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied) {
        debugLog('BleService: BT permissions permanently denied — user must enable in settings');
      }

      return false;
    } catch (e) {
      debugLog('BleService: Error requesting BT permissions: $e');
      // On platforms where these permissions don't exist, assume granted
      return true;
    }
  }

  /// Start monitoring the Bluetooth adapter state for on/off changes.
  void _startBluetoothMonitor() {
    if (_isBluetoothMonitorActive) return;
    _isBluetoothMonitorActive = true;

    _bleStatusSubscription?.cancel();
    _bleStatusSubscription = _ble.statusStream.listen((status) {
      debugLog('BleService: BLE adapter status changed → $status');

      if (status != BleStatus.ready) {
        // Bluetooth was turned off (or became unauthorized/unsupported)
        debugLog('BleService: Bluetooth turned off mid-session');

        // If we were connected or scanning, clean up
        _scanSubscription?.cancel();
        _scanSubscription = null;
        _connectionSubscription?.cancel();
        _connectionSubscription = null;
        _writeCharacteristic = null;
        _lastBleCommand = null;

        _updateState(BleConnectionState.bluetoothOff);
      } else if (connectionState.value == BleConnectionState.bluetoothOff) {
        // Bluetooth was turned back on while we were in bluetoothOff state
        debugLog('BleService: Bluetooth turned back on');
        _updateState(BleConnectionState.disconnected);

        // If navigation is active, auto-reconnect
        if (_navigationActive) {
          debugLog('BleService: Navigation active — auto-reconnecting...');
          scanAndConnect();
        }
      }
    });
  }

  /// Stop monitoring the Bluetooth adapter state.
  void _stopBluetoothMonitor() {
    _bleStatusSubscription?.cancel();
    _bleStatusSubscription = null;
    _isBluetoothMonitorActive = false;
  }

  // ─────────────────────────────────────────────
  //  Scanning & Connecting
  // ─────────────────────────────────────────────

  /// Start scanning and auto-connect to the first ESP32 found.
  ///
  /// Prefers filtering by [_serviceUuid]. Falls back to device name
  /// containing "ESP32" if the UUID isn't advertised.
  Future<void> scanAndConnect() async {
    // If already connected, nothing to do
    if (connectionState.value == BleConnectionState.connected) return;

    // ── Ensure Bluetooth is on & permissions granted ──
    final ready = await ensureBluetoothReady();
    if (!ready) {
      debugLog('BleService: Bluetooth not ready — aborting scan');
      return;
    }

    // Try reconnecting to saved device first
    final savedId = await _loadSavedDeviceId();
    if (savedId != null) {
      debugLog('BleService: Attempting direct reconnect to saved device: $savedId');
      _connectToDevice(savedId, 'ESP32 (saved)');
      return;
    }

    // Start scanning
    _updateState(BleConnectionState.scanning);
    debugLog('BleService: Scanning for ESP32 by service UUID...');

    _scanSubscription?.cancel();
    _scanSubscription = _ble
        .scanForDevices(
      withServices: [_serviceUuid],
      scanMode: ScanMode.lowLatency,
    )
        .listen(
      (device) {
        debugLog('BleService: Found device: ${device.name} (${device.id})');
        _scanSubscription?.cancel();
        _connectToDevice(device.id, device.name);
      },
      onError: (error) {
        debugLog('BleService: UUID scan error: $error — falling back to name scan');
        _scanSubscription?.cancel();
        _scanByName();
      },
    );

    // Timeout after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (connectionState.value == BleConnectionState.scanning) {
        debugLog('BleService: Scan timed out');
        cancelScan();
        _updateState(BleConnectionState.error);
      }
    });
  }

  /// Fallback: scan by device name containing "ESP32".
  void _scanByName() {
    _updateState(BleConnectionState.scanning);
    debugLog('BleService: Scanning for ESP32 by name...');

    _scanSubscription = _ble
        .scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    )
        .listen(
      (device) {
        if (device.name.toUpperCase().contains('ESP32')) {
          debugLog('BleService: Found by name: ${device.name} (${device.id})');
          _scanSubscription?.cancel();
          _connectToDevice(device.id, device.name);
        }
      },
      onError: (error) {
        debugLog('BleService: Name scan error: $error');
        _updateState(BleConnectionState.error);
      },
    );
  }

  /// Connect to a specific device by ID.
  void _connectToDevice(String deviceId, String deviceName) {
    _updateState(BleConnectionState.connecting);
    debugLog('BleService: Connecting to $deviceName ($deviceId)...');

    _connectionSubscription?.cancel();
    _connectionSubscription = _ble
        .connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    )
        .listen(
      (update) {
        debugLog('BleService: Connection state: ${update.connectionState}');

        switch (update.connectionState) {
          case DeviceConnectionState.connected:
            _connectedDeviceId = deviceId;
            _connectedDeviceName = deviceName;
            _writeCharacteristic = QualifiedCharacteristic(
              serviceId: _serviceUuid,
              characteristicId: _characteristicUuid,
              deviceId: deviceId,
            );
            _saveDeviceId(deviceId);
            _stopReconnectTimer();
            _updateState(BleConnectionState.connected);
            debugLog('BleService: Connected to $deviceName ✓');
            break;

          case DeviceConnectionState.disconnected:
            debugLog('BleService: Disconnected from $deviceName');
            _writeCharacteristic = null;
            _lastBleCommand = null;

            // Auto-reconnect if navigation is active
            if (_navigationActive) {
              _startReconnectTimer();
            } else {
              _updateState(BleConnectionState.disconnected);
            }
            break;

          case DeviceConnectionState.connecting:
            _updateState(BleConnectionState.connecting);
            break;

          case DeviceConnectionState.disconnecting:
            break;
        }
      },
      onError: (error) {
        debugLog('BleService: Connection error: $error');
        _writeCharacteristic = null;
        _lastBleCommand = null;

        if (_navigationActive) {
          _startReconnectTimer();
        } else {
          _updateState(BleConnectionState.error);
        }
      },
    );
  }

  /// Cancel an ongoing scan.
  void cancelScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (connectionState.value == BleConnectionState.scanning) {
      _updateState(BleConnectionState.disconnected);
    }
    debugLog('BleService: Scan cancelled');
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    _stopReconnectTimer();
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _writeCharacteristic = null;
    _lastBleCommand = null;
    _connectedDeviceId = null;
    _updateState(BleConnectionState.disconnected);
    debugLog('BleService: Disconnected');
  }

  // ─────────────────────────────────────────────
  //  Sending Commands
  // ─────────────────────────────────────────────

  /// Send a raw BLE command string to the ESP32.
  ///
  /// Skips if the same command was already sent (duplicate prevention).
  Future<void> sendCommand(String command) async {
    if (_writeCharacteristic == null) {
      debugLog('BleService: Cannot send "$command" — not connected');
      return;
    }

    // Duplicate prevention
    if (command == _lastBleCommand) {
      return;
    }

    try {
      final bytes = utf8.encode(command);
      await _ble.writeCharacteristicWithResponse(
        _writeCharacteristic!,
        value: bytes,
      );
      _lastBleCommand = command;
      lastSentCommand.value = '$command (${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')})';
      debugLog('BleService: Sent "$command" ✓');
      print('[BleService] Successfully transmitted signal to ESP32: $command');
    } catch (e) {
      debugLog('BleService: Failed to send "$command": $e');
    }
  }

  // ─────────────────────────────────────────────
  //  Navigation Maneuver → BLE Command
  // ─────────────────────────────────────────────

  /// Max distance (in meters) before a turn to trigger the ESP32 indicator light.
  static const int triggerDistanceMeters = 120;

  /// Process a maneuver event from the navigation SDK.
  ///
  /// [maneuver] — the maneuver name (e.g., `turnRight`, `TURN_RIGHT`).
  /// [distanceMeters] — distance to the turn in meters (triggers signal within 100m-120m).
  void processManeuver(
    String? maneuver, {
    int? distanceMeters,
  }) {
    if (connectionState.value != BleConnectionState.connected) {
      debugLog('BleService: processManeuver skipped — BLE not connected');
      return;
    }
    if (maneuver == null) return;

    final lowerManeuver = maneuver.toLowerCase();
    final isRight = lowerManeuver.contains('right') || lowerManeuver.contains('clockwise');
    final isLeft = lowerManeuver.contains('left') || lowerManeuver.contains('counterclockwise');

    if (!isRight && !isLeft) {
      // Straight or non-turn maneuver → turn off light if it was on
      if (_lastBleCommand != null && _lastBleCommand != 'ALL_OFF') {
        sendCommand('ALL_OFF');
      }
      return;
    }

    // If distance is provided and we are more than 120 meters away, wait until within 120m (e.g. 100m)
    if (distanceMeters != null && distanceMeters > triggerDistanceMeters) {
      debugLog('BleService: Turn "$maneuver" ahead, but distance (${distanceMeters}m) > 120m — waiting');
      if (_lastBleCommand != null && _lastBleCommand != 'ALL_OFF') {
        sendCommand('ALL_OFF');
      }
      return;
    }

    // Within 120m (e.g. 100m) of turn → send signal to ESP32!
    if (isRight) {
      sendCommand('RIGHT_ON');
    } else if (isLeft) {
      sendCommand('LEFT_ON');
    }
  }

  // ─────────────────────────────────────────────
  //  Navigation Lifecycle
  // ─────────────────────────────────────────────

  /// Call when navigation starts to enable auto-reconnect.
  void onNavigationStarted() {
    _navigationActive = true;
    _lastBleCommand = null;
    _startBluetoothMonitor();
    debugLog('BleService: Navigation started — auto-reconnect enabled');
  }

  /// Call when navigation ends (cancelled, destination reached).
  ///
  /// Sends `ALL_OFF`, stops auto-reconnect, and disconnects.
  Future<void> onNavigationEnded() async {
    _navigationActive = false;
    debugLog('BleService: Navigation ended — sending ALL_OFF and disconnecting');

    // Force-send ALL_OFF regardless of duplicate prevention
    _lastBleCommand = null;
    await sendCommand('ALL_OFF');

    // Small delay to ensure the command is transmitted
    await Future.delayed(const Duration(milliseconds: 300));

    await disconnect();
    _stopBluetoothMonitor();
  }

  // ─────────────────────────────────────────────
  //  Auto-Reconnect
  // ─────────────────────────────────────────────

  void _startReconnectTimer() {
    _stopReconnectTimer();
    _updateState(BleConnectionState.reconnecting);
    debugLog('BleService: Starting auto-reconnect (every 4s)...');

    _reconnectTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_navigationActive) {
        _stopReconnectTimer();
        _updateState(BleConnectionState.disconnected);
        return;
      }

      if (connectionState.value == BleConnectionState.connected) {
        _stopReconnectTimer();
        return;
      }

      // Don't attempt reconnect if Bluetooth is off
      if (connectionState.value == BleConnectionState.bluetoothOff) {
        debugLog('BleService: Auto-reconnect skipped — Bluetooth is off');
        return;
      }

      debugLog('BleService: Auto-reconnect attempt...');
      if (_connectedDeviceId != null) {
        _connectToDevice(_connectedDeviceId!, _connectedDeviceName ?? 'ESP32');
      } else {
        scanAndConnect();
      }
    });
  }

  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // ─────────────────────────────────────────────
  //  Device ID Persistence
  // ─────────────────────────────────────────────

  Future<void> _saveDeviceId(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedDeviceIdKey, deviceId);
      debugLog('BleService: Saved device ID: $deviceId');
    } catch (e) {
      debugLog('BleService: Failed to save device ID: $e');
    }
  }

  Future<String?> _loadSavedDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_savedDeviceIdKey);
      debugLog('BleService: Loaded saved device ID: $id');
      return id;
    } catch (e) {
      debugLog('BleService: Failed to load device ID: $e');
      return null;
    }
  }

  /// Clear the saved device ID (e.g., when user wants to pair a new device).
  Future<void> forgetSavedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedDeviceIdKey);
      debugLog('BleService: Cleared saved device ID');
    } catch (e) {
      debugLog('BleService: Failed to clear device ID: $e');
    }
  }

  // ─────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────

  void _updateState(BleConnectionState state) {
    connectionState.value = state;
    debugLog('BleService: State → ${state.name}');
  }
}
