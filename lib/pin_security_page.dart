// lib/pin_security_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart'; // Import your home page

class PinSecurityPage extends StatefulWidget {
  const PinSecurityPage({super.key});

  @override
  State<PinSecurityPage> createState() => _PinSecurityPageState();
}

class _PinSecurityPageState extends State<PinSecurityPage> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _storedPin; // To store the PIN fetched from Firestore

  @override
  void initState() {
    super.initState();
    _fetchUserPin();
  }

  Future<void> _fetchUserPin() async {
    setState(() {
      _isLoading = true;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _storedPin = userDoc['pinHash'] as String?; // Assuming 'pin' is the field name
          });
          if (_storedPin == null) {
            _showSnackBar("PIN not set. Please set a PIN or contact support.");
            _navigateToHomePage(); // Or handle this case by prompting to set PIN
          }
        } else {
          _showSnackBar("User data not found for PIN check.");
          _navigateToHomePage(); // Fallback
        }
      } else {
        _showSnackBar("No active user found for PIN check.");
        _navigateToHomePage(); // Fallback
      }
    } catch (e) {
      _showSnackBar("Error fetching PIN: $e");
      _navigateToHomePage(); // Fallback
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

  void _verifyPin() {
    if (_pinController.text.isEmpty) {
      _showSnackBar("Please enter your PIN.");
      return;
    }

    if (_pinController.text == _storedPin) {
      _showSnackBar("PIN verified successfully!");
      _navigateToHomePage();
    } else {
      _showSnackBar("Invalid PIN. Please try again.");
    }
  }

  void _navigateToHomePage() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Enter your PIN to continue',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4, // Assuming a 4-digit PIN
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _verifyPin,
                      child: const Text('Verify PIN'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}