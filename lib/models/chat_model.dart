import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastSenderId;
  final bool isRead;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    required this.isRead,
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastSenderId: map['lastSenderId'] ?? '',
      isRead: map['isRead'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastSenderId': lastSenderId,
      'isRead': isRead,
    };
  }
}
