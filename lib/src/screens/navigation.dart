import 'dart:ui';
import 'package:cleadr/src/screens/ar_navigation.dart';
import 'package:cleadr/src/screens/drone_navigation.dart';
import 'package:cleadr/src/screens/maps_navigation.dart';
import 'package:cleadr/src/screens/smart_navigation.dart';
import 'package:cleadr/src/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

enum NavigationMode { maps, ar, drone, smartNav }

class NavigationScreen extends StatefulWidget {
  final LatLng destinationLocation;

  const NavigationScreen({super.key, required this.destinationLocation});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with WidgetsBindingObserver {
  NavigationMode _currentMode = NavigationMode.maps;
  bool _isControlMenuOpen = false;
  bool _isSatelliteView = false;
  double _miniMapWidth = 230.0;
  double _miniMapHeight = 270.0;
  DeviceOrientation? _orientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateOrientation();

    // Notify BleService that navigation has started
    BleService.instance.onNavigationStarted();
  }

  @override
  void didChangeMetrics() {
    _updateOrientation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldQuit = await _showQuitConfirmationDialog(context);
        if (shouldQuit == true && context.mounted) {
          await BleService.instance.onNavigationEnded();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Mode 1: Standard / Satellite MAPS
            if (_currentMode == NavigationMode.maps)
              MapsNavigationScreen(
                isMinified: false,
                destinationLocation: widget.destinationLocation,
                mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
              )
            // Mode 2: AR View
            else if (_currentMode == NavigationMode.ar)
              const ARNavigationScreen()
            // Mode 3: Drone Autopilot & GCS Dashboard
            else if (_currentMode == NavigationMode.drone)
              DroneNavigationScreen(
                destinationLocation: widget.destinationLocation,
                mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
              )
            // Mode 4: SMART NAV Timeline Mode
            else
              SmartNavigationScreen(
                destinationLocation: widget.destinationLocation,
                mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
              ),

            // Resizable AR Floating Mini-Map Box Overlay (Only active in AR mode)
            if (_currentMode == NavigationMode.ar)
              Positioned(
                left: 20,
                bottom: 24,
                width: _orientation == DeviceOrientation.landscapeLeft
                    ? _miniMapWidth.clamp(140.0, MediaQuery.of(context).size.width * 0.45)
                    : _miniMapWidth.clamp(140.0, MediaQuery.of(context).size.width * 0.85),
                height: _miniMapHeight.clamp(140.0, MediaQuery.of(context).size.height * 0.65),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: MapsNavigationScreen(
                            isMinified: true,
                            destinationLocation: widget.destinationLocation,
                            mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
                          ),
                        ),

                        // Drag Resize Handle at Top-Right
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _miniMapWidth = (_miniMapWidth + details.delta.dx)
                                    .clamp(140.0, MediaQuery.of(context).size.width * 0.85);
                                _miniMapHeight = (_miniMapHeight - details.delta.dy)
                                    .clamp(140.0, MediaQuery.of(context).size.height * 0.65);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: const Icon(
                                Icons.open_in_full,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Sliding Control Pop-Up Menu ──
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: _isControlMenuOpen
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildControlMenu(),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Small Arrow Indicator Button ──
            _buildArrowIndicatorButton(),
            const SizedBox(height: 12),

            // ── Cancel FAB ──
            FloatingActionButton(
              backgroundColor: Colors.red,
              child: const Icon(
                color: Colors.white,
                Icons.cancel,
              ),
              onPressed: () async {
                final shouldQuit = await _showQuitConfirmationDialog(context);
                if (shouldQuit == true && context.mounted) {
                  await BleService.instance.onNavigationEnded();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Arrow Indicator Trigger Button with Glassmorphism ──

  Widget _buildArrowIndicatorButton() {
    return ValueListenableBuilder<BleConnectionState>(
      valueListenable: BleService.instance.connectionState,
      builder: (context, state, _) {
        final color = _bleButtonColor(state);
        return GestureDetector(
          onTap: () {
            setState(() {
              _isControlMenuOpen = !_isControlMenuOpen;
            });
          },
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedRotation(
                    turns: _isControlMenuOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Consolidated Slide-Up Light-Mode Glassmorphic Pop-Up Control Menu ──

  Widget _buildControlMenu() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Status & Close button
              ValueListenableBuilder<String?>(
                valueListenable: BleService.instance.lastSentCommand,
                builder: (context, cmd, _) {
                  final isRight = cmd?.contains('RIGHT') ?? false;
                  final isLeft = cmd?.contains('LEFT') ?? false;

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (isRight
                                  ? Colors.amber
                                  : (isLeft ? Colors.teal : Colors.grey))
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isRight
                              ? Icons.turn_right
                              : (isLeft ? Icons.turn_left : Icons.power_settings_new),
                          color: isRight
                              ? Colors.amber.shade900
                              : (isLeft ? Colors.teal.shade800 : Colors.black54),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cmd != null ? 'Signal: $cmd' : 'Controls & Modes',
                          style: TextStyle(
                            color: isRight
                                ? Colors.amber.shade900
                                : (isLeft ? Colors.teal.shade800 : Colors.black87),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isControlMenuOpen = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.black54, size: 14),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Connection Action Tile ("Connect with Roadway")
              ValueListenableBuilder<BleConnectionState>(
                valueListenable: BleService.instance.connectionState,
                builder: (context, state, _) {
                  final color = _bleButtonColor(state);
                  final isConn = state == BleConnectionState.connected;
                  final isScanning = state == BleConnectionState.scanning ||
                      state == BleConnectionState.connecting ||
                      state == BleConnectionState.reconnecting;

                  String label = 'Connect with Roadway';
                  if (isConn) {
                    label = 'Connected (${BleService.instance.connectedDeviceName ?? "Roadway"})';
                  } else if (isScanning) {
                    label = 'Scanning for Roadway...';
                  } else if (state == BleConnectionState.bluetoothOff) {
                    label = 'Turn On Bluetooth';
                  } else {
                    label = 'Connect with Roadway';
                  }

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onBluetoothTap(state),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: color.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.15),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            isScanning
                                ? SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                    ),
                                  )
                                : Icon(
                                    isConn ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                                    color: color,
                                    size: 17,
                                  ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Row 2: Mode Selector (MAPS, AR, DRONE)
              Row(
                children: [
                  Expanded(
                    child: _buildModeButton(
                      label: 'MAPS',
                      icon: Icons.map,
                      mode: NavigationMode.maps,
                      activeColor: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _buildModeButton(
                      label: 'AR',
                      icon: Icons.view_in_ar,
                      mode: NavigationMode.ar,
                      activeColor: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _buildModeButton(
                      label: 'DRONE',
                      icon: Icons.flight,
                      mode: NavigationMode.drone,
                      activeColor: Colors.teal.shade800,
                    ),
                  ),
                ],
              ),

              // Satellite View Toggle Button (Available in MAPS mode)
              if (_currentMode == NavigationMode.maps) ...[
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isSatelliteView = !_isSatelliteView;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isSatelliteView
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isSatelliteView ? Colors.green.shade700 : Colors.black.withValues(alpha: 0.12),
                          width: 1.1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSatelliteView ? Icons.satellite_alt : Icons.map_outlined,
                            color: _isSatelliteView ? Colors.green.shade800 : Colors.black54,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isSatelliteView ? 'Satellite Mode: ON' : 'Satellite Mode: OFF',
                            style: TextStyle(
                              color: _isSatelliteView ? Colors.green.shade800 : Colors.black87,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Colors.black12, height: 1),
              ),

              // Row 3: Indicator Controls (Left, Right, Off)
              Row(
                children: [
                  Expanded(
                    child: _buildControlButton(
                      label: 'Left',
                      icon: Icons.turn_left,
                      color: Colors.teal.shade800,
                      bgColor: Colors.teal.withValues(alpha: 0.12),
                      borderColor: Colors.teal.shade300,
                      onTap: () => BleService.instance.sendCommand('LEFT_ON'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildControlButton(
                      label: 'Right',
                      icon: Icons.turn_right,
                      color: Colors.amber.shade900,
                      bgColor: Colors.amber.withValues(alpha: 0.12),
                      borderColor: Colors.amber.shade400,
                      onTap: () => BleService.instance.sendCommand('RIGHT_ON'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildControlButton(
                      label: 'Off',
                      icon: Icons.power_settings_new,
                      color: Colors.grey.shade800,
                      bgColor: Colors.black.withValues(alpha: 0.05),
                      borderColor: Colors.black26,
                      onTap: () => BleService.instance.sendCommand('ALL_OFF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required NavigationMode mode,
    required Color activeColor,
  }) {
    final isSelected = _currentMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _currentMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : Colors.black.withValues(alpha: 0.12),
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : Colors.black54,
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _bleButtonColor(BleConnectionState state) {
    switch (state) {
      case BleConnectionState.connected:
        return const Color(0xFF34A853); // Green
      case BleConnectionState.scanning:
      case BleConnectionState.connecting:
      case BleConnectionState.reconnecting:
        return const Color(0xFF4285F4); // Blue
      case BleConnectionState.error:
        return const Color(0xFFEA4335); // Red
      case BleConnectionState.bluetoothOff:
        return const Color(0xFFF59E0B); // Amber
      case BleConnectionState.disconnected:
        return Colors.grey.shade600;
    }
  }

  void _onBluetoothTap(BleConnectionState state) {
    switch (state) {
      case BleConnectionState.disconnected:
      case BleConnectionState.error:
        // Start scanning and connect
        BleService.instance.scanAndConnect();
        _showBleSnackbar('Scanning for Roadway...', const Color(0xFF4285F4));
        // Listen for connection success
        _listenForConnectionResult();
        break;

      case BleConnectionState.bluetoothOff:
        // Prompt user to enable Bluetooth, then auto-scan
        _showBleSnackbar(
          'Turn on Bluetooth to connect to Roadway',
          const Color(0xFFF59E0B),
        );
        // Trigger scanAndConnect — it will internally wait for BT to turn on
        BleService.instance.scanAndConnect();
        _listenForConnectionResult();
        break;

      case BleConnectionState.scanning:
      case BleConnectionState.connecting:
        // Cancel scan
        BleService.instance.cancelScan();
        _showBleSnackbar('Scan cancelled', Colors.grey.shade600);
        break;

      case BleConnectionState.connected:
        // Show disconnect dialog
        _showDisconnectDialog();
        break;

      case BleConnectionState.reconnecting:
        // Show reconnecting status
        _showBleSnackbar('Reconnecting to Roadway...', const Color(0xFF4285F4));
        break;
    }
  }

  void _listenForConnectionResult() {
    void listener() {
      final state = BleService.instance.connectionState.value;
      if (state == BleConnectionState.connected) {
        final name = BleService.instance.connectedDeviceName ?? 'Roadway';
        _showBleSnackbar('Connected to $name ✓', const Color(0xFF34A853));
        BleService.instance.connectionState.removeListener(listener);
      } else if (state == BleConnectionState.error) {
        _showBleSnackbar('Connection failed — Roadway device not found', const Color(0xFFEA4335));
        BleService.instance.connectionState.removeListener(listener);
      } else if (state == BleConnectionState.bluetoothOff) {
        _showBleSnackbar('Turn on Bluetooth to connect to Roadway', const Color(0xFFF59E0B));
        BleService.instance.connectionState.removeListener(listener);
      } else if (state == BleConnectionState.disconnected) {
        BleService.instance.connectionState.removeListener(listener);
      }
    }

    BleService.instance.connectionState.addListener(listener);
  }

  Future<bool?> _showQuitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit Navigation?'),
        content: const Text(
          'Are you sure you want to quit navigation and stop indicator signals?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Quit',
              style: TextStyle(
                color: Color(0xFFEA4335),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bluetooth Connection'),
        content: Text(
          'Connected to ${BleService.instance.connectedDeviceName ?? "Roadway"}.\n\nDisconnect?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await BleService.instance.disconnect();
              if (mounted) {
                _showBleSnackbar('Disconnected', Colors.grey.shade600);
              }
            },
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Color(0xFFEA4335)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await BleService.instance.forgetSavedDevice();
              await BleService.instance.disconnect();
              if (mounted) {
                _showBleSnackbar('Device forgotten', Colors.grey.shade600);
              }
            },
            child: const Text(
              'Forget & Disconnect',
              style: TextStyle(color: Color(0xFFEA4335)),
            ),
          ),
        ],
      ),
    );
  }

  void _showBleSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.bluetooth, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  void _updateOrientation() {
    final orientation = WidgetsBinding
                .instance.platformDispatcher.views.first.physicalSize.width >
            WidgetsBinding
                .instance.platformDispatcher.views.first.physicalSize.height
        ? DeviceOrientation.landscapeLeft
        : DeviceOrientation.portraitUp;

    _orientation = orientation;
    setState(() {});
  }
}

/// A simple pulsing icon widget for scanning/connecting states.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;

  const _PulsingIcon({required this.icon});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(widget.icon, color: Colors.white, size: 20),
        );
      },
    );
  }
}
