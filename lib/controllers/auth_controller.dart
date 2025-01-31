import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  // Observable user state
  Rxn<User> user = Rxn<User>();

  @override
  void onInit() {
    super.onInit();
    user.bindStream(_auth.authStateChanges());
  }

  String _getRandomAvatar() {
    final seed = DateTime.now().millisecondsSinceEpoch.toString();
    return 'https://api.dicebear.com/7.x/avataaars/svg?seed=$seed';
  }

  Future<bool> login(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('Attempting to login with email: $email'); // Debug print

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print(
          'Login successful for user: ${userCredential.user?.uid}'); // Debug print
      return true;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}'); // Debug print
      switch (e.code) {
        case 'user-not-found':
          error.value = 'No user found with this email.';
          break;
        case 'wrong-password':
          error.value = 'Wrong password provided.';
          break;
        case 'invalid-email':
          error.value = 'Invalid email address.';
          break;
        case 'user-disabled':
          error.value = 'This account has been disabled.';
          break;
        default:
          error.value = 'Firebase Auth Error: ${e.code} - ${e.message}';
      }
      return false;
    } catch (e) {
      print('Unexpected error during login: $e'); // Debug print
      error.value = 'An unexpected error occurred: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('Attempting to register with email: $email'); // Debug print

      // Create user with email and password
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print(
          'User created successfully: ${userCredential.user?.uid}'); // Debug print

      // Generate random avatar
      final photoUrl = _getRandomAvatar();

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Update user profile
      await userCredential.user!.updateDisplayName(name);
      await userCredential.user!.updatePhotoURL(photoUrl);

      print(
          'User profile updated and Firestore document created'); // Debug print
      return true;
    } on FirebaseAuthException catch (e) {
      print(
          'FirebaseAuthException during registration: ${e.code} - ${e.message}'); // Debug print
      switch (e.code) {
        case 'weak-password':
          error.value = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          error.value = 'An account already exists for this email.';
          break;
        case 'invalid-email':
          error.value = 'Invalid email address.';
          break;
        default:
          error.value = 'Firebase Auth Error: ${e.code} - ${e.message}';
      }
      return false;
    } catch (e) {
      print('Unexpected error during registration: $e'); // Debug print
      error.value = 'An unexpected error occurred: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      Get.offAllNamed('/login');
    } catch (e) {
      print('Error during logout: $e'); // Debug print
      error.value = 'Error logging out: $e';
    }
  }

  void clearError() {
    error.value = '';
  }

  bool get isLoggedIn => user.value != null;
}
