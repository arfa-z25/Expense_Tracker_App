// lib/home_page.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'dart:io';

// --- Placeholder Screens (Aapko ye files khud banani hongi) ---
// import 'profile_upload_screen.dart'; // Ab home page se direct navigate nahi hoga
import 'settings_page.dart';
import 'add_expense_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? _userProfileImageUrl;
  String? _userName;
  bool _isLoadingProfile = true; // Added loading state for profile operations
  bool _isDayWise = true;
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadExpenses();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingProfile = true; // Start loading
    });
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userProfileImageUrl = userData['profileImageUrl'];
            _userName = userData['name'] ?? 'User'; // Default name if not found
          });
          debugPrint('DEBUG: Loaded profile image URL: $_userProfileImageUrl');
        } else {
          debugPrint('DEBUG: User document does not exist or is empty.');
          setState(() {
            _userProfileImageUrl = null;
            _userName = 'New User'; // Default for new user
          });
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
        _showSnackBar('Failed to load user data.');
        setState(() {
          _userProfileImageUrl = null;
          _userName = 'Error';
        });
      }
    } else {
      debugPrint('DEBUG: No current user logged in.');
      setState(() {
        _userProfileImageUrl = null;
        _userName = 'Guest';
      });
    }
    setState(() {
      _isLoadingProfile = false; // Stop loading
    });
  }

  void _loadExpenses() {
    // In a real app, you'd fetch this from Firestore based on _isDayWise
    if (_isDayWise) {
      _expenses = [
        Expense(category: 'Food', amount: 50.0, date: DateTime.now()),
        Expense(category: 'Transport', amount: 20.0, date: DateTime.now()),
        Expense(category: 'Shopping', amount: 30.0, date: DateTime.now()),
        Expense(category: 'Bills', amount: 10.0, date: DateTime.now().subtract(const Duration(days: 1))),
      ];
    } else {
      // Month-wise data (dummy)
      _expenses = [
        Expense(category: 'Rent', amount: 500.0, date: DateTime.now()),
        Expense(category: 'Groceries', amount: 150.0, date: DateTime.now().subtract(const Duration(days: 5))),
        Expense(category: 'Utilities', amount: 80.0, date: DateTime.now().subtract(const Duration(days: 10))),
        Expense(category: 'Entertainment', amount: 70.0, date: DateTime.now().subtract(const Duration(days: 15))),
        Expense(category: 'Food', amount: 200.0, date: DateTime.now()),
      ];
    }
    setState(() {}); // Update UI
  }

  // --- Profile Image Upload Logic ---
  Future<void> _uploadProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _isLoadingProfile = true; // Show loading indicator during upload
        // Optionally, show a temporary image or clear the old one
        _userProfileImageUrl = null; // Clear existing image to show progress
      });
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        try {
          File file = File(image.path);
          String filePath = 'profile_images/${currentUser.uid}.jpg'; // Fixed filename for consistent retrieval
          UploadTask uploadTask = _storage.ref().child(filePath).putFile(file);
          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();

          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .set({'profileImageUrl': downloadUrl}, SetOptions(merge: true)); // Use set with merge to update or create

          setState(() {
            _userProfileImageUrl = downloadUrl; // Update UI with new URL
            _isLoadingProfile = false; // Stop loading
            _showSnackBar("Profile image updated successfully!");
          });
        } catch (e) {
          debugPrint("Error uploading profile image: $e");
          _showSnackBar("Failed to upload image. Please try again.");
          // If upload fails, try to reload old data
          _loadUserData(); // Reload to show previous image or default
        }
      } else {
        _showSnackBar("User not logged in.");
        setState(() { _isLoadingProfile = false; });
      }
    } else {
      _showSnackBar("No image selected.");
      setState(() { _isLoadingProfile = false; });
    }
  }

  // --- Edit Name Logic ---
  Future<void> _showEditNameDialog() async {
    TextEditingController nameDialogController = TextEditingController(text: _userName);
    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      _showSnackBar("Please log in to change your name.");
      return;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Your Name'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameDialogController,
                  decoration: const InputDecoration(hintText: "Enter your name"),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                String newName = nameDialogController.text.trim();
                if (newName.isNotEmpty && newName != _userName) {
                  setState(() {
                    _isLoadingProfile = true; // Show loading for name update
                  });
                  try {
                    await _firestore.collection('users').doc(currentUser.uid).set(
                      {'name': newName},
                      SetOptions(merge: true), // Use set with merge
                    );
                    setState(() {
                      _userName = newName; // Update UI
                      _isLoadingProfile = false;
                    });
                    _showSnackBar('Name updated successfully!');
                  } catch (e) {
                    debugPrint('Error updating name: $e');
                    _showSnackBar('Failed to update name. Please try again.');
                    setState(() { _isLoadingProfile = false; });
                  }
                } else {
                   _showSnackBar('Name cannot be empty or same as current.');
                   setState(() { _isLoadingProfile = false; });
                }
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB7C196), // Your app's background color
      appBar: AppBar(
        backgroundColor: const Color(0xFFB7C196), // Match background
        elevation: 0,
        titleSpacing: 0, // Remove default title padding
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: GestureDetector(
            onTap: _isLoadingProfile ? null : _uploadProfileImage, // <-- Avatar click will now directly upload image
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              // Show loading indicator or image
              child: _isLoadingProfile
                  ? const CircularProgressIndicator(color: Colors.grey) // Loading indicator
                  : (_userProfileImageUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _userProfileImageUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Error loading image: $error');
                              return const Icon(Icons.person, color: Colors.grey); // Fallback icon
                            },
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.grey)), // Default icon
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: GestureDetector( // <-- Add GestureDetector for name click
            onTap: _isLoadingProfile ? null : _showEditNameDialog, // Disable click during profile loading
            child: Text(
              _userName ?? 'Guest', // Display user name
              style: const TextStyle(
                  color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              _showSnackBar("Notifications clicked!");
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Day/Month Toggle ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Day Wise'),
                  selected: _isDayWise,
                  onSelected: (selected) {
                    setState(() {
                      _isDayWise = true;
                      _loadExpenses(); // Reload expenses for day-wise
                    });
                  },
                  selectedColor: const Color(0xFF89732B),
                  labelStyle: TextStyle(
                      color: _isDayWise ? Colors.white : Colors.black),
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('Month Wise'),
                  selected: !_isDayWise,
                  onSelected: (selected) {
                    setState(() {
                      _isDayWise = false;
                      _loadExpenses(); // Reload expenses for month-wise
                    });
                  },
                  selectedColor: const Color(0xFF89732B),
                  labelStyle: TextStyle(
                      color: !_isDayWise ? Colors.white : Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Pie Chart for Expense Distribution ---
            Center(
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: _getPieChartSections(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Expense List ---
            const Text(
              'Recent Expenses',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true, // Important for ListView inside SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(), // Disable scrolling for inner list
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final expense = _expenses[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 2,
                  color: Colors.white, // Card background
                  child: ListTile(
                    leading: Icon(_getCategoryIcon(expense.category), color: const Color(0xFF89732B)),
                    title: Text(expense.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('dd-MMM-yyyy').format(expense.date)),
                    trailing: Text(
                      'Rs. ${expense.amount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpensePage()));
        },
        backgroundColor: const Color(0xFF89732B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- Helper for Pie Chart Sections ---
  List<PieChartSectionData> _getPieChartSections() {
    // ... (This method remains unchanged from previous version)
    if (_expenses.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          title: 'No Data',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ];
    }

    Map<String, double> categoryAmounts = {};
    for (var expense in _expenses) {
      categoryAmounts.update(expense.category, (value) => value + expense.amount,
          ifAbsent: () => expense.amount);
    }

    double total = categoryAmounts.values.fold(0, (sum, item) => sum + item);

    List<Color> colors = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.tealAccent,
      Colors.pinkAccent,
    ];
    int colorIndex = 0;

    return categoryAmounts.entries.map((entry) {
      const isTouched = false;
      const double radius = isTouched ? 60 : 50;
      const double fontSize = isTouched ? 16 : 14;

      final color = colors[colorIndex % colors.length];
      colorIndex++;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${(entry.value / total * 100).toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: Text(entry.key, style: const TextStyle(fontSize: 10, color: Colors.black)),
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  // --- Helper for Expense Category Icons ---
  IconData _getCategoryIcon(String category) {
    // ... (This method remains unchanged from previous version)
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'bills':
        return Icons.receipt;
      case 'rent':
        return Icons.home;
      case 'groceries':
        return Icons.local_grocery_store;
      case 'utilities':
        return Icons.lightbulb;
      case 'entertainment':
        return Icons.movie;
      default:
        return Icons.money;
    }
  }
}

// --- Dummy Expense Model ---
class Expense {
  final String category;
  final double amount;
  final DateTime date;

  Expense({required this.category, required this.amount, required this.date});
}