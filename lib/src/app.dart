import 'package:cleadr/src/screens/maps.dart';
import 'package:cleadr/src/util/branding.dart';
import 'package:cleadr/src/screens/loading.dart';
import 'package:cleadr/src/screens/loading_failed.dart';
import 'package:cleadr/src/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CleadrApp extends StatefulWidget {
  const CleadrApp({super.key});

  @override
  State<StatefulWidget> createState() => _CleadrAppState();
}

class _CleadrAppState extends State<CleadrApp> {
  bool _isLoading = true;
  bool _isLoadingFailed = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      // App Theme
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: RodewayBrand.primary,
          secondary: Colors.white,
        ),
      ),

      // Cleadr App
      home: Builder(
        builder: (context) {
          return Scaffold(
            resizeToAvoidBottomInset:
                false, // Keyboard overlays instead of pushing the Scaffold()
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _isLoading
                  // Loading / Animated Splash Screen
                  ? const LoadingScreen()
                  : _isLoadingFailed
                      // Loading - Failed Screen
                      ? const LoadingFailedScreen()
                      // Maps Screen
                      : const MapsScreen(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _initServices() async {
    final startTime = DateTime.now();
    bool success = false;

    try {
      // Check all services using navigator context for dialogs
      final BuildContext? navContext = _navigatorKey.currentContext;
      success = await Services.checkAllServices(navContext);
    } catch (e) {
      debugPrint("_initServices Exception: $e");
      success = false;
    }

    // Guarantee minimum splash animation display time (4.0 seconds) for smooth sequence & brand visibility
    final elapsed = DateTime.now().difference(startTime);
    final minDuration = const Duration(milliseconds: 4000);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    if (mounted) {
      setState(() {
        _isLoadingFailed = !success;
        _isLoading = false;
      });
    }
  }
}
