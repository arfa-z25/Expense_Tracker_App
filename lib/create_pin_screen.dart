// lib/create_pin_screen.dart
// ignore_for_file: library_private_types_in_public_api, avoid_types_as_parameter_names, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

import 'confirm_pin_screen.dart'; // Your PIN confirmation screen

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  _CreatePinScreenState createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String pin = '';

  // Get the current logged-in user's UID
  // It's safe to assume user is logged in here as they just signed up or logged in.
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (_currentUserUid == null) {
      // This scenario should ideally not happen if the previous screen (signup/login)
      // correctly pushed to this screen only after successful authentication.
      // But adding a check is good for robustness.
      // You might want to navigate back to login or show an error.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: User not logged in. Please log in again.")),
        );
        // Optionally, navigate back to login page:
        // Navigator.of(context).popUntil((route) => route.isFirst); // Or push to LoginPage
      });
    }
  }

  void _onKeyTap(String value) {
    if (pin.length < 6) {
      setState(() => pin += value);
    }
    if (pin.length == 6) {
      // Check if UID is available before navigating
      if (_currentUserUid != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConfirmPinScreen(
              createdPin: pin,
              userUid: _currentUserUid, // Pass the user's UID to ConfirmPinScreen
            ),
          ),
        );
      } else {
        // Handle case where user UID is unexpectedly null
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Could not retrieve user ID. Please try again.")),
        );
      }
    }
  }

  void _onBackspaceTap() {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
      });
    }
  }


  Widget _buildNumberPad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((num) => _buildNumberButton(num)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Empty space or another function button (e.g., biometrics)
            SizedBox(
              width: 80, // Adjust size as needed
              height: 80,
              child: Container(), // Empty container for spacing
            ),
            _buildNumberButton('0'),
            SizedBox(
              width: 80, // Adjust size as needed
              height: 80,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined, size: 30, color: Colors.black),
                onPressed: _onBackspaceTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return Container(
      width: 80, // Size of the button
      height: 80, // Size of the button
      margin: const EdgeInsets.all(8),
      child: ElevatedButton(
        onPressed: () => _onKeyTap(number),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE0E0E0), // Light grey background
          foregroundColor: Colors.black, // Text color
          shape: const CircleBorder(), // Circular button
          padding: EdgeInsets.zero, // Remove default padding
          elevation: 4, // Shadow
        ),
        child: Text(
          number,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB7C196), // Background color
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                const Text(
                  "Create a 6-digit PIN",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "This PIN will be used to secure your transactions.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                6,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: index < pin.length ? const Color(0xFF89732B) : Colors.grey[400], // Filled or empty
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            _buildNumberPad(),
          ],
        ),
      ),
    );
  }
}