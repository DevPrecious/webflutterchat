import 'dart:async';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart' as model;
import '../models/chat_model.dart';
import '../models/chat_message.dart';
import 'auth_controller.dart' as auth;

class ChatController extends GetxController {
  final _firestore = FirebaseFirestore.instance;
  final _authController = Get.find<auth.AuthController>();

  StreamSubscription? _chatsSubscription;

  final RxList<model.UserModel> chatUsers = <model.UserModel>[].obs;
  final RxList<ChatModel> chats = <ChatModel>[].obs;
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSearching = false.obs;
  final RxList<model.UserModel> searchResults = <model.UserModel>[].obs;
  final Rxn<ChatMessage> selectedChat = Rxn<ChatMessage>();
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final Rxn<model.UserModel> otherUser = Rxn<model.UserModel>();

  @override
  void onInit() {
    super.onInit();
    print('ChatController onInit'); // Debug print

    // Listen to auth changes
    ever(_authController.user, (user) {
      print('Auth changed in ChatController: ${user?.id}'); // Debug print
      if (user != null) {
        fetchChats();
      } else {
        chatUsers.clear();
        chats.clear();
      }
    });

    // Initial fetch if user is already logged in
    if (_authController.user.value != null) {
      print('User already logged in, fetching chats'); // Debug print
      fetchChats();
    }
  }

  @override
  void onClose() {
    _chatsSubscription?.cancel();
    super.onClose();
  }

  Future<void> _addToRecentContacts(String id, String contactId) async {
    try {
      // Get user data first
      final userDoc = await _firestore.collection('users').doc(contactId).get();
      if (!userDoc.exists) {
        print('User $contactId does not exist'); // Debug print
        return;
      }

      final userData = userDoc.data()!;
      final userContactsRef = _firestore
          .collection('users')
          .doc(id)
          .collection('recent_contacts');

      // Add or update contact with user data and timestamp
      await userContactsRef.doc(contactId).set({
        'name': userData['name'],
        'email': userData['email'],
        'photoUrl': userData['photoUrl'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Added contact $contactId to user $id recent contacts'); // Debug print
    } catch (e) {
      print('Error adding to recent contacts: $e');
    }
  }

  void fetchChats() {
    print('Starting fetchChats()'); // Debug print
    final currentUser = _authController.user.value;
    if (currentUser == null) {
      print('No current user!'); // Debug print
      return;
    }

    print('Fetching chats for user: ${currentUser.id}'); // Debug print
    isLoading.value = true;

    try {
      print('Cancelling existing subscription...'); // Debug print
      // Cancel existing subscription
      _chatsSubscription?.cancel();

      print('Setting up recent contacts listener...'); // Debug print
      // Listen to recent contacts
      final recentContactsRef = _firestore
          .collection('users')
          .doc(currentUser.id)
          .collection('recent_contacts');

      print('Recent contacts path: ${recentContactsRef.path}'); // Debug print

      _chatsSubscription = recentContactsRef
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
        (snapshot) async {
          print('Got snapshot from recent_contacts'); // Debug print
          print('Got ${snapshot.docs.length} recent contacts'); // Debug print

          if (snapshot.docs.isEmpty) {
            print('No recent contacts found'); // Debug print
            chatUsers.clear();
            isLoading.value = false;
            return;
          }

          final usersList = <model.UserModel>[];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            print('Processing contact doc: ${doc.id}'); // Debug print
            print('Contact data: $data'); // Debug print

            final user = model.UserModel(
              id: doc.id,
              name: data['name'] ?? '',
              email: data['email'] ?? '',
              photoUrl: data['photoUrl'],
              lastSeen: data['timestamp'] != null
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now(),
            );
            usersList.add(user);
            print('Added user to list: ${user.name}'); // Debug print
          }

          print('Final users list size: ${usersList.length}'); // Debug print
          chatUsers.assignAll(usersList);
          print(
              'Updated chatUsers. New size: ${chatUsers.length}'); // Debug print
          isLoading.value = false;
        },
        onError: (error) {
          print('Error in recent contacts listener: $error'); // Debug print
          isLoading.value = false;
        },
      );

      print('Setting up chats listener...'); // Debug print
      // Also listen to chats for messages
      _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.id)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          print(
              'Got chats snapshot with ${snapshot.docs.length} chats'); // Debug print
          chats.assignAll(snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.id, doc.data()))
              .toList());
        },
        onError: (error) {
          print('Error in chats listener: $error'); // Debug print
        },
      );

      print('Finished setting up listeners'); // Debug print
    } catch (e) {
      print('Error in fetchChats: $e'); // Debug print
      isLoading.value = false;
    }
  }

  Future<void> startChat(model.UserModel user) async {
    final currentUser = _authController.user.value;
    if (currentUser == null) return;

    try {
      print('Creating/opening chat with user: ${user.id}'); // Debug print

      // Add to recent contacts immediately
      await _addToRecentContacts(currentUser.id, user.id);
      await _addToRecentContacts(user.id, currentUser.id);

      // Check if chat already exists
      final querySnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.id)
          .get();

      final existingChat = querySnapshot.docs.firstWhereOrNull((doc) {
        final participants = List<String>.from(doc['participants']);
        return participants.contains(user.id);
      });

      String chatId;
      if (existingChat != null) {
        chatId = existingChat.id;
        print('Found existing chat: $chatId'); // Debug print
      } else {
        // Create new chat
        final chatRef = await _firestore.collection('chats').add({
          'participants': [currentUser.id, user.id],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'isRead': true,
        });
        chatId = chatRef.id;
        print('Created new chat: $chatId'); // Debug print
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

      // Navigate to chat
      Get.toNamed('/chat/$chatId');
    } catch (e) {
      print('Error creating/opening chat: $e');
    }
  }

  Future<void> openChat(String chatId) async {
    try {
      // Cancel previous subscription
      await _chatsSubscription?.cancel();

      // Subscribe to messages
      _chatsSubscription = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        messages.value = snapshot.docs.map((doc) {
          final data = doc.data();
          final currentUser = _authController.user.value!;
          final isCurrentUser = data['senderId'] == currentUser.id;

          return ChatMessage(
            id: doc.id,
            message: data['content'] ?? '',
            timestamp: (data['timestamp'] as Timestamp).toDate(),
            senderName: isCurrentUser ? 'You' : otherUser.value?.name ?? 'User',
            senderId: data['senderId'],
            senderAvatar: isCurrentUser
                ? currentUser.photoUrl ?? ''
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

      // Get chat data to find other participant
      final chatDoc = await chatRef.get();
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final participants = List<String>.from(chatData['participants']);
        final otherUserId =
            participants.firstWhere((id) => id != currentUser.id);

        // Add to recent contacts when sending message
        await _addToRecentContacts(currentUser.id, otherUserId);
        await _addToRecentContacts(otherUserId, currentUser.id);
      }

      // Add message
      await messageRef.add({
        'senderId': currentUser.id,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update chat
      await chatRef.update({
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': currentUser.id,
        'isRead': false,
      });
    } catch (e) {
      print('Error sending message: $e');
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
          .map((doc) => model.UserModel.fromMap(doc.id, doc.data()))
          .where((user) => user.id != currentUser.id)
          .toList();
    } catch (e) {
      print('Error searching users: $e');
    } finally {
      isSearching.value = false;
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

        if (lastSenderId != currentUser.id) {
          await chatRef.update({'isRead': true});

          // Also mark all messages as read
          final messagesQuery = await chatRef
              .collection('messages')
              .where('senderId', isNotEqualTo: currentUser.id)
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
