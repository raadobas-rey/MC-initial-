import 'package:flutter/material.dart';
import '../controller/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  final AuthController _authController = AuthController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      String res = await _authController.registerNewUser(
        _emailController.text.trim(),
        _nameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (res == "success") {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account Created Successfully"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res),
            backgroundColor: Colors.red,
          ),
        );
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
                      child: Icon(Icons.person_add_alt_1,
                          color: Colors.green, size: 48),
                    ),
                  ),
                  const Text(
                    "Create Account",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Quick registration for NoteNest",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration("Full Name", Icons.person),
                    validator: (value) =>
                        value == null || value.isEmpty ? "Enter your name" : null,
                  ),
                  const SizedBox(height: 16),
                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: _inputDecoration("Email", Icons.email),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Enter email";
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
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
                      if (value == null || value.isEmpty) return "Enter password";
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
                        backgroundColor: MaterialStateProperty.all(
                            const Color(0xFF4ade80)), // green
                        padding: MaterialStateProperty.all(
                            const EdgeInsets.symmetric(vertical: 16)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        elevation: MaterialStateProperty.all(0),
                      ),
                      onPressed: _submit,
                      child: const Text(
                        "Sign Up",
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
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text(
                        "Already have an account? Log In",
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
