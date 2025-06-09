// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // <<< ADD THIS IMPORT for Firestore

import 'create_pin_screen.dart'; // Your PIN creation screen

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _isObscurePassword = true;
  bool _isObscureConfirm = true;
  bool agree = false;
  bool _isLoading = false; // To show loading indicator

  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // <<< ADD THIS for Firestore instance

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Email/Password Sign Up ---
  Future<void> _signUpWithEmailPassword() async {
    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar("Passwords don't match");
      return;
    }
    if (!agree) {
      _showSnackBar("Please agree to terms and privacy policy");
      return;
    }
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showSnackBar("Please fill all fields");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create user with email and password in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // If successful, userCredential.user will not be null
      if (userCredential.user != null) {
        // --- START: ADD FIRESTORE DOCUMENT CREATION HERE ---
        User? user = userCredential.user;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            // 'name' field ko yahan add karna zaroori hai agar aap signup ke waqt name bhi le rahe hain.
            // Example: Agar aapke paas nameTextField hai to
            // 'name': nameController.text.trim(),
            // Agar aap signup me name nahi le rahe, to 'Test User' jaisi default value de sakte hain ya baad me add karein.
            'name': "New User", // Placeholder if you don't collect name during signup
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(), // Initial login time
            'profileImageUrl': '', // Default empty or placeholder URL
            'settings': {
              'currency': 'PKR', // Default currency
              'notificationsEnabled': true, // Default notification setting
            },
          });
    
        }
        // --- END: ADD FIRESTORE DOCUMENT CREATION HERE ---

        _showSnackBar("Sign up successful! Please set your PIN.");

        // Navigate to CreatePinScreen after successful sign-up AND document creation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CreatePinScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = 'Sign up failed: ${e.message}';
      }
  
      _showSnackBar(message);
    } on FirebaseException catch (e) { // <<< CATCH Firestore specific errors
     
      _showSnackBar("Failed to set up user profile: ${e.message}");
    } catch (e) {
     
      _showSnackBar("An unexpected error occurred. Please try again.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB7C196),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Image.asset('image-removebg-preview.png', height: 30), // replace with your logo
              ),
              const SizedBox(height: 10),
              const Text(
                'CASHLY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 12, 12, 12),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Create an account",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Please enter your details",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color.fromARGB(197, 0, 0, 0)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined), // Added icon
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: _isObscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline), // Added icon
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscurePassword = !_isObscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: _isObscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_reset), // Added icon
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscureConfirm = !_isObscureConfirm;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: agree,
                    onChanged: (val) => setState(() => agree = val ?? false),
                    activeColor: const Color.fromARGB(255, 123, 150, 24), // Custom color
                  ),
                  const Expanded(
                    child: Text(
                      "I agree to the Terms of Use and Privacy Policy",
                      style: TextStyle(color: Color.fromARGB(197, 0, 0, 0)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 400,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUpWithEmailPassword, // Disable button while loading
                    style: ElevatedButton.styleFrom(
                      backgroundColor:const Color(0xFF89732B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white) // Show loading spinner
                        : const Text(
                            "NEXT",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color.fromARGB(188, 255, 255, 255),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate to Login Page
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage()));

                  },
                  child: const Text(
                    "Already have an account? Log In",
                    style: TextStyle(color: Color.fromARGB(240, 0, 0, 0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}