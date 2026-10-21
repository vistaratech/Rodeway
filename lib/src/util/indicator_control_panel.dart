import 'dart:async';
import 'dart:ui';
import 'package:cleadr/src/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A sleek, interactive glassmorphic control panel for manual and automated
/// ESP32 2-Channel Relay Indicator testing and live status feedback.
class IndicatorControlPanel extends StatefulWidget {
  final bool isCompact;
  final VoidCallback? onClose;

  const IndicatorControlPanel({
    super.key,
    this.isCompact = false,
    this.onClose,
  });

  @override
  State<IndicatorControlPanel> createState() => _IndicatorControlPanelState();
}

class _IndicatorControlPanelState extends State<IndicatorControlPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  bool _blinkVisible = true;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _blinkTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) {
        setState(() {
          _blinkVisible = !_blinkVisible;
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BleConnectionState>(
      valueListenable: BleService.instance.connectionState,
      builder: (context, connState, _) {
        return ValueListenableBuilder<String>(
          valueListenable: BleService.instance.activeIndicator,
          builder: (context, activeInd, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: BleService.instance.lastSentCommand,
              builder: (context, lastCmd, _) {
                return _buildPanel(
                  context,
                  connState: connState,
                  activeIndicator: activeInd,
                  lastCommand: lastCmd,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required BleConnectionState connState,
    required String activeIndicator,
    required String? lastCommand,
  }) {
    final isConnected = connState == BleConnectionState.connected;
    final isScanning = connState == BleConnectionState.scanning ||
        connState == BleConnectionState.connecting ||
        connState == BleConnectionState.reconnecting;

    final isLeftActive = activeIndicator == 'LEFT';
    final isRightActive = activeIndicator == 'RIGHT';
    final isAllOff = activeIndicator == 'NONE';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar: Connection status & Quick Connect
              Row(
                children: [
                  // Status dot
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected
                          ? const Color(0xFF10B981)
                          : (isScanning ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                      boxShadow: [
                        if (isConnected)
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isConnected
                          ? 'ESP32 Connected (Relay Ready)'
                          : (isScanning ? 'Connecting to ESP32...' : 'ESP32 Disconnected'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Connect / Reconnect Button
                  if (!isConnected)
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        BleService.instance.scanAndConnect();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF60A5FA).withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isScanning)
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            else
                              const Icon(Icons.bluetooth_searching, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              isScanning ? 'Pairing' : 'Connect',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (widget.onClose != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: widget.onClose,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 10),

              // ── 3 Main Control Buttons: LEFT | ALL OFF | RIGHT ──
              Row(
                children: [
                  // 1. LEFT BUTTON
                  Expanded(
                    child: _buildIndicatorButton(
                      label: 'LEFT',
                      sublabel: 'Relay 1 (D2)',
                      icon: Icons.arrow_back,
                      isActive: isLeftActive,
                      activeColor: const Color(0xFFF59E0B), // Vibrant Amber Indicator Color
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        await BleService.instance.toggleLeft();
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 2. ALL OFF BUTTON
                  Expanded(
                    child: _buildIndicatorButton(
                      label: 'ALL OFF',
                      sublabel: 'Stop Relays',
                      icon: Icons.power_settings_new,
                      isActive: isAllOff,
                      isOffButton: true,
                      activeColor: const Color(0xFFEF4444),
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await BleService.instance.turnOffAll();
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 3. RIGHT BUTTON
                  Expanded(
                    child: _buildIndicatorButton(
                      label: 'RIGHT',
                      sublabel: 'Relay 2 (D3)',
                      icon: Icons.arrow_forward,
                      isActive: isRightActive,
                      activeColor: const Color(0xFFF59E0B), // Vibrant Amber Indicator Color
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        await BleService.instance.toggleRight();
                      },
                    ),
                  ),
                ],
              ),

              if (lastCommand != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Command: $lastCommand',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorButton({
    required String label,
    required String sublabel,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    bool isOffButton = false,
  }) {
    // When active and NOT the off button, apply animated blinking glow
    final isBlinking = isActive && !isOffButton;
    final showGlow = isBlinking ? _blinkVisible : isActive;

    Color bg;
    Color borderCol;
    Color textCol;

    if (isOffButton) {
      if (isActive) {
        bg = const Color(0xFF334155);
        borderCol = Colors.white.withValues(alpha: 0.25);
        textCol = Colors.white;
      } else {
        bg = const Color(0xFF1E293B);
        borderCol = Colors.white.withValues(alpha: 0.1);
        textCol = Colors.white70;
      }
    } else {
      if (isActive) {
        bg = showGlow
            ? activeColor.withValues(alpha: 0.95)
            : activeColor.withValues(alpha: 0.35);
        borderCol = activeColor;
        textCol = showGlow ? Colors.black : Colors.white;
      } else {
        bg = const Color(0xFF334155).withValues(alpha: 0.6);
        borderCol = Colors.white.withValues(alpha: 0.12);
        textCol = Colors.white;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderCol,
              width: isActive ? 2.0 : 1.0,
            ),
            boxShadow: [
              if (isActive && showGlow && !isOffButton)
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.65),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: textCol,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: textCol,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  color: textCol.withValues(alpha: 0.75),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
