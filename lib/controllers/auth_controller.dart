import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Rx<User?> _firebaseUser = Rx<User?>(null);
  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  User? get firebaseUser => _firebaseUser.value;

  @override
  void onInit() {
    super.onInit();
    print('AuthController onInit'); // Debug print
    // Set persistence to LOCAL
    _auth.setPersistence(Persistence.LOCAL);

    // Listen to auth state changes
    _firebaseUser.bindStream(_auth.authStateChanges());
    ever(_firebaseUser, _setInitialScreen);
  }

  void clearError() {
    error.value = '';
  }

  void _setInitialScreen(User? user) async {
    print('Auth state changed: ${user?.uid}'); // Debug print
    if (user != null) {
      // Fetch user data from Firestore
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          this.user.value = UserModel.fromMap(doc.id, doc.data()!);
          print('User data loaded: ${this.user.value?.name}'); // Debug print
        } else {
          print('User document does not exist for ${user.uid}'); // Debug print
        }
      } catch (e) {
        print('Error fetching user data: $e'); // Debug print
        error.value = 'Error fetching user data: $e';
      }
    } else {
      this.user.value = null;
      print('User signed out'); // Debug print
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';
      print('Attempting login for $email'); // Debug print

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        print(
            'Login successful for ${userCredential.user!.uid}'); // Debug print
      }
    } on FirebaseAuthException catch (e) {
      print('Login error: $e'); // Debug print
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
          error.value = 'Login error: ${e.message}';
      }
      rethrow;
    } catch (e) {
      print('Login error: $e'); // Debug print
      error.value = 'An unexpected error occurred';
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final user = UserModel(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          photoUrl: null,
          lastSeen: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(user.toMap());

        this.user.value = user;
      }
    } on FirebaseAuthException catch (e) {
      print('Registration error: $e'); // Debug print
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
          error.value = 'Registration error: ${e.message}';
      }
      rethrow;
    } catch (e) {
      print('Registration error: $e'); // Debug print
      error.value = 'An unexpected error occurred';
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      error.value = '';
      await _auth.signOut();
      user.value = null;
    } catch (e) {
      print('Logout error: $e'); // Debug print
      error.value = 'Error during logout: $e';
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }
}
