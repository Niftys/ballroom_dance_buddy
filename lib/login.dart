import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';

void testFirestore() async {
  print("🚀 Attempting Firestore write...");

  try {
    // Ensure Firestore is online
    await FirebaseFirestore.instance.disableNetwork();
    await FirebaseFirestore.instance.enableNetwork();
    print("🔄 Firestore Network Reset.");

    // Force a timeout to detect issues
    await FirebaseFirestore.instance
        .collection('test')
        .add({'message': 'Firestore connected!', 'timestamp': FieldValue.serverTimestamp()})
        .timeout(Duration(seconds: 5), onTimeout: () {
      throw Exception("⚠️ Firestore write timeout! Firestore may be offline or blocked.");
    });

    print("✅ Firestore Write Successful");
  } catch (e) {
    print("❌ Firestore Write Failed: $e");
  } finally {
    print("🛠 Firestore test complete.");
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!mounted) return; // Prevents calling setState if the widget is disposed
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/mainScreen');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerUser(String firstName, String lastName, String email, String password) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      print("🚀 Attempting to register user...");

      // Create user in Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Get the newly created user
      User? user = userCredential.user;
      if (user == null) {
        throw Exception("User creation failed! User is null.");
      }

      print("✅ FirebaseAuth User Created: ${user.uid}");

      // Save user data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("🔥 User saved to Firestore: ${user.uid}");

      // Navigate to the main screen
      if (mounted) {
        print("🔄 Navigating to main screen...");
        Navigator.pushReplacementNamed(context, '/mainScreen');
      }
    } on FirebaseAuthException catch (authError) {
      print("❌ FirebaseAuth Error: ${authError.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Authentication error: ${authError.message}")),
        );
      }
    } on FirebaseException catch (firestoreError) {
      print("❌ Firestore Error: ${firestoreError.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save user data: ${firestoreError.message}")),
        );
      }
    } catch (e) {
      print("❌ Unexpected Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration failed: ${e.toString()}")),
        );
      }
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
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/mainScreen');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Guest login failed: $e")),
        );
      }
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
              _buildTextField(_firstNameController, "First Name", Icons.person),
              SizedBox(height: 8),
              _buildTextField(_lastNameController, "Last Name", Icons.person_outline),
              SizedBox(height: 8),
              _buildTextField(_emailController, "Email", Icons.email),
              SizedBox(height: 8),
              _buildTextField(_passwordController, "Password", Icons.lock, obscureText: true),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("All fields are required!")),
                );
                return;
              }

              await _registerUser(
                _firstNameController.text.trim(),
                _lastNameController.text.trim(),
                _emailController.text.trim(),
                _passwordController.text.trim(),
              );
            },
            child: Text("Register"),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 45),
            ),
          ),
          SizedBox(height: 16),
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        prefixIcon: Icon(icon),
        hintText: "Enter your $label",
      ),
      obscureText: obscureText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/txblogo.svg',
                color: Theme.of(context).colorScheme.secondary,
                width: 150,
                height: 150,
              ),
              SizedBox(height: 16),
              Text("Welcome Back", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text("Please log in, register, or continue as guest", style: TextStyle(fontSize: 16, color: Colors.grey)),
              SizedBox(height: 24),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  hintText: "Enter your email",
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  hintText: "Enter your password",
                ),
                obscureText: true,
              ),
              SizedBox(height: 24),
              _isLoading
                  ? CircularProgressIndicator()
                  : Column(
                children: [
                  ElevatedButton(
                    onPressed: _login,
                    child: Text("Log In", style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loginAsGuest,
                    child: Text("Continue as Guest", style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: _showRegisterDialog,
                    child: Text("Create an account", style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: testFirestore,
                    child: Text("Test Firestore"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}