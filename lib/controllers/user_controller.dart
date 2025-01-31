import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';

class UserController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<UserModel> filteredUsers = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUsers();
    ever(searchQuery, (_) => filterUsers());
  }

  Future<void> fetchUsers() async {
    try {
      isLoading.value = true;
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final QuerySnapshot querySnapshot = await _firestore.collection('users').get();
      
      users.value = querySnapshot.docs
          .where((doc) => doc.id != currentUser.uid) // Exclude current user
          .map((doc) => UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      
      filterUsers();
    } catch (e) {
      print('Error fetching users: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void filterUsers() {
    if (searchQuery.value.isEmpty) {
      filteredUsers.value = users;
      return;
    }

    final query = searchQuery.value.toLowerCase();
    filteredUsers.value = users.where((user) {
      final nameMatch = user.name.toLowerCase().contains(query);
      final emailMatch = user.email.toLowerCase().contains(query);
      return nameMatch || emailMatch;
    }).toList();
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }
}
