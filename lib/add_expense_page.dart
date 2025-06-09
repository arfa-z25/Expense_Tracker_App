// lib/add_expense_page.dart
import 'package:flutter/material.dart';

// --- Placeholder Screens (Aapko ye files khud banani hongi) ---
// Ye screens tab open hongi jab user buttons par click karega.
// For example:
 import './expense_add/manually.dart';
 import './expense_add/voice.dart' ;
 import './expense_add/scan_add.dart';

class AddExpensePage extends StatelessWidget {
  const AddExpensePage({super.key});

  // Dummy functions for navigation - replace with actual navigation to new screens
  void _navigateToAddManualExpense(BuildContext context) {
     Navigator.push(context, MaterialPageRoute(builder: (_) => const ManuallyAddPage()));
    _showSnackBar(context, 'Add Manually button clicked!');
    // Implement navigation to your manual expense entry screen
  }

  void _navigateToAddVoiceExpense(BuildContext context) {
     Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceAddPage()));
    _showSnackBar(context, 'Add by Voice button clicked!');
    // Implement navigation to your voice expense entry screen
  }

  void _navigateToAddScanExpense(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptScanPage()));
    _showSnackBar(context, 'Add by Scan button clicked!');
    // Implement navigation to your scan expense entry screen
  }

  void _showSnackBar(BuildContext context, String message) {
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
        title: const Text('Add New Expense', style: TextStyle(color: Colors.black)),
        backgroundColor: appBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black), // Back button color
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center the cards vertically
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch cards horizontally
          children: [
            // --- Add Manually Card ---
            _buildExpenseOptionCard(
              context: context,
              icon: Icons.edit_note,
              title: 'Add Manually',
              description: 'Enter expense details yourself.',
              onTap: () => _navigateToAddManualExpense(context),
              primaryColor: appPrimaryColor,
            ),
            const SizedBox(height: 20), // Spacing between cards

            // --- Add by Voice Card ---
            _buildExpenseOptionCard(
              context: context,
              icon: Icons.mic,
              title: 'Add by Voice',
              description: 'Speak your expense details.',
              onTap: () => _navigateToAddVoiceExpense(context),
              primaryColor: appPrimaryColor,
            ),
            const SizedBox(height: 20), // Spacing between cards

            // --- Add by Scan Card ---
            _buildExpenseOptionCard(
              context: context,
              icon: Icons.camera_alt,
              title: 'Add by Scan',
              description: 'Scan receipts or invoices.',
              onTap: () => _navigateToAddScanExpense(context),
              primaryColor: appPrimaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white, // Card background color
      child: InkWell( // Use InkWell for tap effect
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1), // Light background for icon
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: primaryColor),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}