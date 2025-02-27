import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    debugPrint("Refreshed Auth Token: $idToken");
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

      debugPrint("FirebaseAuth User Created: ${newUser.uid}");

      await firestore.collection('users').doc(newUser.uid).set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("Firestore User Document Created!");

      await auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());

      debugPrint("User Logged In After Registration!");

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/mainScreen');
      }
    } catch (e) {
      debugPrint("Error: $e");
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
      debugPrint("FirebaseAuth Error: ${authError.message}");

      setState(() {
        if (authError.code == 'user-not-found' ||
            authError.code == 'wrong-password' ||
            authError.code == 'invalid-credential') {
          errorMessage = "Username or password incorrect";
        } else {
          errorMessage = "Login failed: ${authError.message}";
        }
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
      debugPrint("Guest login failed: $e");
      setState(() => errorMessage = "Guest login failed: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    if (email.isEmpty) {
      setState(() {
        errorMessage = "Please enter your email address";
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await auth.sendPasswordResetEmail(email: email.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Password reset link sent to $email"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Password reset error: $e");
      setState(() {
        if (e.code == 'user-not-found') {
          errorMessage = "No account found with this email";
        } else {
          errorMessage = "Couldn't send reset email: ${e.message}";
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter your email address and we'll send you a link to reset your password.",
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: Theme.of(context).textTheme.titleSmall),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPassword(emailController.text);
            },
            child: Text("Send Reset Link"),
          ),
        ],
      ),
    );
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
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  "assets/icons/txblogo.svg",
                  width: 150,
                  height: 150,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Ballroom Dance Buddy",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Please log in, register, or continue as guest",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading, // Disable input when loading
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Password"),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  enabled: !_isLoading, // Disable input when loading
                  onSubmitted: (_) => _loginUser(_emailController.text, _passwordController.text),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                      if (_emailController.text.isNotEmpty) {
                        _resetPassword(_emailController.text);
                      } else {
                        _showForgotPasswordDialog();
                      }
                    },
                    child: Text(
                      "Forgot Password?",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _loginUser(_emailController.text, _passwordController.text),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: const Text("Log In"),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loginAsGuest,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: const Text("Continue as Guest"),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(child: Divider(thickness: 1, color: Colors.grey[400])),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text("or", style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ),
                        Expanded(child: Divider(thickness: 1, color: Colors.grey[400])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => _showRegisterDialog(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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