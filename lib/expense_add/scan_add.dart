// lib/receipt_scan_page.dart
// ignore_for_file: use_build_context_synchronously, prefer_interpolation_to_compose_strings

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore
import 'package:permission_handler/permission_handler.dart'; // For permission handling

class ReceiptScanPage extends StatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  State<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends State<ReceiptScanPage> {
  String _extractedText = '';
  File? _image;
  final ImagePicker _picker = ImagePicker();

  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Extracted data fields (Title, Date, Amount)
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController(); // Renamed from _descriptionController for clarity

  @override
  void dispose() {
    _textRecognizer.close();
    _dateController.dispose();
    _amountController.dispose();
    _titleController.dispose(); // Dispose the renamed controller
    super.dispose();
  }

  /// Handles picking an image from camera or gallery and initiates text recognition.
  Future<void> _pickImage(ImageSource source) async {
    // Request camera or gallery permission based on source
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      status = await Permission.photos.request();
    }

    if (!status.isGranted) {
      _showSnackBar("Permission denied. Cannot pick image.");
      return;
    }

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _extractedText = ''; // Clear previous text
        _dateController.clear();
        _amountController.clear();
        _titleController.clear(); // Clear the renamed controller
        _isProcessing = true; // Set processing to true before recognition
      });
      await _recognizeText(_image!);
    }
  }

  /// Performs text recognition on the given image file.
  Future<void> _recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      setState(() {
        _extractedText = recognizedText.text;
        _isProcessing = false; // Stop processing after recognition
        _parseExtractedText(recognizedText.text); // Parse and set controllers
      });
    } catch (e) {
      setState(() {
        _extractedText = 'Error recognizing text: $e';
        _isProcessing = false; // Stop processing on error
      });
      _showSnackBar('Error recognizing text: ${e.toString()}');
    }
  }

  /// Parses the extracted text to find date, amount, and a suitable description/title.
  void _parseExtractedText(String text) {
    // --- Date Parsing ---
    // Updated regex to be more flexible with delimiters and month formats (e.g., JAN, FEB)
    RegExp dateRegex = RegExp(
        r'\b(?:\d{1,2}[-\/\.]\d{1,2}[-\/\.]\d{2,4})|(?:\d{4}[-\/\.]\d{1,2}[-\/\.]\d{1,2})|(?:\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{2,4})\b',
        caseSensitive: false);

    String? foundDate;
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      String dateString = dateMatch.group(0)!;
      List<DateFormat> formats = [
        DateFormat('yyyy-MM-dd'),
        DateFormat('yyyy/MM/dd'),
        DateFormat('yyyy.MM.dd'),
        DateFormat('MM-dd-yyyy'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('dd-MM-yyyy'),
        DateFormat('dd/MM/yyyy'),
        DateFormat('MM-dd-yy'),
        DateFormat('MM/dd/yy'),
        DateFormat('dd-MM-yy'),
        DateFormat('dd/MM/yy'),
        DateFormat('d MMM yyyy'), // Added for '1 Jan 2023'
        DateFormat('dd MMM yyyy'),
        DateFormat('d MMM yy'),
        DateFormat('dd MMM yy'),
      ];

      DateTime? parsedDateTime;
      for (var format in formats) {
        try {
          parsedDateTime = format.parseStrict(dateString);
          break;
        } catch (_) {
          // Continue to the next format if parsing fails
        }
      }

      if (parsedDateTime != null) {
        foundDate = DateFormat('yyyy-MM-dd').format(parsedDateTime);
      } else {
        // Fallback: if no strict format matches, try to use the raw string
        foundDate = dateString;
      }
    } else {
      // If no date is found, use today's date as a default
      foundDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    // --- **Improved Amount Parsing (Prioritize "Total")** ---
    double? foundAmount;

    // Regex to explicitly look for "Total" amounts first
    // It captures numbers possibly with comma thousands separators and two decimal places.
    RegExp totalAmountRegex = RegExp(
      r'(?:total|grand\s*total|amount\s*due|net|balance)\s*[:\s]*[\$€£Rs]*\s*(\d{1,3}(?:[,\s]\d{3})*(?:[\.,]\d{2}))',
      caseSensitive: false,
      multiLine: true,
    );

    // Look for a specific "Total" match
    final totalMatch = totalAmountRegex.firstMatch(text);
    if (totalMatch != null && totalMatch.group(1) != null) {
      String amountString = totalMatch.group(1)!
          .replaceAll(',', '') // Remove commas
          .replaceAll(' ', ''); // Remove spaces
      foundAmount = double.tryParse(amountString);
      if (foundAmount != null && foundAmount > 0) { // Ensure it's a valid positive amount
        // If a valid total is found, use it and exit this part
      } else {
        foundAmount = null; // Reset if it was parsed as 0 or null
      }
    }

    // Fallback if no specific "Total" or invalid "Total" was found:
    // Look for the last number that looks like a currency amount (e.g., 12.34 or 1234.56)
    if (foundAmount == null) {
      RegExp fallbackAmountRegex = RegExp(r'\b\d{1,}(?:[,\s]\d{3})*(?:[\.,]\d{2})\b');
      Iterable<RegExpMatch> matches = fallbackAmountRegex.allMatches(text);
      if (matches.isNotEmpty) {
        // Iterate from the last match to find the most likely large value
        for (int i = matches.length - 1; i >= 0; i--) {
          String potentialAmountString = matches.elementAt(i).group(0)!
              .replaceAll(',', '')
              .replaceAll(' ', '');
          double? parsedValue = double.tryParse(potentialAmountString);
          if (parsedValue != null && parsedValue > 0) { // Only take positive amounts
            foundAmount = parsedValue;
            break; // Found a valid fallback, stop searching
          }
        }
      }
    }


    // --- Improved Title Parsing ---
    String? foundTitle = 'General Expense'; // Default title if nothing specific is found

    // Common keywords to ignore from being titles or part of titles
    List<String> ignoreKeywords = [
      'subtotal', 'tax', 'gst', 'vat', 'change', 'payment', 'credit card',
      'cash', 'total', 'amount', 'balance', 'due', 'thank you', 'you for your purchase',
      'store number', 'customer', 'item', 'price', 'quantity', 'date', 'time',
      'invoice', 'receipt', 'bill', 'copy', 'original', 'net', 'discount',
      'return', 'exchange', 'no.', 'tel:', 'phone:', 'fax:', 'email:', 'web:',
      'website:', 'address:', 'street', 'road', 'lane', 'avenue', 'boulevard',
      'city', 'state', 'zip', 'postcode', 'p.o. box', 'pakistan', 'pk', 'usa', 'uk',
      'limited', 'ltd', 'corp', 'inc', 'co.', 'company', 'shop', 'store', 'market',
      'supermarket', 'mall', 'plaza', 'center', 'centre', 'department', 'goods',
      'services', 'sold to', 'customer copy', 'vendor copy', 'vat no', 'ntn',
      'purchased from', 'transaction', 'order', 'description', 'serial'
    ];

    List<String> lines = text.split('\n');
    List<String> potentialTitles = [];

    // Attempt to find a "store name" or main purpose of the receipt
    for (String line in lines) {
      String trimmedLine = line.trim();
      if (trimmedLine.isEmpty || trimmedLine.length < 3) continue;

      // Skip lines that are likely dates, amounts, or ignorable keywords
      if (dateRegex.hasMatch(trimmedLine) ||
          totalAmountRegex.hasMatch(trimmedLine) || // Check against the new total regex
          RegExp(r'\b\d{1,}(?:[,\s]\d{3})*(?:[\.,]\d{2})\b').hasMatch(trimmedLine) || // Any currency-like number
          trimmedLine.split(' ').length > 8) {
        continue; // Too long for a concise title
      }

      bool containsIgnoredKeyword = ignoreKeywords.any((keyword) => trimmedLine.toLowerCase().contains(keyword));
      if (containsIgnoredKeyword) continue;

      // Look for lines that look like a primary business name, usually at the top
      // Prioritize lines that are mostly alphabetic and not too short/long
      if (trimmedLine.split(' ').isNotEmpty && trimmedLine.split(' ').length <= 5 &&
          !RegExp(r'\d').hasMatch(trimmedLine)) { // Exclude lines with numbers if it's primarily text
        potentialTitles.add(trimmedLine);
      }
    }

    // Heuristic: Take the first few "clean" lines that might be a store name or a short description.
    if (potentialTitles.isNotEmpty) {
      // Prioritize titles that seem more like a proper name (e.g., capitalized words)
      // or simply take the first reasonable one.
      foundTitle = potentialTitles.first;
      // Further refine: if the first title is too generic, look for others.
      if (foundTitle.toLowerCase().contains('receipt') || foundTitle.toLowerCase().contains('invoice') ||
          foundTitle.toLowerCase().contains('bill')) {
        if (potentialTitles.length > 1) {
          foundTitle = potentialTitles[1]; // Try the next one
        }
      }
    }

    // Fallback if nothing useful is found: use a generic category based on keywords
    if (foundTitle == 'General Expense' || foundTitle.isEmpty) {
      if (text.toLowerCase().contains('grocery') || text.toLowerCase().contains('supermarket')) {
        foundTitle = 'Groceries';
      } else if (text.toLowerCase().contains('cafe') || text.toLowerCase().contains('restaurant') || text.toLowerCase().contains('food')) {
        foundTitle = 'Food & Dining';
      } else if (text.toLowerCase().contains('fuel') || text.toLowerCase().contains('petrol') || text.toLowerCase().contains('gas station')) {
        foundTitle = 'Fuel';
      } else if (text.toLowerCase().contains('clothing') || text.toLowerCase().contains('apparel') || text.toLowerCase().contains('fashion')) {
        foundTitle = 'Clothing';
      } else if (text.toLowerCase().contains('pharmacy') || text.toLowerCase().contains('drugstore') || text.toLowerCase().contains('hospital')) {
        foundTitle = 'Health';
      } else {
        foundTitle = 'Miscellaneous'; // Ultimate fallback
      }
    }

    // Ensure the title isn't too long for the graph
    if (foundTitle.length > 30) {
      foundTitle = foundTitle.substring(0, 27) + '...';
    }


    // Update controllers
    setState(() {
      _dateController.text = foundDate ?? '';
      _amountController.text = foundAmount?.toStringAsFixed(2) ?? '';
      _titleController.text = foundTitle!; // Use the new title controller
    });
  }

  /// Displays a SnackBar message at the bottom of the screen.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Saves the extracted receipt data to Firestore under the current user's expenses.
  Future<void> _saveReceiptData() async {
    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      _showSnackBar('Please log in to save receipt data.');
      return;
    }

    final String dateString = _dateController.text;
    final double? amount = double.tryParse(_amountController.text);
    final String title = _titleController.text.trim(); // Use the new title controller

    if (dateString.isEmpty || amount == null || title.isEmpty) {
      _showSnackBar('Please ensure date, amount, and title are entered correctly.');
      return;
    }

    DateTime? expenseDate;
    try {
      // Parse the date using the expected format 'yyyy-MM-dd'
      expenseDate = DateFormat('yyyy-MM-dd').parse(dateString);
    } catch (e) {
      _showSnackBar('Invalid date format. Please use YYYY-MM-DD.');
      return;
    }

    setState(() {
      _isProcessing = true; // Show loading indicator during save
    });

    try {
      // Add expense to a subcollection under the user's document
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('expenses') // Subcollection for expenses
          .add({
        'title': title, // Save the refined title
        'amount': amount,
        'date': Timestamp.fromDate(expenseDate), // Save date as Firestore Timestamp
        'timestamp': FieldValue.serverTimestamp(), // When this record was created
      });

      _showSnackBar('Receipt data saved to Firestore!');

      // Clear fields after successful save
      setState(() {
        _image = null;
        _extractedText = '';
        _dateController.clear();
        _amountController.clear();
        _titleController.clear(); // Clear the new title controller
        _isProcessing = false;
      });

      // Optionally, navigate back or update previous screen
      Navigator.pop(context); // Go back to HomePage after saving
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      debugPrint('Error saving receipt data to Firestore: $e');
      _showSnackBar('Failed to save receipt data: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_image != null)
              Image.file(
                _image!,
                height: 300,
                fit: BoxFit.contain,
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Picture'),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick from Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isProcessing)
              const CircularProgressIndicator()
            else if (_image != null && _extractedText.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Extracted Details (Review & Edit):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.datetime,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (e.g., 123.45)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _titleController, // Use the new title controller here
                    decoration: const InputDecoration(
                      labelText: 'Expense Title/Category', // Updated label
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 20),
                  const Text('Full OCR Result (for reference):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    height: 150,
                    child: SingleChildScrollView(
                      child: Text(
                        _extractedText,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _saveReceiptData,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Receipt', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            if (_image == null && !_isProcessing)
              const Text(
                'Take a picture of your receipt or pick one from the gallery to start scanning.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}