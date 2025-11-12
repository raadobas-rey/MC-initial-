import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:act1adobas/view/signupscreen.dart';
import 'package:act1adobas/view/loginscreen.dart';
import 'package:act1adobas/view/homepage.dart';
import 'package:act1adobas/view/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyC6_EW1nsM_7Qy0F-9MDV_FAydyWUEURqI',
        appId: '1:678030113218:android:add55dfadf69b78f5fbe5b',
        messagingSenderId: '522442644558',
        projectId: 'actadobas',
        storageBucket: 'actadobas.firebasestorage.app',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
