// lib/biometric_security_page.dart
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'home_page.dart'; // Import your home page

class BiometricSecurityPage extends StatefulWidget {
  const BiometricSecurityPage({super.key});

  @override
  State<BiometricSecurityPage> createState() => _BiometricSecurityPageState();
}

class _BiometricSecurityPageState extends State<BiometricSecurityPage> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
    } catch (e) {
      canCheckBiometrics = false;
      _showSnackBar("Error checking biometrics: $e");
    }

    if (!mounted) return;

    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
    });

    if (_canCheckBiometrics) {
      _authenticateWithBiometrics(); // Automatically try to authenticate if available
    } else {
      _showSnackBar("Biometrics not available or not set up on this device.");
      // Option: Offer a fallback to PIN or direct to home page
      _navigateToHomePage(); // For now, direct to home if biometrics not available
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    bool authenticated = false;
    setState(() {
      _isAuthenticating = true;
    });

    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access your account',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep the authentication UI on screen until dismissed or authenticated
          biometricOnly: true, // Only allow biometric authentication
        ),
      );
    } catch (e) {
      _showSnackBar("Error during biometric authentication: $e");
    } finally {
      setState(() {
        _isAuthenticating = false;
      });
    }

    if (!mounted) return;

    if (authenticated) {
      _showSnackBar("Biometric authentication successful!");
      _navigateToHomePage();
    } else {
      _showSnackBar("Biometric authentication failed or cancelled.");
      // User cancelled or failed. You might want to allow them to retry or offer an alternative login method.
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      appBar: AppBar(title: const Text('Biometric Authentication')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isAuthenticating)
                const CircularProgressIndicator()
              else if (_canCheckBiometrics)
                Column(
                  children: [
                    const Text(
                      'Authenticate with your fingerprint or face ID to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _authenticateWithBiometrics,
                      icon: const Icon(Icons.fingerprint), // or Icons.face
                      label: const Text('Authenticate'),
                    ),
                  ],
                )
              else
                const Text(
                  'Biometric authentication is not available or configured on this device. Please log in using another method.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}