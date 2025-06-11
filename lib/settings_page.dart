// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';

// Import your PIN screen here. Make sure CreatePinScreen exists!
import 'create_pin_screen.dart';

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
  bool _isPinSet = false;
  String _selectedCurrency = 'PKR';
  final List<String> _currencies = ['PKR', 'USD', 'EUR', 'GBP'];

  bool _canCheckBiometrics = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    await _checkBiometricsAvailability();
    await _loadUserSettings();
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadUserSettings() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _notificationsEnabled = userData['settings']?['notificationsEnabled'] ?? true;
          _biometricsEnabled = userData['biometricsEnabled'] ?? false;
          _isPinSet = userData['userPinHash'] != null && userData['userPinHash'].toString().isNotEmpty;
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
            key: value,
          });
        } else {
          await _firestore.collection('users').doc(user.uid).update({
            'settings.$key': value,
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
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      List<BiometricType> availableBiometrics = [];
      if (canCheck) {
        availableBiometrics = await _localAuth.getAvailableBiometrics();
      }
      setState(() {
        _canCheckBiometrics = canCheck && availableBiometrics.isNotEmpty;
        if (!_canCheckBiometrics) {
          _biometricsEnabled = false;
        }
      });
      if (!_canCheckBiometrics) {
        await _updateSetting('biometricsEnabled', false);
      }
    } catch (e) {
      setState(() {
        _canCheckBiometrics = false;
        _biometricsEnabled = false;
      });
    }
  }

  Future<void> _toggleBiometrics(bool newValue) async {
    if (newValue) {
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
            _biometricsEnabled = true;
          });
          await _updateSetting('biometricsEnabled', true);
        } else {
          _showSnackBar('Biometric authentication failed or cancelled.');
        }
      } catch (e) {
        debugPrint('Biometric authentication error: $e');
        _showSnackBar('Biometric setup failed: $e');
      }
    } else {
      setState(() {
        _biometricsEnabled = false;
      });
      await _updateSetting('biometricsEnabled', false);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    _showSnackBar('Logged out successfully!');
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const appPrimaryColor = Color(0xFF89732B);
    const appBackgroundColor = Color(0xFFB7C196);

    if (_loading) {
      return const Scaffold(
        backgroundColor: appBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                        onChanged: _canCheckBiometrics ? _toggleBiometrics : null,
                        activeColor: appPrimaryColor,
                      ),
                      subtitle: !_canCheckBiometrics
                          ? const Text('Biometrics not available or not configured on this device', style: TextStyle(color: Colors.red))
                          : null,
                    ),
                    const Divider(),
                    // PIN Password Setting
                    ListTile(
                      leading: const Icon(Icons.lock, color: appPrimaryColor),
                      title: Text(_isPinSet ? 'Change PIN Password' : 'Set PIN Password'),
                      trailing: const Icon(Icons.arrow_forward_ios, color: appPrimaryColor, size: 18),
                      onTap: () async {
                        // Yahan par sirf CreatePinScreen() use karein agar aapko isPinSet ka status bhejna nahi hai
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreatePinScreen(),
                          ),
                        );
                        if (result == true) {
                          _loadUserSettings();
                          _showSnackBar('PIN set or changed successfully!');
                        } else if (result == false) {
                          _showSnackBar('PIN operation cancelled.');
                        }
                      },
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
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: const Icon(Icons.account_balance, color: appPrimaryColor),
                title: const Text('Bank Attachment'),
                trailing: const Icon(Icons.arrow_forward_ios, color: appPrimaryColor, size: 18),
                onTap: () {
                  _showSnackBar('Bank attachment feature coming soon!');
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => BankAttachmentPage()));
                },
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