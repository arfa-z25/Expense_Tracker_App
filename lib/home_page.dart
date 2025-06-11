// lib/home_page.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, unused_import, avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart'; // For charts
import 'package:intl/intl.dart'; // For date formatting
import 'package:permission_handler/permission_handler.dart'; // For checking gallery permissions
import 'dart:io'; // For File class
import 'dart:convert'; // For Base64 encoding/decoding

// Placeholder screens - make sure these files exist in your 'lib' folder
import 'settings_page.dart';
import 'add_expense_page.dart';
import 'all_expenses_page.dart'; // ADDED: Import the new page

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User profile states
  String? _userProfileImageUrl; // Stores the URL/Base64 string of the user's profile image
  String? _userName; // Stores the user's name
  bool _isLoadingProfile = true; // Indicates if profile data is loading or being updated

  // Expense tracking states
  bool _isDayWise = true; // True for daily view, false for monthly
  List<Expense> _expensesForList = []; // List of expenses to display in the recent list
  List<Expense> _expensesForPieChart = []; // List of expenses specifically for the pie chart
  final int _visibleExpensesCount = 3; // Number of expenses to show on the main page

  // Date/Month selection states for expense filtering
  DateTime _selectedDate = DateTime.now(); // For day-wise filtering
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month); // For month-wise filtering

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load user profile data on app start
    _loadExpenses(); // Load initial expenses for list and pie chart
  }

  /// Loads user data (name and profile image URL/Base64) from Firestore.
  /// Updates the UI with the fetched data.
  Future<void> _loadUserData() async {
    setState(() => _isLoadingProfile = true);
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userProfileImageUrl = userData['profileImageBase64'] ?? userData['profileImageUrl'];
            _userName = userData['name'] ?? 'User';
          });
        } else {
          setState(() {
            _userProfileImageUrl = null;
            _userName = 'New User';
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
      setState(() {
        _userProfileImageUrl = null;
        _userName = 'Guest';
      });
    }
    setState(() => _isLoadingProfile = false);
  }

  /// Handles the process of picking an image from the gallery and uploading it as Base64 to Firestore.
  Future<void> _uploadProfileImage() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android ||
          Theme.of(context).platform == TargetPlatform.iOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          _showSnackBar("Storage permission is required to upload images");
          return;
        }
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) return;

      setState(() {
        _isLoadingProfile = true;
        _userProfileImageUrl = null;
      });

      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showSnackBar("User not logged in");
        setState(() => _isLoadingProfile = false);
        return;
      }

      final file = File(image.path);
      if (!await file.exists()) {
        _showSnackBar("Selected image not found");
        setState(() => _isLoadingProfile = false);
        return;
      }

      final bytes = await file.readAsBytes();

      if (bytes.length > 2 * 1024 * 1024) {
        _showSnackBar("Image too large (max 2MB)");
        setState(() => _isLoadingProfile = false);
        return;
      }

      String base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await _firestore.collection('users').doc(currentUser.uid).set(
        {'profileImageBase64': base64Image},
        SetOptions(merge: true),
      );

      setState(() {
        _userProfileImageUrl = base64Image;
        _isLoadingProfile = false;
      });

      _showSnackBar("Profile image updated successfully!");
    } catch (e) {
      setState(() => _isLoadingProfile = false);
      debugPrint("Error uploading profile image: $e");
      _showSnackBar("Failed to upload image: ${e.toString()}");
    }
  }

  /// Shows a dialog to allow the user to edit their name.
  Future<void> _showEditNameDialog() async {
    TextEditingController nameDialogController = TextEditingController(text: _userName);
    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      _showSnackBar("Please log in to change your name.");
      return;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
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
                    _isLoadingProfile = true;
                  });
                  try {
                    await _firestore.collection('users').doc(currentUser.uid).set(
                      {'name': newName},
                      SetOptions(merge: true),
                    );
                    setState(() {
                      _userName = newName;
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
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Displays a SnackBar message at the bottom of the screen.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Loads real expense data from Firestore based on selected date/month and 'day-wise'/'month-wise' toggle.
  Future<void> _loadExpenses() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _expensesForList = [];
        _expensesForPieChart = [];
      });
      return;
    }

    try {
      // --- Define base query for both list and pie chart ---
      Query baseQuery = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('expenses')
          .orderBy('date', descending: true);

      // --- Fetch expenses for the Recent Expenses list ---
      Query queryForList = baseQuery; // Start with the base query

      if (_isDayWise) {
        DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
        queryForList = queryForList
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      } else {
        DateTime startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        DateTime endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
        queryForList = queryForList
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth));
      }

      QuerySnapshot listSnapshot = await queryForList.get();
      List<Expense> tempExpensesList = listSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Expense(
          category: data['title'] ?? 'Unknown',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          date: (data['date'] as Timestamp).toDate(),
        );
      }).toList();

      // --- Prepare expenses for the Pie Chart based on selected mode ---
      List<Expense> tempExpensesForPieChart = [];

      if (_isDayWise) {
        // Day-wise pie chart shows categories for the selected day
        tempExpensesForPieChart = tempExpensesList;
      } else {
        // Month-wise pie chart shows categories for the selected month
        // We can reuse the expenses already fetched for the list, as they are for the same period
        tempExpensesForPieChart = tempExpensesList; // Use the same filtered list

        // If the list is empty, and we are month wise, the pie chart will show "No Data"
        // If not empty, we need to sum amounts by category within this month
        if (tempExpensesForPieChart.isNotEmpty) {
          Map<String, double> categoryTotals = {};
          for (var expense in tempExpensesForPieChart) {
            categoryTotals.update(expense.category, (value) => value + expense.amount,
                ifAbsent: () => expense.amount);
          }

          // Convert category totals back to Expense objects
          tempExpensesForPieChart = categoryTotals.entries.map((entry) {
            return Expense(
              category: entry.key,
              amount: entry.value,
              date: _selectedMonth, // Use the selected month as the date for consistency
            );
          }).toList();
        }
      }

      setState(() {
        _expensesForList = tempExpensesList;
        _expensesForPieChart = tempExpensesForPieChart;
      });
    } catch (e) {
      debugPrint('Error loading expenses from Firestore: $e');
      _showSnackBar('Failed to load expenses.');
      setState(() {
        _expensesForList = [];
        _expensesForPieChart = [];
      });
    }
  }

  /// Opens a date picker for selecting a specific day (for day-wise expense view).
  Future<void> _pickDay() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadExpenses();
    }
  }

  /// Opens a date picker for selecting a month (for month-wise expense view).
  Future<void> _pickMonth() async {
    final DateTime today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'Select a date in the desired month', // Guide user to select a date in the month
    );
    if (picked != null) {
      // Set to 1st of selected month to correctly represent the month for filtering
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
      _loadExpenses(); // Reload expenses for the newly selected month
    }
  }

  @override
  Widget build(BuildContext context) {
    const appPrimaryColor = Color(0xFF89732B);
    const appBackgroundColor = Color(0xFFB7C196);

    // Calculate total amount for the center of the pie chart
    // This now consistently reflects the total of items shown in the pie chart
    double totalPieChartAmount = _expensesForPieChart.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBackgroundColor,
        elevation: 0,
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: GestureDetector(
            onTap: _isLoadingProfile ? null : _uploadProfileImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  child: _isLoadingProfile
                      ? const CircularProgressIndicator(color: Colors.grey)
                      : (_userProfileImageUrl != null
                              ? ClipOval(
                                  child: _userProfileImageUrl!.startsWith('data:image/')
                                      ? Image.memory(
                                          base64Decode(_userProfileImageUrl!.split(',').last),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            debugPrint('Error decoding Base64 image: $error');
                                            return const Icon(Icons.person, color: Colors.grey);
                                          },
                                        )
                                      : Image.network(
                                          _userProfileImageUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            debugPrint('Error loading network image: $error');
                                            return const Icon(Icons.person, color: Colors.grey);
                                          },
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const CircularProgressIndicator(color: Colors.grey);
                                          },
                                        ),
                                )
                              : const Icon(Icons.person, color: Colors.grey)),
                ),
                if (!_isLoadingProfile)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: GestureDetector(
            onTap: _isLoadingProfile ? null : _showEditNameDialog,
            child: Text(
              _userName ?? 'Guest',
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
            // Row for Day Wise / Month Wise toggle chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Day Wise'),
                  selected: _isDayWise,
                  onSelected: (selected) {
                    setState(() {
                      _isDayWise = true;
                    });
                    _loadExpenses();
                  },
                  selectedColor: appPrimaryColor,
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
                    });
                    _loadExpenses();
                  },
                  selectedColor: appPrimaryColor,
                  labelStyle: TextStyle(
                      color: !_isDayWise ? Colors.white : Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date/Month picker button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isDayWise)
                  OutlinedButton.icon(
                    onPressed: _pickDay,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('dd MMM يَوم').format(_selectedDate)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                if (!_isDayWise)
                  OutlinedButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(DateFormat('MMM سَنَة').format(_selectedMonth)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Pie Chart to visualize expense distribution
            Center(
              child: SizedBox(
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: _getPieChartSections(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 48,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isDayWise ? 'Total for Today' : 'Total for this Month', // Corrected text
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)
                        ),
                        Text(
                          'Rs. ${totalPieChartAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section title for Recent Expenses
            Text(
              _isDayWise ? 'Expenses for ${DateFormat('dd MMM يَوم').format(_selectedDate)}'
                         : 'Expenses for ${DateFormat('MMM سَنَة').format(_selectedMonth)}',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 12),

            // List of recent expenses (limited)
            _expensesForList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No expenses found for this period.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _expensesForList.length > _visibleExpensesCount
                        ? _visibleExpensesCount
                        : _expensesForList.length,
                    itemBuilder: (context, index) {
                      final expense = _expensesForList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        color: Colors.white,
                        child: ListTile(
                          leading: Icon(_getCategoryIcon(expense.category), color: appPrimaryColor),
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
            // "See All Expenses" button
            if (_expensesForList.length > _visibleExpensesCount)
              Center(
                child: TextButton(
                  onPressed: () async {
                    // Pass only the relevant expenses for the list to AllExpensesPage
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllExpensesPage(expenses: _expensesForList),
                      ),
                    );
                    _loadExpenses(); // Reload expenses in case changes were made on AllExpensesPage
                  },
                  child: const Text('See All Expenses'),
                ),
              ),
          ],
        ),
      ),
      // Floating Action Button to add new expenses
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpensePage()));
          _loadExpenses(); // Reload expenses after returning from adding
        },
        backgroundColor: appPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Generates the sections for the Pie Chart based on expense categories.
  List<PieChartSectionData> _getPieChartSections() {
    if (_expensesForPieChart.isEmpty) {
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

    double total = _expensesForPieChart.fold(0.0, (sum, item) => sum + item.amount);

    List<Color> colors = [
      Colors.blueAccent, Colors.redAccent, Colors.greenAccent,
      Colors.purpleAccent, Colors.orangeAccent, Colors.tealAccent,
      Colors.pinkAccent, Colors.amberAccent, Colors.lightBlueAccent,
      Colors.cyanAccent, Colors.limeAccent, Colors.indigoAccent,
      Colors.brown, Colors.deepOrange, Colors.lightGreen, Colors.deepPurple,
      Colors.blueGrey, Colors.lime, Colors.indigo,
    ];
    int colorIndex = 0;

    return _expensesForPieChart.map((expense) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;

      // Decide what text to show on the slice
      String percentage = (expense.amount / total * 100).toStringAsFixed(1);
      String sliceTitle = '$percentage%';

      // Only add category name if the slice is significant enough for text
      if ((expense.amount / total * 100) > 5) { // Only show title if percentage is above 5%
        sliceTitle = '${expense.category}\n$sliceTitle';
      }

      return PieChartSectionData(
        color: color,
        value: expense.amount,
        title: sliceTitle,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  /// Returns an appropriate icon based on the expense category.
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'groceries':
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
      case 'travel':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'bills':
      case 'utilities':
        return Icons.receipt;
      case 'rent':
      case 'home':
        return Icons.home;
      case 'entertainment':
        return Icons.movie;
      case 'clothing':
        return Icons.checkroom;
      case 'health':
      case 'medical':
        return Icons.health_and_safety;
      default:
        return Icons.money;
    }
  }
}

// Simple Expense data model - keep this in home_page.dart or a common file if reused
class Expense {
  final String category;
  final double amount;
  final DateTime date;

  Expense({required this.category, required this.amount, required this.date});
}