import 'package:flutter_test/flutter_test.dart';

import 'package:soulmate/models/chat_model.dart';
import 'package:soulmate/services/chat_ai_service.dart';

void main() {
  group('ChatAiService — local fallback engine', () {
    test('greeting par gender-specific reply aata hai', () {
      final men = ChatAiService.generateReply('hello', true, 'Arjun', 'Sara');
      final women =
          ChatAiService.generateReply('hello', false, 'Arjun', 'Sara');
      expect(men, contains('bhai'));
      expect(women, contains('jaan'));
    });

    test('thakawat par support milta hai', () {
      final men = ChatAiService.generateReply(
          'bhai thak gaya hoon', true, 'Arjun', 'Sara');
      expect(men.toLowerCase(), contains('rest'));
    });

    test('joke ka reply men/women dono alag hai', () {
      final men =
          ChatAiService.generateReply('ek joke sunao', true, 'Arjun', 'Sara');
      final women = ChatAiService
          .generateReply('ek joke sunao', false, 'Arjun', 'Sara');
      expect(men, contains('Santa'));
      expect(women, contains('Pati'));
    });

    test('system prompt persona ke hisaab se badalta hai', () {
      final menPrompt =
          ChatAiService.buildSystemPrompt(isMen: true, menName: 'Arjun', womenName: 'Sara');
      final womenPrompt =
          ChatAiService.buildSystemPrompt(isMen: false, menName: 'Arjun', womenName: 'Sara');
      expect(menPrompt, contains('brother'));
      expect(womenPrompt, contains('girlfriend'));
      expect(menPrompt, contains('Arjun'));
      expect(womenPrompt, contains('Sara'));
    });

    test('bina config (offline) ke getReply fallback se jawab deta hai',
        () async {
      // Na Supabase initialized hai, na API key — pipeline step 3 par
      // land karna chahiye aur koi na koi reply dena chahiye.
      final reply = await ChatAiService.getReply(
        userMessage: 'hello',
        history: const [],
        isMen: true,
        menName: 'Arjun',
        womenName: 'Sara',
        apiKey: '',
      );
      expect(reply, isNotEmpty);
    });
  });

  group('Message model', () {
    test('text message image nahi hai', () {
      final msg = Message(text: 'hi', time: DateTime(2026, 1, 1), isMe: true);
      expect(msg.isImage, isFalse);
      expect(msg.isMe, isTrue);
      expect(msg.replyToText, isNull);
    });

    test('image path par isImage true hota hai', () {
      final msg = Message(
          text: '',
          time: DateTime(2026, 1, 1),
          isMe: false,
          imagePath: 'C:/temp/pic.png');
      expect(msg.isImage, isTrue);
    });
  });
}
