// lib/confirm_pin_screen.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore operations
import 'package:crypto/crypto.dart'; // For hashing the PIN
import 'dart:convert'; // For utf8.encode

import 'biometric_screen.dart'; // Your biometric setup page path

class ConfirmPinScreen extends StatefulWidget {
  final String createdPin;
  final String userUid; // User UID jo CreatePinScreen se aaya hai

  const ConfirmPinScreen({
    super.key, // Changed super.key to Key? key for consistency
    required this.createdPin,
    required this.userUid, // Required userUid now
  });

  @override
  _ConfirmPinScreenState createState() => _ConfirmPinScreenState();
}

class _ConfirmPinScreenState extends State<ConfirmPinScreen> {
  String confirmPin = '';
  bool _isLoading = false; // To show loading indicator

  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance

  // Function to hash the PIN
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin); // Convert PIN to bytes
    final digest = sha256.convert(bytes); // Hash the bytes using SHA-256
    final hashedPin = digest.toString();
    // Debugging: Print the hashed PIN to console
    
    return hashedPin; // Return the hashed PIN as a string
  }

  void _onKeyTap(String value) async {
    if (_isLoading) return; // Prevent input while loading

    if (confirmPin.length < 6) {
      setState(() => confirmPin += value);
    }

    if (confirmPin.length == 6) {
      if (confirmPin == widget.createdPin) {
        // PINs match, now hash and save to Firestore
        setState(() {
          _isLoading = true; // Show loading indicator
        });

        try {
          final String hashedPin = _hashPin(widget.createdPin); // Hash the created PIN

          // Debugging: Check userUid before attempting to update
          
          if (widget.userUid.isEmpty) {
            _showSnackBar("Error: User ID is missing. Please log in again.");
          
            // Optionally, navigate back to login or an error screen
            return;
          }

          // Update the user's document in Firestore with the hashed PIN
          // The collection 'users' and document ID (userUid) should match your Firestore structure
          await _firestore.collection('users').doc(widget.userUid).update({
            'pinHash': hashedPin, // 'pinHash' field will be added/updated
          });

          _showSnackBar("PIN Set Successfully! Now setting up biometrics.");

          // Navigate to BiometricSetupScreen, correctly passing the userUid
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => BiometricSetupScreen(userUid: widget.userUid), // Pass the userUid
            ),
            (Route<dynamic> route) => false, // Remove all previous routes
          );
        } on FirebaseException catch (e) {
          // Catch specific Firebase exceptions
          
          _showSnackBar("Failed to set PIN. Firebase Error: ${e.message ?? 'Unknown error'}.");
        } catch (e) {
          // Catch any other unexpected errors
     
          _showSnackBar("Failed to set PIN. Please try again. Error: $e");
        } finally {
          setState(() {
            _isLoading = false; // Hide loading indicator
          });
        }
      } else {
        // PINs do not match
        _showSnackBar("PINs do not match! Please try again.");
        setState(() => confirmPin = ''); // Clear the entered PIN
      }
    }
  }

  void _onBackspaceTap() {
    if (confirmPin.isNotEmpty) {
      setState(() {
        confirmPin = confirmPin.substring(0, confirmPin.length - 1);
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        onPressed: _isLoading ? null : () => _onKeyTap(number), // Disable button while loading
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
                  "Confirm your 6-digit PIN",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Please re-enter your PIN to confirm.",
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
                    color: index < confirmPin.length ? const Color(0xFF89732B) : Colors.grey[400], // Filled or empty
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF89732B)) // Show loading spinner
                : _buildNumberPad(), // Show number pad when not loading
          ],
        ),
      ),
    );
  }
}