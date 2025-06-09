// lib/settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For logout
import 'package:cloud_firestore/cloud_firestore.dart'; // For user settings
import 'package:local_auth/local_auth.dart'; // For biometric settings

// Import your login page if you want to navigate there on logout
// import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _notificationsEnabled = true;
  bool _biometricsEnabled = false;
  String _selectedCurrency = 'PKR';
  final List<String> _currencies = ['PKR', 'USD', 'EUR', 'GBP']; // Example currencies

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _checkBiometricsAvailability();
  }

  Future<void> _loadUserSettings() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _notificationsEnabled = userData['settings']?['notificationsEnabled'] ?? true;
          _biometricsEnabled = userData['biometricsEnabled'] ?? false; // Top level field
          _selectedCurrency = userData['settings']?['currency'] ?? 'PKR';
        });
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        if (key == 'biometricsEnabled') {
          await _firestore.collection('users').doc(user.uid).update({
            key: value, // Biometrics is a top-level field
          });
        } else {
          // For nested settings
          await _firestore.collection('users').doc(user.uid).update({
            'settings.$key': value, // Using dot notation for nested fields
          });
        }
        _showSnackBar('$key updated successfully!');
      } catch (e) {
        debugPrint('Error updating setting $key: $e');
        _showSnackBar('Failed to update $key. Please try again.');
      }
    }
  }

  Future<void> _checkBiometricsAvailability() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    List<BiometricType> availableBiometrics = [];
    if (canCheckBiometrics) {
      availableBiometrics = await _localAuth.getAvailableBiometrics();
    }
    if (!canCheckBiometrics || availableBiometrics.isEmpty) {
      // If biometrics not available or not enrolled, disable biometrics option
      if (mounted) {
        setState(() {
          _biometricsEnabled = false; // Force disable if not supported
        });
      }
      _updateSetting('biometricsEnabled', false); // Update Firestore
    }
  }

  Future<void> _toggleBiometrics(bool newValue) async {
    if (newValue) {
      // Try to authenticate
      try {
        bool authenticated = await _localAuth.authenticate(
          localizedReason: 'Enable biometrics for quick login',
          options: const AuthenticationOptions(
            biometricOnly: true,
            useErrorDialogs: true,
            stickyAuth: true,
          ),
        );
        if (authenticated) {
          setState(() {
            _biometricsEnabled = newValue;
          });
          await _updateSetting('biometricsEnabled', newValue);
        } else {
          _showSnackBar('Biometric authentication failed.');
        }
      } catch (e) {
        debugPrint('Biometric authentication error: $e');
        _showSnackBar('Biometric setup failed: $e');
      }
    } else {
      // Simply disable if toggle is off
      setState(() {
        _biometricsEnabled = newValue;
      });
      await _updateSetting('biometricsEnabled', newValue);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    _showSnackBar('Logged out successfully!');
    // Navigate to Login Page or Splash Screen
    // Navigator.pushAndRemoveUntil(
    //   context,
    //   MaterialPageRoute(builder: (_) => const LoginPage()), // Replace LoginPage
    //   (Route<dynamic> route) => false,
    // );
    // For now, just pop to ensure state is clear
    Navigator.of(context).pop();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const appPrimaryColor = Color(0xFF89732B);
    const appBackgroundColor = Color(0xFFB7C196);

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.black)),
        backgroundColor: appBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications, color: appPrimaryColor),
                      title: const Text('Enable Notifications'),
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: (newValue) {
                          setState(() {
                            _notificationsEnabled = newValue;
                          });
                          _updateSetting('notificationsEnabled', newValue);
                        },
                        activeColor: appPrimaryColor,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.fingerprint, color: appPrimaryColor),
                      title: const Text('Enable Biometric Login'),
                      trailing: Switch(
                        value: _biometricsEnabled,
                        onChanged: _toggleBiometrics, // Uses biometric authentication
                        activeColor: appPrimaryColor,
                      ),
                      subtitle: !_biometricsEnabled && !(_localAuth.canCheckBiometrics as bool)
                          ? const Text('Biometrics not available on this device', style: TextStyle(color: Colors.red))
                          : null,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.currency_pound, color: appPrimaryColor),
                      title: const Text('Currency'),
                      trailing: DropdownButton<String>(
                        value: _selectedCurrency,
                        items: _currencies.map((String currency) {
                          return DropdownMenuItem<String>(
                            value: currency,
                            child: Text(currency),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCurrency = newValue;
                            });
                            _updateSetting('currency', newValue);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: Colors.white,
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}