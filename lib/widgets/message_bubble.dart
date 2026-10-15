import 'dart:io';
import 'package:flutter/material.dart';
import '../models/chat_model.dart';

/// WhatsApp-style compact chat message bubble with swipe-to-reply, long-press selection & 12h AM/PM time.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
    this.onReply,
  });

  String _formatTime(DateTime time) {
    int hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = message.isMe;

    final gradientColors = isMe
        ? (isDark
            ? [const Color(0xFF00A884), const Color(0xFF005C4B)]
            : [const Color(0xFFE2F7CB), const Color(0xFFC8E6C9)])
        : (isDark
            ? [const Color(0xFF202C33), const Color(0xFF1F2C34)]
            : [Colors.white, const Color(0xFFF9F9F9)]);

    final textColor = isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
    final metaColor = isDark ? const Color(0xFF8696A0) : Colors.grey[600];

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(3),
      bottomRight: isMe ? const Radius.circular(3) : const Radius.circular(12),
    );

    return Dismissible(
      key: ValueKey(message.time.toIso8601String() + message.text),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        if (onReply != null) {
          onReply!();
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(
          Icons.reply,
          color: Color(0xFF00A884),
          size: 22,
        ),
      ),
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Container(
          color: isSelected
              ? (isDark
                  ? Colors.teal.withValues(alpha: 0.3)
                  : Colors.teal.withValues(alpha: 0.2))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
              padding: message.isImage
                  ? const EdgeInsets.all(3)
                  : const EdgeInsets.only(
                      left: 10, right: 10, top: 6, bottom: 5),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Compact Quoted Reply Box
                  if (message.replyToText != null &&
                      message.replyToText!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(
                          left: BorderSide(
                            color: isMe
                                ? const Color(0xFF005C4B)
                                : const Color(0xFF00A884),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        message.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (message.isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(message.imagePath!),
                        width: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 220,
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                      ),
                    ),
                  if (message.text.isNotEmpty)
                    Padding(
                      padding: message.isImage
                          ? const EdgeInsets.fromLTRB(6, 6, 6, 2)
                          : EdgeInsets.zero,
                      child: Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 15.5,
                          color: textColor,
                          height: 1.25,
                        ),
                      ),
                    ),
                  const SizedBox(height: 1),
                  Padding(
                    padding: message.isImage
                        ? const EdgeInsets.fromLTRB(6, 1, 6, 2)
                        : EdgeInsets.zero,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.time),
                          style: TextStyle(fontSize: 10.5, color: metaColor),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.done_all,
                            size: 14,
                            color: Color(0xFF53BDEB),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
