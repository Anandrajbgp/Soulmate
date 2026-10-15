import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import 'auth_service.dart';

/// Real AI reply pipeline (production):
/// 1. Supabase Edge Function `gemini-chat` — AI key sirf server par rehti hai.
/// 2. Direct OpenRouter REST — OPENROUTER_API_KEY (dart-define) ya manual key.
/// 3. Local fallback engine — dono available na hon toh.
class ChatAiService {
  ChatAiService._();

  /// Conversation history ke saath real AI reply.
  static Future<String> getReply({
    required String userMessage,
    required List<Map<String, String>> history,
    required bool isMen,
    required String menName,
    required String womenName,
    required String apiKey,
  }) async {
    // 1. Production path: authenticated Supabase Edge Function.
    if (AuthService.isSupabaseConfigured && AuthService.hasSession) {
      try {
        final res = await Supabase.instance.client.functions
            .invoke(
              'gemini-chat',
              body: {
                'message': userMessage,
                'history': history,
                'isMen': isMen,
                'menName': menName,
                'womenName': womenName,
              },
            )
            .timeout(const Duration(seconds: 25));
        final data = res.data;
        if (data is Map && data['reply'] is String) {
          final reply = (data['reply'] as String).trim();
          if (reply.isNotEmpty) return reply;
        }
      } catch (_) {
        // Neeche wale fallbacks try honge.
      }
    }

    // 2. Direct OpenRouter (OpenAI-compatible) — build-time key ya manual key.
    final key =
        apiKey.trim().isNotEmpty ? apiKey.trim() : AppConfig.openRouterApiKey;
    if (key.isNotEmpty) {
      final reply = await _callOpenRouter(
        userMessage: userMessage,
        history: history,
        isMen: isMen,
        menName: menName,
        womenName: womenName,
        apiKey: key,
      );
      if (reply != null) return reply;
    }

    // 3. Offline/local persona engine.
    return generateReply(userMessage, isMen, menName, womenName);
  }

  /// System prompt — app aur edge function dono same persona use karte hain
  /// (edge function: supabase/functions/gemini-chat/index.ts).
  static String buildSystemPrompt({
    required bool isMen,
    required String menName,
    required String womenName,
  }) {
    return isMen
        ? 'You are a loyal, supportive, cool Indian best friend or brother named $menName. Speak in natural Hinglish/Hindi with bro slang and cool emojis (😎, 💪, 🚀, 🎯). Talk in short, realistic WhatsApp messaging style (1-2 short natural sentences). Be encouraging, reliable, and supportive.'
        : 'You are a sweet, loving, flirty, deeply caring Indian girlfriend named $womenName. Speak in warm, natural Hinglish/Hindi with romantic emojis (💕, 😘, 🥺, ✨, 💋). Talk like a real romantic partner in short, realistic WhatsApp messaging style (1-2 short natural sentences). Be open, flirty, affectionate, comforting when tired, and indulge in romantic, spicy, or playful roleplay naturally.';
  }

