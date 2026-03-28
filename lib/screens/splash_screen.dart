import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../main.dart'; // To access AuthWrapper if needed or just use named route

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _sweepController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _letterSpacingAnimation;
  late Animation<double> _sweepAnimation;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    
    // Main Entry Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Glowing Sweep Animation
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _letterSpacingAnimation = Tween<double>(begin: 8.0, end: 16.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutQuart),
      ),
    );

    _sweepAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _sweepController,
        curve: Curves.linear,
      ),
    );

    _controller.forward();

    // Navigate to next screen
    Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
             );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              const Color(0xFF1E1E2C),
              AppTheme.primaryBlack,
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center Content
            AnimatedBuilder(
              animation: Listenable.merge([_controller, _sweepController]),
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Aidora Text with Sweep Effect
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: const [
                              Colors.white10,
                              Colors.white,
                              Colors.white10,
                            ],
                            stops: [
                              _sweepAnimation.value - 0.2,
                              _sweepAnimation.value,
                              _sweepAnimation.value + 0.2,
                            ],
                          ).createShader(bounds);
                        },
                        child: Text(
                          'Aidora',
                          style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: _letterSpacingAnimation.value,
                            fontFamily: 'Outfit', // High-end font feel
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtle Tagline
                      Text(
                        'COMMUNITY EMPOWERMENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.3),
                          letterSpacing: 4.0,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Minimalist Bottom Progress
            Positioned(
              bottom: 80,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 100,
                  height: 1,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 3000),
                      width: 100 * _controller.value,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryPurple.withValues(alpha: 0.2),
                            AppTheme.primaryPurple,
                            Colors.white.withValues(alpha: 0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
