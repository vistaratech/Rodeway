import 'package:cleadr/src/util/branding.dart';
import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const LoadingScreen({
    super.key,
    this.onAnimationComplete,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _nameController;
  late AnimationController _letterController;
  late AnimationController _entryController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late Animation<double> _nameOpacity;

  late Animation<double> _entryPulse;
  late Animation<double> _entryOpacity;

  @override
  void initState() {
    super.initState();

    // 1. Logo Animation (0.0s -> 0.8s)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    // 2. Letter-by-letter stagger animation (1.0s)
    _letterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 3. Subtitle / tagline fade-in (after letters finish)
    _nameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _nameOpacity = CurvedAnimation(
      parent: _nameController,
      curve: Curves.easeIn,
    );

    // 3. Entry Animation (1.2s -> repeat pulse)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _entryPulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeInOut,
      ),
    );

    _entryOpacity = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );

    // Run Animation Sequence
    _runAnimationSequence();
  }

  Future<void> _runAnimationSequence() async {
    // Start Logo display
    await _logoController.forward();

    // Start letter-by-letter "Rodeway" animation
    await _letterController.forward();

    // Start subtitle fade-in
    await _nameController.forward();

    // Start Entry animation pulse
    _entryController.repeat(reverse: true);

    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _letterController.dispose();
    _nameController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.05),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Step 1: Animated Logo Display
                AnimatedBuilder(
                  animation: Listenable.merge([_logoController, _entryController]),
                  builder: (context, child) {
                    final scale =
                        _logoScale.value * (_entryController.isAnimating ? _entryPulse.value : 1.0);
                    return Transform.scale(
                      scale: scale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: Container(
                          width: 110,
                          height: 110,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26.0),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 24.0,
                                spreadRadius: 1.0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14.0),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.explore_rounded,
                                size: 64.0,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 36.0),

                // Step 2: Animated "Rodeway" letter-by-letter reveal
                Column(
                  children: [
                    AnimatedRodewayLogoText(
                      controller: _letterController,
                      fontSize: 42.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      shadows: const [
                        Shadow(
                          color: Colors.black12,
                          blurRadius: 10.0,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    FadeTransition(
                      opacity: _nameOpacity,
                      child: const Text(
                        "AI-ENHANCED AR NAVIGATION",
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.0,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 54.0),

                // Step 3: Entry Transition & Loading Indicator
                FadeTransition(
                  opacity: _entryOpacity,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 180.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: LinearProgressIndicator(
                            minHeight: 4.0,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        "Initializing AR Navigation...",
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
