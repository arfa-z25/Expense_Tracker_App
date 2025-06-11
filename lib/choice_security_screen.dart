// lib/choice_security_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart'; // Still needed for canCheckBiometrics to check availability
import 'create_pin_screen.dart'; // Your CreatePinScreen
import 'biometric_screen.dart'; // Assuming this is BiometricSetupScreen
import 'intro_page.dart'; // Your IntroScreen (for skip option)

class ChoiceSecurityScreen extends StatefulWidget {
  const ChoiceSecurityScreen({super.key});

  @override
  State<ChoiceSecurityScreen> createState() => _ChoiceSecurityScreenState();
}

class _ChoiceSecurityScreenState extends State<ChoiceSecurityScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isLoading = false; // For showing loading indicators

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    super.dispose();
  }

  /// Saves the user's security choice to Firestore and then navigates.
  /// 'choice' can be 'biometric', 'pin', or 'none'.
  Future<void> _saveSecurityChoiceAndNavigate(String choice) async {
    if (currentUser == null) {
      _showSnackBar('User not logged in. Cannot save security choice.');
      _navigateToIntro(); // Go back to intro if no user is logged in
      return;
    }

    setState(() => _isLoading = true);

    // Data to be stored in the 'securitySettings' sub-field within the user document
    Map<String, dynamic> securitySettings = {'securityChoice': choice};
    // The actual hashed PIN will be stored by CreatePinScreen later if 'pin' is chosen.
    // The actual biometric status will be handled by BiometricSetupScreen.

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({'securitySettings': securitySettings}, SetOptions(merge: true));

      _showSnackBar('Security preference saved!');

      // Navigate based on choice after successfully saving the preference
      if (choice == 'biometric') {
        // ✅ Pass the userUid to BiometricSetupScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BiometricSetupScreen(userUid: currentUser!.uid),
          ),
        );
      } else if (choice == 'pin') {
        // CreatePinScreen will handle saving the hashed PIN itself
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CreatePinScreen()),
        );
      } else { // 'none'
        _navigateToIntro();
      }
    } catch (e) {
      debugPrint('Error saving security choice: $e');
      _showSnackBar('Failed to save security choice. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Handles the user's choice to enable biometric.
  /// First, it checks for biometric availability, then saves the preference, then navigates.
  Future<void> _handleBiometricChoice() async {
    setState(() => _isLoading = true);
    try {
      final bool canAuthenticate = await auth.canCheckBiometrics;
      if (!canAuthenticate) {
        _showSnackBar('No biometric features available or enabled on this device.');
        setState(() => _isLoading = false); // Stop loading if not available
        return;
      }
      // If biometrics are available, proceed to save choice and navigate to setup screen.
      await _saveSecurityChoiceAndNavigate('biometric');
    } catch (e) {
      debugPrint('Biometric check error: $e');
      _showSnackBar('Error checking biometric availability.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Navigates to the IntroScreen and removes all previous routes.
  void _navigateToIntro() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const IntroScreen()),
      (Route<dynamic> route) => false,
    );
  }

  /// Displays a SnackBar message at the bottom of the screen.
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Secure your financial data!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Add an extra layer of security (PIN or Biometric) when opening the app?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _handleBiometricChoice, // Triggers biometric check and navigation
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Enable Biometric Lock'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _saveSecurityChoiceAndNavigate('pin'), // Saves choice and navigates to CreatePinScreen
                    icon: const Icon(Icons.lock),
                    label: const Text('Set PIN Lock'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _saveSecurityChoiceAndNavigate('none'), // Saves choice and navigates to IntroScreen
                    child: const Text('Skip for Now'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}