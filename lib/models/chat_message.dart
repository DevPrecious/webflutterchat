class ChatMessage {
  final String id;
  final String message;
  final DateTime timestamp;
  final String senderName;
  final String senderId;
  final String senderAvatar;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.senderName,
    required this.senderId,
    required this.senderAvatar,
    required this.isRead,
  });
}