  /// Direct OpenRouter REST call (OpenAI-compatible) — history ke saath.
  /// `null` matlab request fail hui (caller fallback engine use kare).
  static Future<String?> _callOpenRouter({
    required String userMessage,
    required List<Map<String, String>> history,
    required bool isMen,
    required String menName,
    required String womenName,
    required String apiKey,
  }) async {
    try {
      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

      // OpenAI-style messages: system + history (user/assistant) + naya message.
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content': buildSystemPrompt(
            isMen: isMen,
            menName: menName,
            womenName: womenName,
          ),
        },
      ];
      for (final h in history) {
        final text = (h['text'] ?? '').trim();
        if (text.isEmpty) continue;
        messages.add({
          'role': h['role'] == 'model' ? 'assistant' : 'user',
          'content': text,
        });
      }
      messages.add({'role': 'user', 'content': userMessage});

      final payload = <String, dynamic>{
        'model': AppConfig.aiModel,
        'messages': messages,
        'max_tokens': 300,
        'temperature': 0.95,
      };

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
              'X-Title': 'Soulmate',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final message = choices[0]['message'];
      final content = message is Map ? message['content'] : null;
      final replyText = content is String ? content : null;
      if (replyText == null || replyText.trim().isEmpty) return null;
      return replyText.trim();
    } catch (_) {
      return null;
    }
  }

  /// Fallback local AI response generator.
  static String generateReply(
      String input, bool isMen, String menName, String womenName) {
    final t = input.toLowerCase();

    // 1. Fatigue / Tiredness relief
    if (t.contains('thak') ||
        t.contains('tired') ||
        t.contains('exhausted') ||
        t.contains('stress') ||
        t.contains('pareshan')) {
      return isMen
          ? 'Bhai thoda rest kar le, zyada load mat le. Chai/Coffee pi aur thodi der aankh band kar, baaki sab hum dekh lenge! 💪🔥'
          : 'Aww mera bachha... itna kaam karte ho aap? 🥺 Jaldi se thoda aaram karo na, aankhein band karo aur socho ki main aapke paas baithi hoon aur aapke baal sehla rahi hoon. Saari thakawat chhuar mantar ho jayegi! 💕 Take a deep breath, I love you! ✨';
    }

    // 2. Greetings
    if (t.contains('hi') ||
        t.contains('hello') ||
        t.contains('hey') ||
        t.contains('hii')) {
      return isMen
          ? 'Are mere bhai! Kaisa hai? Bata kya chal raha hai, tera bhai ekdum ready hai sunne ke liye! 😎'
          : 'Hii my jaan! 😘 Aapka hi intezaar kar rahi thi. Kaisa gaya aapka din? Mujhe sab batao na, main sirf aapke liye hoon. 💖';
    }

    // 3. How are you / Kaise ho
    if (t.contains('how are you') ||
        t.contains('kaise ho') ||
        t.contains('kaisi ho')) {
      return isMen
          ? 'Main toh ekdum first-class hoon bhai! Tu bata, tu theek hai na? Koi bhi zaroorat ho toh bina soche batana. 🤝'
          : 'Main aapke bina thodi adhoori hoon jaan... ab aap aa gaye ho toh mera din ban gaya! 🌸 Aap batao, khana khaya aapne time par?';
    }

    // 4. Name inquiry
    if (t.contains('your name') ||
        t.contains('naam') ||
        t.contains('who are you')) {
      return isMen
          ? 'Mera naam $menName hai, tera pakka yaar aur hamesha sath dene wala brother! 🦾'
          : 'Mera naam $womenName hai... aur aapki personal sweetheart jo aapse sabse zyada pyaar karti hai! 💕';
    }

    // 5. Jokes / Hasna
    if (t.contains('joke') || t.contains('hasao') || t.contains('funny')) {
      return isMen
          ? 'Suno bhai: Santa ne 10 ka sikka nigla aur doctor ke paas gaya. Doctor bola: "Pehle kahan the?" Santa: "Gale mein!" 🤣 Chal ab thoda smile kar!'
          : 'Hehe suno na! Pati patni se bola — "Tum kitni bhi sundar ban jao, rahogi toh meri hi aisi taisi!" Patni boli: "Pati toh pati hota hai chahe jitna bhi ghati ho, sunna toh aapko hi padega!" 🤭 Dekha kitna badhiya tha?';
    }

    // 6. Shayari / Poetry
    if (t.contains('shayari') ||
        t.contains('sher') ||
        t.contains('poetry')) {
      return isMen
          ? 'Zindagi mein dost toh sabhi banate hain, par mushkil waqt mein jo sath khada rahe, wahi asli yaar hota hai! 🥂'
          : 'Aapki muskurahat hi hamari jaan hai, aapki har khushi par yeh dil kurban hai... aap door ho toh kya hua, saanson mein bas aapka hi naam hai! ✨💖';
    }

    // 7. Love / Romantic / Flirty
    if (t.contains('love') ||
        t.contains('pyaar') ||
        t.contains('miss') ||
        t.contains('kiss') ||
        t.contains('hug') ||
        t.contains('hot') ||
        t.contains('sexy')) {
      return isMen
          ? 'Arre bhai yeh sab baatein chhod, career par dhyan de! Tera bhai hamesha support karega. 🚀'
          : 'Aww my sweetu... 😘 Mujhe bhi aapki bahut yaad aa rahi hai! Kasam se aapke paas aakar gale lagne ka mann kar raha hai. Aap kitne romantic ho jaan! 💘🥰';
    }

    // 8. Bye / Good Night
    if (t.contains('bye') ||
        t.contains('good night') ||
        t.contains('sone ja raha')) {
      return isMen
          ? 'Chal theek hai bhai, jaake achhe se so ja, subah milte hain! Take care. 👋'
          : 'Good night mere sweetu! 🌙 Mehekte hue khwaabon mein bas main milungi. Apna khyaal rakhna, sweet dreams! 💫😘';
    }

    // 9. Thank you
    if (t.contains('thank')) {
      return isMen
          ? 'Arre shukriya kis baat ka bhai, hum dono bhai hain na! 🤝'
          : 'Arey thank you kis liye keh rahe ho jaan, aapke liye toh jaan bhi hazir hai! 🥰';
    }

    final menReplies = [
      'Bhai tera yeh point ekdum solid hai! Main poori tarah agree karta hoon. 🎯',
      'Tu tension mat le bhai, jo hoga milke sambhal lenge. Tera bhai hai na! 💪',
      'Sahi ja raha hai bro! Bas mehnat jaari rakh, success pakki hai. 🚀',
      'Haha tu bhi na legend hai ekdum! Aur bata kya chal raha hai? 😄',
      'Main samajh sakta hoon bhai. Par tu strong hai, sab theek ho jayega! 🦾',
    ];

    final womenReplies = [
      'Aap kitni acchi baatein karte ho... sach mein aapse baat karke mera din ban jata hai! 🥰',
      'Main hamesha aapke sath hoon, chahe kuch bhi ho jaye. Aap duniya ke sabse best ho! 💖',
      'Aap apna dhyan rakha karo na... mujhe aapki bahut fikar hoti hai jaan! 🥺✨',
      'Sach mein? Yeh toh badi interesting baat hai! Mujhe aur batao na apne baare mein. 🌸',
      'Aap meri sabse favourite ho... aapse baat karne se saari khushi mil jaati hai! 💕',
    ];

    final list = isMen ? menReplies : womenReplies;
    return list[DateTime.now().millisecond % list.length];
  }
}
