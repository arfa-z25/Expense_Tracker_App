// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart'; // For date formatting

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

  // Extracted data fields
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController(); // New: for description

  // To store parsed items if you want to display them individually
  // For simplicity, we'll focus on a single description field for now based on your request.
  // List<ReceiptItem> _parsedItems = [];

  @override
  void dispose() {
    _textRecognizer.close();
    _dateController.dispose();
    _amountController.dispose();
    _descriptionController.dispose(); // Dispose new controller
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _extractedText = ''; // Clear previous text
        _dateController.clear();
        _amountController.clear();
        _descriptionController.clear(); // Clear description
        _isProcessing = true;
      });
      await _recognizeText(_image!);
    }
  }

  Future<void> _recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      setState(() {
        _extractedText = recognizedText.text;
        _isProcessing = false;
        _parseExtractedText(recognizedText.text); // Parse and set controllers
      });
    } catch (e) {
      setState(() {
        _extractedText = 'Error recognizing text: $e';
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recognizing text: ${e.toString()}')),
      );
    }
  }

  void _parseExtractedText(String text) {
    // --- Date Parsing ---
    // More robust date regex, looking for common separators and year lengths
    // Prioritize YYYY-MM-DD or MM/DD/YYYY or DD/MM/YYYY
    RegExp dateRegex = RegExp(
        r'\b(?:(?:\d{4}[\-\/\.]\d{1,2}[\-\/\.]\d{1,2})|(?:\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4}))\b',
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
        DateFormat('MM-dd-yy'), // For 2-digit years
        DateFormat('MM/dd/yy'),
        DateFormat('dd-MM-yy'),
        DateFormat('dd/MM/yy'),
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
      // If no date is found, try to use today's date as a default or leave blank
      foundDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    // --- Amount Parsing ---
    // Look for keywords like "Total", "Amount", "Grand Total", "Balance Due"
    // followed by a number with 2 decimal places. Handles currency symbols.
    RegExp amountRegex = RegExp(
      r'(?:total|amount|grand\s*total|balance|due)\s*[:\s]*[\$€£]?\s*(\d+[\.,]\d{2})',
      caseSensitive: false,
      multiLine: true,
    );

    double? foundAmount;
    final amountMatch = amountRegex.firstMatch(text);
    if (amountMatch != null && amountMatch.group(1) != null) {
      // Replace comma with dot for consistent parsing
      String amountString = amountMatch.group(1)!.replaceAll(',', '.');
      foundAmount = double.tryParse(amountString);
    } else {
      // Fallback: If "Total" isn't found, try to find the last monetary value in the text
      // This is a heuristic and might not always be accurate.
      RegExp fallbackAmountRegex = RegExp(r'\b\d+[\.,]\d{2}\b');
      Iterable<RegExpMatch> matches = fallbackAmountRegex.allMatches(text);
      if (matches.isNotEmpty) {
        // Take the last match as it's often the total on receipts
        String lastAmountString = matches.last.group(0)!.replaceAll(',', '.');
        foundAmount = double.tryParse(lastAmountString);
      }
    }

    // --- Description Parsing (simplified) ---
    // This is the trickiest part as receipts vary widely.
    // For a simple approach, we'll try to capture text between a possible "items" heading
    // and the "total" line. For a real-world app, you'd need more advanced NLP or
    // heuristics (e.g., look for patterns like "Item Name (Qty) Price").

    String? foundDescription = '';

    // A very basic attempt: capture lines that don't look like dates or amounts and are not too short.
    // This will just grab a chunk of text.
    List<String> lines = text.split('\n');
    List<String> potentialDescriptionLines = [];

    for (String line in lines) {
      String trimmedLine = line.trim();
      if (trimmedLine.isEmpty || trimmedLine.length < 3) continue; // Skip empty or very short lines

      // Skip lines that look like dates or amounts already parsed
      if (dateRegex.hasMatch(trimmedLine) || amountRegex.hasMatch(trimmedLine)) continue;
      if (RegExp(r'\b\d+[\.,]\d{2}\b').hasMatch(trimmedLine) && trimmedLine.split(' ').length < 3) continue; // Skip lines that are just numbers with decimals

      // Try to exclude common receipt footers/headers or non-item lines
      if (trimmedLine.toLowerCase().contains('subtotal') ||
          trimmedLine.toLowerCase().contains('tax') ||
          trimmedLine.toLowerCase().contains('change') ||
          trimmedLine.toLowerCase().contains('payment') ||
          trimmedLine.toLowerCase().contains('credit card') ||
          trimmedLine.toLowerCase().contains('cash') ||
          trimmedLine.toLowerCase().contains('thank you') ||
          trimmedLine.toLowerCase().contains('store number')) {
        continue;
      }
      potentialDescriptionLines.add(trimmedLine);
    }
    foundDescription = potentialDescriptionLines.join('\n');

    // Update controllers
    setState(() {
      _dateController.text = foundDate ?? '';
      _amountController.text = foundAmount?.toStringAsFixed(2) ?? '';
      _descriptionController.text = foundDescription!; // Set the description
    });
  }

  void _saveReceiptData() {
    final date = _dateController.text;
    final amount = double.tryParse(_amountController.text); // Amount as double
    final description = _descriptionController.text;

    if (date.isEmpty || amount == null || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please ensure date, amount, and description are entered correctly.')),
      );
      return;
    }

    // You now have:
    // date (String, YYYY-MM-DD format)
    // amount (double)
    // description (String)

    // For demonstration, print to console
  

    // In a real application, you would save this data to a database (e.g., SQLite, Firebase),
    // an API, or a local file.
    // Example:
    // MyDatabaseHelper.instance.insertReceipt({
    //   'date': date,
    //   'amount': amount,
    //   'description': description,
    // });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt data saved!')),
    );

    // Optionally, clear fields after saving
    // setState(() {
    //   _image = null;
    //   _extractedText = '';
    //   _dateController.clear();
    //   _amountController.clear();
    //   _descriptionController.clear();
    // });
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
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Picture'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick from Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isProcessing)
              const CircularProgressIndicator()
            else if (_image != null && _extractedText.isNotEmpty) // Show fields only if an image is picked and processed
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
                    readOnly: true, // Optionally make it read-only if you prefer users not to edit the date
                    onTap: () async { // Allow manual date picking
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
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (What you bought/spent on)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5, // Allow multiple lines for description
                    keyboardType: TextInputType.multiline,
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
                      onPressed: _saveReceiptData,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: const Text('Save Receipt', style: TextStyle(fontSize: 18)),
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