import 'dart:async';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/chat_message.dart';
import 'auth_controller.dart';

class ChatController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authController = Get.find<AuthController>();

  final chats = <ChatModel>[].obs;
  final searchResults = <UserModel>[].obs;
  final selectedChat = Rxn<ChatMessage>();
  final messages = <ChatMessage>[].obs;
  final searchQuery = ''.obs;
  final isLoading = false.obs;
  final isSearching = false.obs;
  final otherUser = Rxn<UserModel>();

  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  @override
  void onInit() {
    super.onInit();
    fetchChats();
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    super.onClose();
  }

  void fetchChats() {
    final currentUser = _authController.user.value;
    if (currentUser == null) return;

    isLoading.value = true;
    try {
      _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .listen((snapshot) {
        chats.value = snapshot.docs
            .map((doc) => ChatModel.fromMap(doc.id, doc.data()))
            .toList();
        isLoading.value = false;
      });
    } catch (e) {
      print('Error fetching chats: $e');
      isLoading.value = false;
    }
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      clearSearch();
    } else {
      searchUsers();
    }
  }

  void clearSearch() {
    searchQuery.value = '';
    searchResults.clear();
  }

  Future<void> searchUsers() async {
    if (searchQuery.value.isEmpty) return;

    isSearching.value = true;
    try {
      final currentUser = _authController.user.value;
      if (currentUser == null) return;

      final querySnapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: searchQuery.value)
          .where('name', isLessThan: searchQuery.value + 'z')
          .get();

      searchResults.value = querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .where((user) => user.id != currentUser.uid)
          .toList();
    } catch (e) {
      print('Error searching users: $e');
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> createOrOpenChat(UserModel user) async {
    final currentUser = _authController.user.value;
    if (currentUser == null) return;

    try {
      // Check if chat already exists
      final querySnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      final existingChat = querySnapshot.docs.firstWhereOrNull((doc) {
        final participants = List<String>.from(doc['participants']);
        return participants.contains(user.id);
      });

      String chatId;
      if (existingChat != null) {
        chatId = existingChat.id;
      } else {
        // Create new chat
        final chatRef = await _firestore.collection('chats').add({
          'participants': [currentUser.uid, user.id],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'isRead': true,
        });
        chatId = chatRef.id;
      }

      // Set other user and fetch messages
      otherUser.value = user;
      await openChat(chatId);

      // Create chat message for UI
      final lastMessage = existingChat?['lastMessage'] as String? ?? '';
      final lastMessageTime =
          (existingChat?['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime.now();
      selectedChat.value = ChatMessage(
        id: chatId,
        message: lastMessage,
        timestamp: lastMessageTime,
        senderName: user.name,
        senderId: user.id,
        senderAvatar: user.photoUrl ?? '',
        isRead: existingChat?['isRead'] ?? true,
      );
    } catch (e) {
      print('Error creating/opening chat: $e');
    }
  }

  Future<void> openChat(String chatId) async {
    try {
      // Cancel previous subscription
      await _messagesSubscription?.cancel();

      // Subscribe to messages
      _messagesSubscription = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        messages.value = snapshot.docs.map((doc) {
          final data = doc.data();
          final currentUser = _authController.user.value!;
          final isCurrentUser = data['senderId'] == currentUser.uid;

          return ChatMessage(
            id: doc.id,
            message: data['content'] ?? '',
            timestamp: (data['timestamp'] as Timestamp).toDate(),
            senderName: isCurrentUser ? 'You' : otherUser.value?.name ?? 'User',
            senderId: data['senderId'],
            senderAvatar: isCurrentUser
                ? currentUser.photoURL ?? ''
                : otherUser.value?.photoUrl ?? '',
            isRead: data['isRead'] ?? false,
          );
        }).toList();
      });

      // Mark chat as read
      await markChatAsRead(chatId);
    } catch (e) {
      print('Error opening chat: $e');
    }
  }

  Future<void> sendMessage(String chatId, String content) async {
    final currentUser = _authController.user.value;
    if (currentUser == null) return;

    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      final messageRef = chatRef.collection('messages');

      // Add message
      await messageRef.add({
        'senderId': currentUser.uid,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update chat
      await chatRef.update({
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': currentUser.uid,
        'isRead': false,
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> markChatAsRead(String chatId) async {
    final currentUser = _authController.user.value;
    if (currentUser == null) return;

    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      final chat = await chatRef.get();

      if (chat.exists) {
        final data = chat.data() as Map<String, dynamic>;
        final lastSenderId = data['lastSenderId'] as String;

        if (lastSenderId != currentUser.uid) {
          await chatRef.update({'isRead': true});

          // Also mark all messages as read
          final messagesQuery = await chatRef
              .collection('messages')
              .where('senderId', isNotEqualTo: currentUser.uid)
              .where('isRead', isEqualTo: false)
              .get();

          final batch = _firestore.batch();
          for (final doc in messagesQuery.docs) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit();
        }
      }
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }
}
