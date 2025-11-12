import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Register a new user
  Future<String> registerNewUser(
    String email,
    String name,
    String password,
  ) async {
    String result = "Something went wrong";
    try {
      // 1. Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Save user details in Firestore
      await _firestore.collection("users").doc(userCredential.user!.uid).set({
        "name": name,
        "uid": userCredential.user!.uid,
        "email": email,
        "profileImage": "",
        "pinCode": "",
        "purok": "",
        "barangay": "",
        "city": "",
        "pass": password,
      });

      result = "success";
    } catch (e) {
      result = e.toString();
    }

    return result;
  }
}
