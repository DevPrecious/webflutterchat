import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/chat_list.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ChatController chatController = Get.find<ChatController>();
    final isMobile = MediaQuery.of(context).size.width < 768;
    final TextEditingController messageController = TextEditingController();

    Widget buildChatDetail(ChatMessage chat) {
      return Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (isMobile)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => chatController.selectedChat.value = null,
                    ),
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(chat.senderAvatar),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    chat.senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Chat messages area
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: Obx(() {
                final messages = chatController.messages;
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = message.senderName == 'You';

                    return Align(
                      alignment: isCurrentUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          message.message,
                          style: TextStyle(
                            color: isCurrentUser
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          chatController.sendMessage(chat.id, value.trim());
                          messageController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      if (messageController.text.trim().isNotEmpty) {
                        chatController.sendMessage(
                            chat.id, messageController.text.trim());
                        messageController.clear();
                      }
                    },
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget buildPlaceholder() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Select a chat to start messaging',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return Scaffold(
        body: Obx(() {
          final selectedChat = chatController.selectedChat.value;
          if (selectedChat == null) {
            return ChatList();
          }
          return buildChatDetail(selectedChat);
        }),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Chat list
          SizedBox(
            width: 400,
            child: ChatList(),
          ),
          // Chat detail view
          Expanded(
            child: Obx(() {
              final selectedChat = chatController.selectedChat.value;
              if (selectedChat == null) {
                return buildPlaceholder();
              }
              return buildChatDetail(selectedChat);
            }),
          ),
        ],
      ),
    );
  }
}
