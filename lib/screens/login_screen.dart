import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

/// Google Sign-In Screen — native Google dialog → Supabase JWT session.
/// Config missing ho toh clear error snackbar, warna direct ChatScreen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // Native Google dialog → Supabase JWT session (agar configured hai).
      await AuthService.signInWithGoogle();
      if (mounted) _goToChat();
    } on AuthCancelledException {
      // User ne dialog band kiya — chup-chaap wahi rahein.
    } on AuthConfigException catch (e) {
      _showError(e.message);
    } on AuthFailedException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Login fail ho gaya: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB3261E),
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _goToChat() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ChatScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    // Guest session kisi aur user ki identity reuse na kare.
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_photo');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ChatScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B10), // Deep Navy Black
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Radiant SoulMate Logo (asset photo)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A884), Color(0xFFFF2A6D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2A6D).withValues(alpha: 0.5),
                      blurRadius: 35,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00A884).withValues(alpha: 0.4),
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
              const SizedBox(height: 28),

              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Color(0xFF00A884), Color(0xFFFF2A6D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'SoulMate AI',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.8,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              const Text(
                'Connect with your personal AI soulmate',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),

              const Spacer(),

              // Google Sign-In Button
              if (_isLoading)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
                )
              else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _handleGoogleSignIn,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google Logo Icon (G)
                      Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.g_mobiledata,
                                size: 30, color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Guest Option
                TextButton(
                  onPressed: _continueAsGuest,
                  child: const Text(
                    'Continue as Guest',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // Footer Note
              const Text(
                'By signing in, you agree to our Terms & Privacy Policy.\nSoulMate AI • by odlix',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
