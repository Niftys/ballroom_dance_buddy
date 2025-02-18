import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? errorMessage;

  Future<String> refreshAuthToken(User user) async {
    String? idToken = await user.getIdToken(true);
    print("🔄 Refreshed Auth Token: $idToken");
    return idToken ?? "";
  }

  Future<void> _registerUser(String firstName, String lastName, String email, String password) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? newUser = userCredential.user;
      if (newUser == null) throw Exception("User creation failed!");

      print("✅ FirebaseAuth User Created: ${newUser.uid}");

      // 🔥 Get a fresh Auth Token
      String idToken = await refreshAuthToken(newUser);
      print("🔑 Verified Firebase Auth Token: $idToken");

      // 🔥 Firestore API URL
      final String firestoreURL = "https://firestore.googleapis.com/v1/projects/ballroom-dance-buddy/databases/bdbdb/documents/users";

      final userData = {
        "fields": {
          "firstName": {"stringValue": firstName.trim()},
          "lastName": {"stringValue": lastName.trim()},
          "email": {"stringValue": email.trim()},
          "uid": {"stringValue": newUser.uid},
          "createdAt": {"timestampValue": DateTime.now().toUtc().toIso8601String()}
        }
      };

      // 🔥 Firestore API Request
      final response = await http.post(
        Uri.parse(firestoreURL),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken"
        },
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200) {
        print("🔥 Firestore HTTP Write SUCCESSFUL");
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, '/mainScreen'); // ✅ Move navigation here
        }
      } else {
        print("❌ Firestore HTTP Write FAILED: ${response.body}");
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/mainScreen');
      }
    } catch (e) {
      print("❌ Unexpected Error: $e");
      setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginUser(String email, String password) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/mainScreen');
      }
    } on FirebaseAuthException catch (authError) {
      print("❌ FirebaseAuth Error: ${authError.message}");
      setState(() {
        errorMessage = authError.message;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginAsGuest() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await auth.signInAnonymously();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/mainScreen');
      }
    } catch (e) {
      print("❌ Guest login failed: $e");
      setState(() => errorMessage = "Guest login failed: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRegisterDialog() {
    final _firstNameController = TextEditingController();
    final _lastNameController = TextEditingController();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(child: Text("Create an Account", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _firstNameController, decoration: InputDecoration(labelText: "First Name")),
              SizedBox(height: 8),
              TextField(controller: _lastNameController, decoration: InputDecoration(labelText: "Last Name")),
              SizedBox(height: 8),
              TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email")),
              SizedBox(height: 8),
              TextField(controller: _passwordController, decoration: InputDecoration(labelText: "Password"), obscureText: true),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (_firstNameController.text.isEmpty ||
                  _lastNameController.text.isEmpty ||
                  _emailController.text.isEmpty ||
                  _passwordController.text.isEmpty) {
                setState(() {
                  errorMessage = "All fields are required!";
                });
                return;
              }

              await _registerUser(
                _firstNameController.text.trim(),
                _lastNameController.text.trim(),
                _emailController.text.trim(),
                _passwordController.text.trim(),
              );

              Navigator.pop(context);
            },
            child: Text("Register"),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.65, // 🔥 Limits width to 65% of the screen
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24), // Add vertical padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset("assets/icons/txblogo.svg", width: 150, height: 150, color: Theme.of(context).colorScheme.secondary),
                SizedBox(height: 16),
                Text("Ballroom Dance Buddy", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("Please log in, register, or continue as guest", style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 24),

                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: "Email"),
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 12),

                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: "Password"),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loginUser(_emailController.text, _passwordController.text),
                ),
                SizedBox(height: 24),

                _isLoading
                    ? CircularProgressIndicator()
                    : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _loginUser(_emailController.text, _passwordController.text),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                        child: Text("Log In"),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loginAsGuest,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                        child: Text("Log In as Guest"),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Divider(thickness: 1, color: Colors.grey[400])),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text("or", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        ),
                        Expanded(child: Divider(thickness: 1, color: Colors.grey[400])),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _showRegisterDialog,
                        child: Text(
                          "Register Account",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}