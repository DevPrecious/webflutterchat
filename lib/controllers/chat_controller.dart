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
  final searchQuery = ''.obs;
  final isLoading = false.obs;
  final isSearching = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchChats();
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

  Future<void> createOrOpenChat(UserModel otherUser) async {
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
        return participants.contains(otherUser.id);
      });

      String chatId;
      if (existingChat != null) {
        chatId = existingChat.id;
      } else {
        // Create new chat
        final chatRef = await _firestore.collection('chats').add({
          'participants': [currentUser.uid, otherUser.id],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'isRead': true,
        });
        chatId = chatRef.id;
      }

      // Navigate to chat
      Get.toNamed('/chat/$chatId');
    } catch (e) {
      print('Error creating/opening chat: $e');
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
        }
      }
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }
}
