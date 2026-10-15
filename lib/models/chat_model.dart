/// Ek single chat message ka model (with reply support).
class Message {
  final String text;
  final DateTime time;

  /// true => maine bheja (right side, green bubble)
  /// false => dusre ne bheja (left side, white bubble)
  final bool isMe;

  /// Agar photo bheji ho toh uska local file path, warna null.
  final String? imagePath;

  /// Agar kisi specific message ka reply ho toh uska quoted text.
  final String? replyToText;

  Message({
    required this.text,
    required this.time,
    required this.isMe,
    this.imagePath,
    this.replyToText,
  });

  /// Photo wala message hai ya nahi.
  bool get isImage => imagePath != null && imagePath!.isNotEmpty;
}

/// Ek chat conversation (ek contact ke saath).
class Chat {
  final String id;
  String name;
  final List<Message> messages;

  int unreadCount;
  bool isOnline;
  bool isPinned;
  bool isMuted;

  Chat({
    required this.id,
    required this.name,
    List<Message>? messages,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isPinned = false,
    this.isMuted = false,
  }) : messages = messages ?? <Message>[];

  Message? get lastMessage => messages.isNotEmpty ? messages.last : null;
}
