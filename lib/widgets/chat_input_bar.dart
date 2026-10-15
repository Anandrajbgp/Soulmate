import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Designdar chat input bar with reply banner preview, text field, and send button.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final bool isMen;
  final String? replyingToText;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;
  final Function(ImageSource) onPickImage;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.isMen,
    this.replyingToText,
    required this.onCancelReply,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F0F0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // WhatsApp style reply preview banner
            if (replyingToText != null && replyingToText!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A3942) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: Color(0xFF00A884), width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Replying to message',
                            style: TextStyle(
                              color: Color(0xFF00A884),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            replyingToText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onCancelReply,
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A3942) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined,
                              color: Colors.grey),
                          onPressed: () {},
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            maxLines: 1,
                            textInputAction: TextInputAction.newline,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.grey),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.attach_file, color: Colors.grey),
                          tooltip: 'Gallery se photo',
                          onPressed: () => onPickImage(ImageSource.gallery),
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.grey),
                          tooltip: 'Camera se photo',
                          onPressed: () => onPickImage(ImageSource.camera),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSend,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00A884), Color(0xFF005C4B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00A884).withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
