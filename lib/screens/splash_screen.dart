import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

/// The Spark of Connection (लव स्पार्क एनिमेशन) Splash Screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Particles animations
  late Animation<Offset> _p1Animation;
  late Animation<Offset> _p2Animation;

  // Heart & Pulse animations
  late Animation<double> _pulseScaleAnimation;
  late Animation<double> _pulseOpacityAnimation;

  // Logo & Title Zoom/Fade
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Particle 1 moves from Top-Left (-1.5, -1.5) to Center (0, 0)
    _p1Animation = Tween<Offset>(
      begin: const Offset(-1.5, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
    ));

    // Particle 2 moves from Bottom-Right (1.5, 1.5) to Center (0, 0)
    _p2Animation = Tween<Offset>(
      begin: const Offset(1.5, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
    ));

    // Pulse wave & Heart explosion at collision (0.35 to 0.70)
    _pulseScaleAnimation = Tween<double>(begin: 0.1, end: 2.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.70, curve: Curves.easeOutQuad),
      ),
    );

    _pulseOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );

    // Logo & Title Fade-in + Zoom-in (0.50 to 0.85)
    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.85, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.80, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      _navigateToNext();
    });
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            isLoggedIn ? const ChatScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B10), // Deep Navy Black
      body: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                // Ambient Glowing Background Circles
                Positioned.fill(
                  child: CustomPaint(
                    painter: AmbientGlowPainter(progress: _controller.value),
                  ),
                ),

                // Expanding Pulse Ring on Collision (centered)
                if (_controller.value > 0.35)
                  Align(
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: _pulseScaleAnimation.value,
                      child: Opacity(
                        opacity: _pulseOpacityAnimation.value.clamp(0.0, 1.0),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00A884)
                                  .withValues(alpha: 0.8),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00A884)
                                    .withValues(alpha: 0.6),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color: const Color(0xFFFF2A6D)
                                    .withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Particle 1 (Top-Left Neon Cyan Magic Particle)
                if (_controller.value <= 0.45)
                  Align(
                    alignment: Alignment(
                        _p1Animation.value.dx, _p1Animation.value.dy),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00E6FF),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF00E6FF),
                            blurRadius: 20,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Particle 2 (Bottom-Right Neon Pink Magic Particle)
                if (_controller.value <= 0.45)
                  Align(
                    alignment: Alignment(
                        _p2Animation.value.dx, _p2Animation.value.dy),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF2A6D),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFFF2A6D),
                            blurRadius: 20,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Dead Center Heart Vector & Glowing Logo
                if (_controller.value >= 0.45)
                  Align(
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: _logoOpacityAnimation.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Radiant SoulMate Logo (asset photo)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00A884),
                                    Color(0xFFFF2A6D)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF2A6D)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 35,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF00A884)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 35,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'Assets/soulmate_logo.png',
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Glowing "SoulMate AI" Title
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Colors.white,
                                  Color(0xFF00A884),
                                  Color(0xFFFF2A6D)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Text(
                                'SoulMate AI',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Subtitle
                            const Text(
                              'The Spark of Connection',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white60,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'by odlix',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF00A884),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AmbientGlowPainter extends CustomPainter {
  final double progress;

  AmbientGlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00A884).withValues(alpha: 0.15 * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.8));

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF2A6D).withValues(alpha: 0.12 * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.9));

    canvas.drawCircle(center, size.width * 0.8, paint1);
    canvas.drawCircle(center, size.width * 0.9, paint2);
  }

  @override
  bool shouldRepaint(covariant AmbientGlowPainter oldDelegate) => true;
}
