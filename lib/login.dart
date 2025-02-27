import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

      print("FirebaseAuth User Created: ${newUser.uid}");

      await firestore.collection('users').doc(newUser.uid).set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("Firestore User Document Created!");

      await auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());

      print("User Logged In After Registration!");

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/mainScreen');
      }
    } catch (e) {
      print("Error: $e");
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
      print("FirebaseAuth Error: ${authError.message}");
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
      print("Guest login failed: $e");
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
        title: Center(
          child: Text(
            "Create an Account",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
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
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 20),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text("Register"),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.65,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
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
                        child: Text("Continue as Guest"),
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
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Register Account",
                          style: Theme.of(context).textTheme.titleMedium,
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