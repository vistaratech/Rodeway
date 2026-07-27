import 'dart:ui';
import 'package:cleadr/src/app.dart';
import 'package:cleadr/src/services/services.dart';
import 'package:cleadr/src/util/branding.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LoadingFailedScreen extends StatelessWidget {
  const LoadingFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Service Statuses
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 80.0,
              horizontal: 36.0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(22.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24.0,
                        spreadRadius: 2.0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      statusRow("🌐", "Internet", Services.serviceStatusesStr[0]),
                      statusRow("🧾", "Terms & Conditions",
                          Services.serviceStatusesStr[1]),
                      statusRow(
                          "🗺️", "Google Maps API", Services.serviceStatusesStr[2]),
                      statusRow("📍", "Location", Services.serviceStatusesStr[3]),
                      statusRow("📷", "Camera", Services.serviceStatusesStr[4]),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Description 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 70.0),
            child: Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                children: [
                  // Multicolor "Rodeway" text
                  ...List.generate('Rodeway'.length, (i) {
                    return TextSpan(
                      text: 'Rodeway'[i],
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                        color: RodewayBrand.letterColors[i],
                      ),
                    );
                  }),
                  TextSpan(
                    style: TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                    text:
                        " requires the access of a few app permissions to work.",
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30.0),

          // Description 2
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 70.0),
            child: Text(
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              "Please try again.",
            ),
          ),
          const SizedBox(height: 50.0),

          // Retry, Settings
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10.0,
            children: [
              // Invisible button for alignment purposes
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.transparent,
                ),
                icon: Icon(
                  color: Colors.transparent,
                  Icons.circle,
                ),
                onPressed: null,
              ),

              // Retry
              IconButton(
                style: IconButton.styleFrom(
                  iconSize: 40.0,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                ),
                icon: Icon(
                  Icons.refresh,
                ),
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const CleadrApp()),
                  (route) => false, // Disable and remove previous screens
                ),
              ),

              // Settings
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  color: Colors.white,
                  Icons.settings,
                ),
                onPressed: () => openAppSettings(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget statusRow(String icon, String label, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon, label
          Text(
            style: TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
            ),
            "$icon  $label",
          ),

          // Status
          Text(
            style: TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
            ),
            status,
          ),
        ],
      ),
    );
  }
}
