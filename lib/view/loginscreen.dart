import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login Successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } on FirebaseAuthException catch (e) {
        String message = "Login failed";
        if (e.code == 'user-not-found') {
          message = "No user found with this email.";
        } else if (e.code == 'wrong-password') {
          message = "Incorrect password.";
        } else if (e.code == 'invalid-email') {
          message = "Invalid email format.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFedf7ee),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade50,
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFd4ffd8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                    width: 90,
                    height: 90,
                    child: const Center(
                      child: Icon(Icons.lock_open,
                          color: Colors.green, size: 48),
                    ),
                  ),
                  const Text(
                    "Welcome Back!",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Login to your NoteNest account",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  // Email field
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: _inputDecoration("Email", Icons.email),
                    validator: (value) =>
                        value == null || value.isEmpty ? "Enter email" : null,
                  ),
                  const SizedBox(height: 16),
                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    style: const TextStyle(color: Colors.black87),
                    decoration: _inputDecoration(
                      "Password",
                      Icons.lock,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hidePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black54,
                        ),
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter password";
                      }
                      if (value.length < 6) {
                        return "Password must be at least 6 characters";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                            const Color(0xFF4ade80)),
                        padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(vertical: 16)),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        elevation: WidgetStateProperty.all(0),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: Color(0xFFbcd2c3),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/signup');
                      },
                      child: const Text(
                        "Don’t have an account? Sign Up",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black54),
      prefixIcon: Icon(icon, color: Colors.black54),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }
}
