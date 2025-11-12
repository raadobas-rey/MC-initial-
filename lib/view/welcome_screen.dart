import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFedf7ee),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFd4ffd8),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  margin: const EdgeInsets.only(bottom: 36),
                  width: 180,
                  height: 180,
                  child: Center(
                    child: Image.asset(
                      'lib/assets/icons/notenest_green.png',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const Text(
                  'NoteNest',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Stay Organized and Never Miss a Beat with NoteNest',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 40),
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
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/signup');
                    },
                    child: const Text(
                      'Sign up for free',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(
                        color: Color(0xFFbcd2c3),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
