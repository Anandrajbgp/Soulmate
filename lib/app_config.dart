/// Build-time configuration — sabhi secrets `--dart-define` se aati hain,
/// source code me kuch bhi hardcode nahi hota. Example:
///
/// ```sh
/// flutter run `
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co `
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci... `
///   --dart-define=OPENROUTER_API_KEY=sk-or-... `
///   --dart-define=AI_MODEL=meta-llama/llama-3.3-70b-instruct:free `
///   --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
/// ```
///
/// Poori setup guide: `SETUP.md`
class AppConfig {
  AppConfig._();

  /// Supabase project URL (dashboard → Project Settings → API).
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon/publishable public key (safe app me jaane ke liye).
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// OpenRouter API key (openrouter.ai → Keys). Production me yeh key
  /// `supabase/functions/gemini-chat` ke andar server par rakhi jaati hai,
  /// isliye yeh mostly empty rehti hai.
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY');

  /// OpenRouter model id (openrouter.ai/models dekhein). Free default —
  /// paid model ke liye badlein, jaise `openai/gpt-4o-mini`.
  static const String aiModel = String.fromEnvironment('AI_MODEL',
      defaultValue: 'meta-llama/llama-3.3-70b-instruct:free');

  /// Google Cloud → Credentials → OAuth client ID (type: Web application).
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isAiConfigured => openRouterApiKey.isNotEmpty;

  static bool get isGoogleConfigured => googleWebClientId.isNotEmpty;
}
