// lib/biometric_setup_screen.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore

import 'home_page.dart'; // Navigate to HomePage after biometric setup/skip

class BiometricSetupScreen extends StatefulWidget {
  final String userUid; // User UID receive karein

  const BiometricSetupScreen({super.key, required this.userUid}); // Constructor updated

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _authStatus = '';
  bool _isBiometricAvailable = false; // To check if biometrics are available on device

  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance

  @override
  void initState() {
    super.initState();
    // Debugging: Check if userUid is received correctly
   
    if (widget.userUid.isEmpty) {
      // Handle case where userUid is unexpectedly empty
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackBar("Error: User ID is missing for biometric setup. Please re-login.");
        // Optionally, navigate back to login:
        // Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _checkBiometrics(); // Check for biometric availability on init
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics;
    List<BiometricType> availableBiometrics = [];
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
      if (canCheckBiometrics) {
        availableBiometrics = await auth.getAvailableBiometrics();
      }
     

      setState(() {
        // _isBiometricAvailable = canCheckBiometrics; // Less strict: just hardware support
        _isBiometricAvailable = canCheckBiometrics && availableBiometrics.isNotEmpty; // More strict: hardware support AND enrolled biometrics
      });
    } catch (e) {
      debugPrint("Error checking biometrics: $e");
      setState(() {
        _isBiometricAvailable = false;
      });
    }
  }


  Future<void> _authenticateAndSavePreference(bool enableBiometrics) async {
    // Prevent actions if UID is missing
    if (widget.userUid.isEmpty) {
      _showSnackBar("Operation failed: User ID is missing.");
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _authStatus = ''; // Clear previous status
    });

    try {
      bool authenticated = false;
      if (enableBiometrics) {
        // Only try to authenticate if biometrics are to be enabled
        authenticated = await auth.authenticate(
          localizedReason: 'Use Fingerprint/Face ID to sign in quickly and securely',
          options: const AuthenticationOptions(
            biometricOnly: true, // Force biometric authentication
            useErrorDialogs: true, // Show system-provided error dialogs
            stickyAuth: true, // Keep authentication session active even if app is paused
          ),
        );
       
      } else {
        // If "Not Now" is pressed, consider it authenticated to proceed with saving false
        authenticated = true;
      
      }

      if (authenticated) {
        // Save biometric preference to Firestore
        
        await _firestore.collection('users').doc(widget.userUid).update({
          'biometricsEnabled': enableBiometrics,
        });

        _showSnackBar(enableBiometrics ? "Biometric login set successfully!" : "Biometric setup skipped.");

        // Navigate to Home Page and remove all previous routes
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()), // Go to HomePage
          (Route<dynamic> route) => false, // Remove all previous routes
        );
      } else {
        // If authentication failed (and user wanted to enable biometrics)
        _showSnackBar("Biometric authentication failed. Please try again or skip.");
        setState(() {
          _authStatus = 'Authentication Failed';
        });
      }
    } on FirebaseException catch (e) {
      // Handle Firestore specific errors
      _showSnackBar("Failed to save biometric preference: ${e.message}");
      debugPrint("Firestore Error saving biometrics: ${e.code} - ${e.message}");
      setState(() {
        _authStatus = 'Firestore Error: ${e.message}';
      });
    } catch (e) {
      // Handle any other unexpected errors
      _showSnackBar("An error occurred during biometric setup: $e");
      debugPrint("General Biometric setup error: $e");
      setState(() {
        _authStatus = 'Error: $e';
      });
    } finally {
      setState(() {
        _isAuthenticating = false;
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
    // App ke theme colours ko use karein
    const appPrimaryColor = Color(0xFF89732B); // Jaise previous screens mein tha
    const appBackgroundColor = Color(0xFFB7C196); // Jaise previous screens mein tha

    return Scaffold(
      backgroundColor: appBackgroundColor, // Background color
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon aur app name ko apne app ke hisaab se adjust karein
            const Icon(Icons.lock_open, size: 48, color: appPrimaryColor), // Changed icon
            const SizedBox(height: 8),
            const Text(
              'CASHLY', // Apne app ka naam
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),

            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appPrimaryColor.withOpacity(0.2), // Light background for icon
              ),
              child: const Center(
                child: Icon(
                  Icons.fingerprint, // Fingerprint icon
                  size: 60, // Adjusted size
                  color: appPrimaryColor, // Icon color
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Unlock with Biometrics', // Updated text
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Use biometric authentication for faster, safer, and more convenient access to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800], // Changed color
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                // Button disabled if authenticating or if biometrics are not available
                onPressed: _isAuthenticating || !_isBiometricAvailable
                    ? null
                    : () => _authenticateAndSavePreference(true), // Enable biometrics
                style: ElevatedButton.styleFrom(
                  backgroundColor: appPrimaryColor, // Button color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _isAuthenticating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isBiometricAvailable ? 'Activate Biometrics' : 'Biometrics Not Available',
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 45,
              child: TextButton( // Changed to TextButton as per current style
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent, // Transparent background for 'Not Now'
                  foregroundColor: Colors.black, // Text color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: appPrimaryColor) // Border matching theme
                  ),
                ),
                onPressed: _isAuthenticating ? null : () => _authenticateAndSavePreference(false), // Skip biometrics
                child: const Text(
                  'Not Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_authStatus.isNotEmpty)
              Text(
                _authStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _authStatus.contains('Enabled') || _authStatus.contains('Skipped') ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}