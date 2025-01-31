import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authController = Get.find<AuthController>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _authController.error.value = 'Passwords do not match';
      return;
    }

    try {
      await _authController.register(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
      );
      Get.offAllNamed('/chat'); // Navigate to chat page if successful
    } catch (e) {
      // Error is already handled in the controller
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => AuthForm(
          title: 'Create Account',
          buttonText: 'Register',
          isLoading: _authController.isLoading.value,
          error: _authController.error.value,
          fields: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => _authController.clearError(),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _authController.clearError(),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _authController.clearError(),
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Confirm your password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _authController.clearError(),
              onSubmitted: (_) => _handleRegister(),
            ),
          ],
          onSubmit: _handleRegister,
          bottomWidget: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already have an account?'),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
