// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceAddPage extends StatefulWidget {
  const VoiceAddPage({super.key});

  @override
  State<VoiceAddPage> createState() => _VoiceAddPageState();
}

class _VoiceAddPageState extends State<VoiceAddPage> with WidgetsBindingObserver {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  String? _deviceLocaleId;

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _speechToText.stop();
    _dateController.dispose();
    _amountController.dispose();
    _titleController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isListening) {
      _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
    super.didChangeAppLifecycleState(state);
  }

  void _initSpeech() async {
    final systemLocale = await _speechToText.systemLocale();
    _deviceLocaleId = systemLocale?.localeId ?? 'en_US';

    _speechEnabled = await _speechToText.initialize(
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech recognition error: ${error.errorMsg}')),
          );
        }
        setState(() {
          _isListening = false;
        });
      },
      onStatus: (status) {
        if (status == SpeechToText.listeningStatus) {
          setState(() {
            _isListening = true;
          });
        } else if (status == SpeechToText.notListeningStatus || status == SpeechToText.doneStatus) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );

    if (mounted) {
      setState(() {});
    }

    if (!_speechEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available or permissions denied. Please grant microphone permission.')),
      );
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available. Please check microphone permissions.')),
      );
      return;
    }

    _lastWords = '';
    _dateController.clear();
    _amountController.clear();
    _titleController.clear();
    setState(() {});

    _showVoiceInputDialog();

    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: _deviceLocaleId ?? 'en_US',
    );

    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });

    // Only dismiss the dialog if it is open (not the page itself)
    if (mounted && ModalRoute.of(context)?.isCurrent == false) {
      Navigator.of(context).pop();
    }

    if (_lastWords.isNotEmpty) {
      _processVoiceInput(_lastWords);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      if (result.finalResult) {
        _stopListening();
      }
    });
  }

  void _showVoiceInputDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _isListening;
            _lastWords;
            return AlertDialog(
              title: const Text('Speak Your Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 60,
                    color: _isListening ? Colors.blueAccent : Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isListening ? 'Listening...' : 'Processing...',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _lastWords.isEmpty
                        ? 'Say something like: "I spent 500 rupees on groceries yesterday"'
                        : _lastWords,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: _lastWords.isEmpty ? Colors.grey : Colors.black),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _stopListening,
                    icon: Icon(_isListening ? Icons.stop : Icons.check),
                    label: Text(_isListening ? 'Stop Listening' : 'Done'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _processVoiceInput(String voiceText) {
    String lowerCaseText = voiceText.toLowerCase();
    double? parsedAmount;
    DateTime? parsedDate;
    String? parsedTitle;

    // --- 1. AMOUNT PARSING ---
    RegExp amountRegex = RegExp(
      r'(?:total|amount|cost|price|value|spent|paid)\s*[:\s]*[\$€£Rs]*\s*(\d{1,3}(?:[,\s]\d{3})*(?:[\.,]\d{2})?)'
      r'|\b(\d{1,3}(?:[,\s]\d{3})*(?:[\.,]\d{2})?)\s*(?:rupees|rs|\$|€|£)\b'
      r'|\b(?:rupees|rs|\$|€|£)\s*(\d{1,3}(?:[,\s]\d{3})*(?:[\.,]\d{2})?)'
      r'|\b(\d+)\b',
      caseSensitive: false,
    );

    for (var match in amountRegex.allMatches(lowerCaseText)) {
      String? amountString;
      if (match.group(1) != null) {
        amountString = match.group(1);
      } else if (match.group(2) != null) {
        amountString = match.group(2);
      } else if (match.group(3) != null) {
        amountString = match.group(3);
      } else if (match.group(4) != null) {
        amountString = match.group(4);
        if (!amountString!.contains('.') && !amountString.contains(',')) {
          amountString += '.00';
        }
      }
      if (amountString != null) {
        amountString = amountString.replaceAll(',', '').replaceAll(' ', '');
        parsedAmount = double.tryParse(amountString);
        if (parsedAmount != null && parsedAmount > 0) {
          break;
        }
      }
    }
    _amountController.text = parsedAmount?.toStringAsFixed(2) ?? '';

    // --- 2. DATE PARSING ---
    if (lowerCaseText.contains('today')) {
      parsedDate = DateTime.now();
    } else if (lowerCaseText.contains('yesterday')) {
      parsedDate = DateTime.now().subtract(const Duration(days: 1));
    } else if (lowerCaseText.contains('tomorrow')) {
      parsedDate = DateTime.now().add(const Duration(days: 1));
    } else {
      RegExp explicitDateRegex = RegExp(
        r'(?:on|for|spent\s*(?:on)?|paid\s*(?:on)?)?\s*'
        r'(?:the\s*)?(\d{1,2}(?:st|nd|rd|th)?\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\s+\d{2,4})?|' 
        r'(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}(?:st|nd|rd|th)?(?:\s+\d{2,4})?|'
        r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}|'
        r'\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2})',
        caseSensitive: false,
      );

      var dateMatch = explicitDateRegex.firstMatch(lowerCaseText);
      if (dateMatch != null && dateMatch.group(1) != null) {
        String potentialDate = dateMatch.group(1)!;
        potentialDate = potentialDate.replaceAll(RegExp(r'(st|nd|rd|th)\b'), '');

        List<DateFormat> formats = [
          DateFormat('dd MMMM yyyy'),
          DateFormat('MMMM dd yyyy'),
          DateFormat('d MMMM yyyy'),
          DateFormat('MMMM d yyyy'),
          DateFormat('dd MMMM yy'),
          DateFormat('MMMM dd yy'),
          DateFormat('d MMMM yy'),
          DateFormat('MMMM d yy'),
          DateFormat('MM/dd/yyyy'),
          DateFormat('dd/MM/yyyy'),
          DateFormat('yyyy/MM/dd'),
          DateFormat('MM-dd-yyyy'),
          DateFormat('dd-MM-yyyy'),
          DateFormat('yyyy-MM-dd'),
          DateFormat('MM/dd/yy'),
          DateFormat('dd/MM/yy'),
        ];

        for (var format in formats) {
          try {
            parsedDate = format.parseLoose(potentialDate);
            break;
          // ignore: empty_catches
          } catch (e) {}
        }
      }
    }

    parsedDate ??= DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(parsedDate);

    // --- 3. TITLE PARSING ---
    String tempTitle = voiceText;

    if (parsedAmount != null) {
      String amountPattern = parsedAmount.toStringAsFixed(parsedAmount.truncateToDouble() == parsedAmount ? 0 : 2).replaceAll('.', r'\.');
      RegExp amountRemovalRegex = RegExp(
          r'(?:total|amount|cost|price|value|spent|paid)\s*[:\s]*[\$€£Rs]*\s*' + amountPattern + r'\b|' +
              r'\b' + amountPattern + r'\s*(?:rupees|rs|\$|€|£)\b|' +
              r'\b(?:rupees|rs|\$|€|£)\s*' + amountPattern + r'\b',
          caseSensitive: false);
      tempTitle = tempTitle.replaceAll(amountRemovalRegex, '').trim();
    }

    tempTitle = tempTitle.replaceAll(RegExp(r'\b(today|yesterday|tomorrow)\b', caseSensitive: false), '').trim();

    tempTitle = tempTitle.replaceAll(
      RegExp(
        r'(?:on|for|spent\s*(?:on)?|paid\s*(?:on)?)?\s*'
        r'(?:the\s*)?\d{1,2}(?:st|nd|rd|th)?\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\s+\d{2,4})?|'
        r'(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}(?:st|nd|rd|th)?(?:\s+\d{2,4})?|'
        r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}|'
        r'\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}',
        caseSensitive: false,
      ),
      ''
    ).trim();

    List<String> fillerWords = [
      'i spent', 'i paid', 'i bought', 'an expense of', 'it was', 'for', 'on',
      'that was', 'which was', 'about', 'a new', 'some', 'the', 'my', 'her', 'his',
      'our', 'their'
    ];
    for (String filler in fillerWords) {
      tempTitle = tempTitle.replaceAll(RegExp(r'\b' + filler + r'\b', caseSensitive: false), '').trim();
    }

    tempTitle = tempTitle.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[,\. ]+|[,\. ]+$'), '').trim();

    parsedTitle = tempTitle.isNotEmpty ? tempTitle : 'Uncategorized Expense';
    _titleController.text = parsedTitle;

    setState(() {});
  }

  Future<void> _saveExpenseData() async {
    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save expense data.')),
      );
      return;
    }

    final String dateString = _dateController.text;
    final double? amount = double.tryParse(_amountController.text);
    final String title = _titleController.text.trim();

    if (dateString.isEmpty || amount == null || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please ensure amount, date, and title are entered correctly.')),
      );
      return;
    }

    DateTime? expenseDate;
    try {
      expenseDate = DateFormat('yyyy-MM-dd').parse(dateString);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid date format. Please use YYYY-MM-DD.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving expense...')),
    );

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('expenses')
          .add({
        'title': title,
        'amount': amount,
        'date': Timestamp.fromDate(expenseDate),
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved successfully!')),
      );

      setState(() {
        _lastWords = '';
        _dateController.clear();
        _amountController.clear();
        _titleController.clear();
      });

      // Do NOT pop the page automatically after saving

    } catch (e) {
      debugPrint('Error saving expense data to Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save expense data: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense by Voice'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? Colors.redAccent.withOpacity(0.8) : Colors.blueAccent.withOpacity(0.8),
                          boxShadow: [
                            BoxShadow(
                              color: _isListening ? Colors.redAccent.withOpacity(0.4) : Colors.blueAccent.withOpacity(0.4),
                              blurRadius: _isListening ? 20.0 : 10.0,
                              spreadRadius: _isListening ? 5.0 : 2.0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _speechEnabled
                          ? (_isListening ? 'Listening... Tap to stop' : 'Tap mic to speak expense')
                          : 'Speech not available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _speechEnabled ? Colors.black87 : Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isListening && _lastWords.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _lastWords,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 40),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (PKR)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Date (YYYY-MM-DD)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _dateController.text.isNotEmpty
                      ? DateTime.tryParse(_dateController.text) ?? DateTime.now()
                      : DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Expense Title/Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveExpenseData,
                icon: const Icon(Icons.save),
                label: const Text('Save Expense', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}