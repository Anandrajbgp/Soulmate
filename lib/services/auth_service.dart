import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

/// Build config bhoolne par aane wali error (missing dart-define etc).
class AuthConfigException implements Exception {
  AuthConfigException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// User ne Google dialog par sign-in cancel kiya — ye error nahi hai.
class AuthCancelledException implements Exception {}

/// Sign-in fail hua (network / OAuth / Supabase server error).
class AuthFailedException implements Exception {
  AuthFailedException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Production Google Sign-In:
/// native Google dialog → (agar Supabase configured) Supabase JWT session →
/// local profile save. Chat screen isi session se Gemini edge function
/// ko securely call karta hai.
class AuthService {
  AuthService._();

  /// `main()` me `Supabase.initialize` success ke baad hi `true` hota hai.
  static bool supabaseReady = false;

  static bool get isSupabaseConfigured =>
      AppConfig.isSupabaseConfigured && supabaseReady;

  static bool get hasSession =>
      isSupabaseConfigured &&
      Supabase.instance.client.auth.currentSession != null;

  static GoogleSignIn _googleClient() => GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConfig.googleWebClientId.isEmpty
            ? null
            : AppConfig.googleWebClientId,
      );

  /// Google se sign-in + Supabase session.
  /// Errors UI ko `Auth*Exception` ke roop me milte hain, guest fallback
  /// sirf tab chalta hai jab user khud "Continue as Guest" choose kare.
  static Future<void> signInWithGoogle() async {
    if (!AppConfig.isGoogleConfigured) {
      throw AuthConfigException(
        'Google Sign-In abhi configured nahi hai — build ke waqt '
        '--dart-define=GOOGLE_WEB_CLIENT_ID=... pass karein (SETUP.md dekhein).',
      );
    }

    final google = _googleClient();
    GoogleSignInAccount? account;
    try {
      account = await google.signIn();
    } catch (e) {
      final raw = e.toString();
      if (raw.contains('sign_in_canceled') ||
          raw.contains('kSignInCanceledError') ||
          raw.contains('ApiException: 12501')) {
        // 12501 = user ne dialog par cancel kiya.
        throw AuthCancelledException();
      }
      throw AuthFailedException(explainGoogleError(raw));
    }
    if (account == null) throw AuthCancelledException();

    String? idToken;
    String? accessToken;
    try {
      final tokens = await account.authentication;
      idToken = tokens.idToken;
      accessToken = tokens.accessToken;
    } catch (_) {
      // Tokens sirf Supabase flow ke liye zaroori hain.
    }

    if (isSupabaseConfigured) {
      if (idToken == null || idToken.isEmpty) {
        throw AuthConfigException(
          'Google ID token nahi mila — GOOGLE_WEB_CLIENT_ID (Web client ID) '
          'sahi set hai ya nahi check karein (SETUP.md).',
        );
      }
      try {
        final res = await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        if (res.session == null) {
          throw AuthFailedException(
            'Supabase session nahi bana — dashboard me Google provider '
            'enable hai ya nahi check karein.',
          );
        }
      } on AuthFailedException {
        rethrow;
      } on Exception catch (e) {
        throw AuthFailedException('Supabase login fail ho gaya: $e');
      }
    }

    final user =
        isSupabaseConfigured ? Supabase.instance.client.auth.currentUser : null;
    final uid = user?.id ?? account.id;
    final email = user?.email ?? account.email;
    final name = user?.userMetadata?['full_name']?.toString() ??
        account.displayName ??
        'User';
    final photo = user?.userMetadata?['avatar_url']?.toString() ??
        account.photoUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_id', uid);
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', name);
    if (photo != null) {
      await prefs.setString('user_photo', photo);
    } else {
      await prefs.remove('user_photo');
    }
  }

  /// Google + Supabase dono se logout. Chat history user ke scope me rehti
  /// hai, isliye dobara login karne par wahi wapas mil jayegi.
  static Future<void> signOut() async {
    try {
      if (isSupabaseConfigured) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}
    try {
      await _googleClient().signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_photo');
  }

  /// Current user ke liye chat history prefs key (guest = 'guest').
  static String chatMessagesKeyOf(SharedPreferences prefs) {
    final uid = prefs.getString('user_id') ?? '';
    final email = prefs.getString('user_email') ?? '';
    final scope =
        uid.isNotEmpty ? uid : (email.isNotEmpty ? email : 'guest');
    return 'chat_messages|$scope';
  }

  /// Google ke cryptic error codes ko actionable message me badalta hai
  /// taaki user ko pata chale kya theek karna hai.
  static String explainGoogleError(String raw) {
    // Message format device/plugin ke hisaab se badalta hai — isliye
    // case-insensitive + alag-alag format dono check karte hain.
    final e = raw.toLowerCase();
    bool codeIs(int c) =>
        e.contains('apiexception: $c') || e.contains('statuscode $c');

    if (codeIs(10)) {
      return 'Google Sign-In config match nahi kar rahi (error 10). '
          'Check: (1) GOOGLE_WEB_CLIENT_ID = WEB application wala client ID '
          'hona chahiye (Android wala nahi!), (2) Google Console → '
          'Credentials me Android client: package "com.odlix.soulmate" + '
          'SHA-1 D5:6B:93:B1:14:E3:EA:59:86:A3:2F:07:BC:B7:41:33:4B:75:EF:40 '
          'exact hon, (3) value me quotes/spaces na hon, (4) credentials '
          'banane ke 5-10 min wait karein. Guide: SETUP.md';
    }
    if (codeIs(12500) || codeIs(7)) {
      return 'Google login complete nahi hua — device me Google account '
          'theek se add hai ya nahi check karein, phir retry karein.';
    }
    if (e.contains('network_error') || e.contains('network error')) {
      return 'Internet nahi hai — Google sign-in ke liye network chahiye.';
    }
    return 'Google Sign-In fail ho gaya: $raw';
  }
}
