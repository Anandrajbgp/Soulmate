import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../app_config.dart';
import '../models/chat_model.dart';
import '../services/auth_service.dart';
import '../services/chat_ai_service.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/profile_dialog.dart';
import '../widgets/typing_bubble.dart';
import 'login_screen.dart';

/// App ka main screen: Gemini AI API integration, WhatsApp-style selection, specific message reply, 12h AM/PM time, persistence & haptics.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isMen = true;
  String _menName = 'Arjun';
  String _womenName = 'Sara';
  String? _menProfileImagePath;
  String? _womenProfileImagePath;
  String _geminiApiKey = '';
  String _userEmail = '';

  // Per-user chat storage (AuthService.scope se key banti hai).
  String _chatMessagesKey = 'chat_messages';
  bool _legacyChatMigrated = false;
  Timer? _typeTimer;

  final List<Message> _messages = [];
  bool _isTyping = false;
  Timer? _typingTimer;
  Timer? _replyTimer;

  // WhatsApp-style message selection & reply state
  final Set<int> _selectedIndices = {};
  bool get _isSelecting => _selectedIndices.isNotEmpty;
  String? _replyingToText;

  String get _aiName => _isMen ? _menName : _womenName;
  String? get _aiProfileImagePath =>
      _isMen ? _menProfileImagePath : _womenProfileImagePath;

  /// Drawer me dikhane ke liye AI backend ka live status.
  String get _aiBackendLabel {
    if (AuthService.isSupabaseConfigured && AuthService.hasSession) {
      return 'OpenRouter AI • cloud connected';
    }
    if (AppConfig.isAiConfigured || _geminiApiKey.isNotEmpty) {
      return 'OpenRouter AI • connected';
    }
    return 'Offline AI • demo mode';
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences().then((_) {
      if (_messages.isEmpty) {
        _messages.insert(
          0,
          Message(
            text: _isMen
                ? 'Hey! Main $_menName. Bata, kya chal raha hai? 😎'
                : 'Hii! Main $_womenName. Kaise ho aap? 😊',
            time: DateTime.now(),
            isMe: false,
          ),
        );
        _savePreferences();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _replyTimer?.cancel();
    _typeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMen = prefs.getBool('is_men') ?? true;
      _menName = prefs.getString('men_name') ?? 'Arjun';
      _womenName = prefs.getString('women_name') ?? 'Sara';
      _menProfileImagePath = prefs.getString('men_profile_path');
      _womenProfileImagePath = prefs.getString('women_profile_path');
      _geminiApiKey = prefs.getString('gemini_api_key') ?? '';
      _userEmail = prefs.getString('user_email') ?? '';

      // Har account ki chat history alag — koi user doosre ki chat na dekhe.
      _chatMessagesKey = AuthService.chatMessagesKeyOf(prefs);
      final scopedMessages = prefs.getStringList(_chatMessagesKey);
      final savedMessages =
          scopedMessages ?? prefs.getStringList('chat_messages');
      _legacyChatMigrated = scopedMessages == null && savedMessages != null;
      if (savedMessages != null && savedMessages.isNotEmpty) {
        _messages.clear();
        for (final mStr in savedMessages) {
          final parts = mStr.split('|||');
          if (parts.length >= 3) {
            _messages.insert(
              0,
              Message(
                text: parts[0],
                time: DateTime.tryParse(parts[1]) ?? DateTime.now(),
                isMe: parts[2] == 'true',
                imagePath:
                    parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
                replyToText:
                    parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_men', _isMen);
    await prefs.setString('men_name', _menName);
    await prefs.setString('women_name', _womenName);
    await prefs.setString('gemini_api_key', _geminiApiKey);
    if (_menProfileImagePath != null) {
      await prefs.setString('men_profile_path', _menProfileImagePath!);
    } else {
      await prefs.remove('men_profile_path');
    }
    if (_womenProfileImagePath != null) {
      await prefs.setString('women_profile_path', _womenProfileImagePath!);
    } else {
      await prefs.remove('women_profile_path');
    }

    final messageStrings = _messages.reversed.map((m) {
      return '${m.text}|||${m.time.toIso8601String()}|||${m.isMe}|||${m.imagePath ?? ''}|||${m.replyToText ?? ''}';
    }).toList();
    await prefs.setStringList(_chatMessagesKey, messageStrings);
    if (_legacyChatMigrated) {
      // Purani (bina user-scope wali) history ab scoped key par aa chuki hai.
      await prefs.remove('chat_messages');
      _legacyChatMigrated = false;
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _copySelectedMessages() {
    final texts = _selectedIndices
        .map((i) => _messages[i].text)
        .where((t) => t.isNotEmpty)
        .join('\n');
    if (texts.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: texts));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message copied to clipboard')),
      );
    }
    setState(() => _selectedIndices.clear());
  }

  void _deleteSelectedMessages() {
    setState(() {
      final sortedIndices = _selectedIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final i in sortedIndices) {
        if (i < _messages.length) {
          _messages.removeAt(i);
        }
      }
      _selectedIndices.clear();
    });
    _savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selected message(s) deleted')),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _focusNode.requestFocus();

    setState(() {
      _messages.insert(
        0,
        Message(
          text: text,
          time: DateTime.now(),
          isMe: true,
          replyToText: _replyingToText,
        ),
      );
      _controller.clear();
      _replyingToText = null;
    });
    _savePreferences();

    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    _scrollToBottom();
    _scheduleReply(text);
  }

  void _scheduleReply(String userText) {
    _typingTimer?.cancel();
    _replyTimer?.cancel();

    // 5 seconds delay before AI starts replying
    _replyTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;

      // Pichhli ~12 messages bhejo taaki AI ko poora conversation yaad rahe
      // (aur real AI vs local fallback dono context ke saath jawab dein).
      final history = _messages
          .skip(1)
          .take(11)
          .where((m) => m.text.trim().isNotEmpty)
          .toList()
          .reversed
          .map((m) => {'role': m.isMe ? 'user' : 'model', 'text': m.text})
          .toList();

      final fullReply = await ChatAiService.getReply(
        userMessage: userText,
        history: history,
        isMen: _isMen,
        menName: _menName,
        womenName: _womenName,
        apiKey: _geminiApiKey,
      );

      final sentences = fullReply
          .replaceAll('!', '.')
          .replaceAll('?', '.')
          .split('.')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (sentences.isEmpty) {
        sentences.add(fullReply);
      }

      _sendSentenceSequentially(sentences, 0);
    });
  }

  void _sendSentenceSequentially(List<String> sentences, int index) {
    if (!mounted) return;

    if (index >= sentences.length) {
      setState(() => _isTyping = false);
      return;
    }

    setState(() => _isTyping = true);
    _scrollToBottom();

    final delay =
        index == 0 ? const Duration(milliseconds: 1200) : const Duration(milliseconds: 1500);

    _replyTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _isTyping = false);

      final fullSentence = sentences[index] +
          (sentences[index].endsWith('.') ||
                  sentences[index].endsWith('!') ||
                  sentences[index].endsWith('?')
              ? ''
              : '.');

      _typeSentenceCharacterByCharacter(fullSentence, () {
        if (index + 1 < sentences.length) {
          _sendSentenceSequentially(sentences, index + 1);
        }
      });
    });
  }

  void _typeSentenceCharacterByCharacter(
      String text, VoidCallback onComplete) {
    int currentCharIndex = 0;
    final messageTime = DateTime.now();

    setState(() {
      _messages.insert(
        0,
        Message(
          text: '',
          time: messageTime,
          isMe: false,
        ),
      );
    });

    _typeTimer =
        Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (currentCharIndex < text.length) {
        currentCharIndex++;
        setState(() {
          _messages[0] = Message(
            text: text.substring(0, currentCharIndex),
            time: messageTime,
            isMe: false,
          );
        });
        _scrollToBottom();
      } else {
        timer.cancel();
        _savePreferences();
        onComplete();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content:
            const Text('Kya aap saari chat history delete karna chahte hain?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedIndices.clear();
                _replyingToText = null;
                _messages.clear();
                _messages.insert(
                  0,
                  Message(
                    text: _isMen
                        ? 'Hey! Main $_menName. Bata, kya chal raha hai? 😎'
                        : 'Hii! Main $_womenName. Kaise ho aap? 😊',
                    time: DateTime.now(),
                    isMe: false,
                  ),
                );
              });
              _savePreferences();
            },
            child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      resizeToAvoidBottomInset: true,
      backgroundColor:
          isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
      appBar: _isSelecting
          ? AppBar(
              backgroundColor:
                  isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIndices.clear()),
              ),
              title: Text('${_selectedIndices.length}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.reply),
                  tooltip: 'Reply',
                  onPressed: () {
                    if (_selectedIndices.isNotEmpty) {
                      setState(() {
                        _replyingToText =
                            _messages[_selectedIndices.first].text;
                        _selectedIndices.clear();
                      });
                      _focusNode.requestFocus();
                    }
                  },
                ),
                if (_selectedIndices.any((i) => _messages[i].text.isNotEmpty))
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy',
                    onPressed: _copySelectedMessages,
                  ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  onPressed: _deleteSelectedMessages,
                ),
              ],
            )
          : AppBar(
              backgroundColor:
                  isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
              foregroundColor: Colors.white,
              titleSpacing: 16,
              title: InkWell(
                onTap: _showProfileDialog,
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    _buildAvatar(radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _aiName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _isTyping ? 'typing...' : 'online',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  tooltip: 'Video call',
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.white),
                  tooltip: 'Voice call',
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: 'Menu',
                  onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
                ),
              ],
            ),
      endDrawer: _buildMenuDrawer(isDark),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == 0) {
                  return TypingBubble(isDark: isDark);
                }
                final msgIndex = _isTyping ? index - 1 : index;
                final message = _messages[msgIndex];
                final isSelected = _selectedIndices.contains(msgIndex);
                return MessageBubble(
                  message: message,
                  isSelected: isSelected,
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _toggleSelection(msgIndex);
                  },
                  onTap: () {
                    if (_isSelecting) {
                      _toggleSelection(msgIndex);
                    }
                  },
                  onReply: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _replyingToText = message.text;
                    });
                    _focusNode.requestFocus();
                  },
                );
              },
            ),
          ),
          ChatInputBar(
            controller: _controller,
            focusNode: _focusNode,
            isDark: isDark,
            isMen: _isMen,
            replyingToText: _replyingToText,
            onCancelReply: () => setState(() => _replyingToText = null),
            onSend: () {
              _sendMessage();
              _focusNode.requestFocus();
            },
            onPickImage: _pickAndSendImage,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required double radius}) {
    final imagePath = _aiProfileImagePath;
    if (imagePath != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF128C7E),
        backgroundImage: FileImage(File(imagePath)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF128C7E),
      child: Icon(
        _isMen ? Icons.face : Icons.face_3,
        color: Colors.white,
        size: radius,
      ),
    );
  }

  void _showProfileDialog() {
    ProfileDialog.show(
      context: context,
      aiName: _aiName,
      isMen: _isMen,
      initialImagePath: _aiProfileImagePath,
      onSave: (newName, newImagePath) {
        setState(() {
          if (_isMen) {
            _menName = newName;
            _menProfileImagePath = newImagePath;
          } else {
            _womenName = newName;
            _womenProfileImagePath = newImagePath;
          }
        });
        _savePreferences();
      },
      onPickImage: _pickImage,
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final path = await _pickImage(source);
    if (path == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _messages.insert(
        0,
        Message(
          text: '',
          time: DateTime.now(),
          isMe: true,
          imagePath: path,
          replyToText: _replyingToText,
        ),
      );
      _replyingToText = null;
    });
    _savePreferences();
    _focusNode.requestFocus();
    _scrollToBottom();
    _scheduleReply('photo');
  }

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted || status.isLimited) return true;
      if (status.isPermanentlyDenied) {
        if (mounted) _showPermissionSettingsDialog(source);
        return false;
      }
    } else {
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted || photosStatus.isLimited) return true;

      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted || storageStatus.isLimited) return true;

      if (photosStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        if (mounted) _showPermissionSettingsDialog(source);
        return false;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(source == ImageSource.camera
              ? 'Camera permission chahiye photo khinchne ke liye.'
              : 'Gallery permission chahiye photo chunne ke liye.'),
        ),
      );
    }
    return false;
  }

  void _showPermissionSettingsDialog(ImageSource source) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permission chahiye'),
          content: Text(source == ImageSource.camera
              ? 'Camera use karne ke liye Settings mein Camera permission allow karein.'
              : 'Photos use karne ke liye Settings mein Photos/Storage permission allow karein.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('SETTINGS'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _pickImage(ImageSource source) async {
    final granted = await _requestPermission(source);
    if (!granted) return null;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      return picked?.path;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo nahi mili: $e')),
        );
      }
      return null;
    }
  }

  Widget _buildMenuDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              color: isDark ? const Color(0xFF00A884) : const Color(0xFF075E54),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Soulmate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'by odlix',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              offset: const Offset(0, 0),
              color: isDark ? const Color(0xFF2A3942) : Colors.white,
              onSelected: (value) {
                final men = value == 'men';
                if (men != _isMen) {
                  setState(() => _isMen = men);
                  Navigator.pop(context);
                  _savePreferences();
                }
              },
              itemBuilder: (context) => [
                _menuItem('men', 'Men', _isMen, Icons.face),
                _menuItem('women', 'Women', !_isMen, Icons.face_3),
              ],
              child: ListTile(
                leading: const Icon(Icons.wc),
                title: const Text('Chat Mode'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_isMen ? 'Men' : 'Women'),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const Divider(height: 8),
            PopupMenuButton<String>(
              offset: const Offset(0, 0),
              color: isDark ? const Color(0xFF2A3942) : Colors.white,
              onSelected: (value) {
                themeNotifier.value =
                    value == 'dark' ? ThemeMode.dark : ThemeMode.light;
              },
              itemBuilder: (context) {
                final dark = themeNotifier.value == ThemeMode.dark;
                return [
                  _menuItem('light', 'Light', !dark, Icons.light_mode),
                  _menuItem('dark', 'Dark', dark, Icons.dark_mode),
                ];
              },
              child: ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Theme'),
                trailing: ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, _) {
                    final dark = mode == ThemeMode.dark;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(dark ? 'Dark' : 'Light'),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.account_circle, color: Color(0xFF00A884)),
              title: const Text('Account Status'),
              subtitle: Text(
                '${_userEmail.isNotEmpty ? _userEmail : 'Logged in as Guest'}\n$_aiBackendLabel',
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey, height: 1.4),
              ),
            ),
            ListTile(
              leading: Icon(
                _userEmail.isNotEmpty ? Icons.logout : Icons.login,
                color: Colors.orange,
              ),
              title: Text(_userEmail.isNotEmpty ? 'Logout Account' : 'Sign in with Google'),
              onTap: () async {
                Navigator.pop(context);
                // Google + Supabase dono se clean logout. Chat history
                // user ke scope me save rehti hai, login par wahi milegi.
                await AuthService.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Clear Chat',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _clearChat();
              },
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Feedback'),
              subtitle: const Text('team.odlix@gmail.com'),
              onTap: () {
                Navigator.pop(context);
                _sendFeedback();
              },
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    String label,
    bool selected,
    IconData icon,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          if (selected)
            const Icon(Icons.check, size: 20, color: Color(0xFF00A884)),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('About Soulmate'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Soulmate — by odlix',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Yeh app aapko ek AI se baat karne deta hai. Aap apni '
                  'pasand ke hisaab se Men ya Women mode chun sakte hain.',
                ),
                SizedBox(height: 12),
                Text(
                  'Kaise use karein:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('1. Upar-right ☰ menu kholein.\n'
                    '2. "Chat Mode" se Men/Women chunein.\n'
                    '3. "Theme" se Light/Dark badlein.\n'
                    '4. Neeche message likhkar bhejein.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('THEEK HAI'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendFeedback() async {
    final subject = Uri.encodeComponent('Soulmate Feedback');
    final body = Uri.encodeComponent(
        'Hi team odlix,\n\nMera feedback / suggestion yeh hai:\n\n');
    final uri =
        Uri.parse('mailto:team.odlix@gmail.com?subject=$subject&body=$body');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _showEmailFallback();
    } catch (_) {
      if (mounted) _showEmailFallback();
    }
  }

  void _showEmailFallback() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feedback bhejein: team.odlix@gmail.com'),
      ),
    );
  }
}
