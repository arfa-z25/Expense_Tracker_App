// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class VoiceAddPage extends StatefulWidget {
  const VoiceAddPage({super.key});

  @override
  State<VoiceAddPage> createState() => _VoiceAddPageState();
}

class _VoiceAddPageState extends State<VoiceAddPage> with WidgetsBindingObserver {
  // Speech-to-Text variables
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false; // Is speech recognition available?
  bool _isListening = false; // Is the app currently listening?
  String _lastWords = ''; // Stores the real-time spoken text
  String? _deviceLocaleId; // Stores the device's system locale for speech recognition

  // Expense data controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addObserver(this); // Observe app lifecycle
  }

  @override
  void dispose() {
    _speechToText.stop(); // Stop listening if active
    _dateController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    super.dispose();
  }

  // Handle app lifecycle changes (pause listening if app goes to background)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isListening) {
      _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
    // No need to restart on resume, user will initiate
    super.didChangeAppLifecycleState(state);
  }

  /// Initializes the speech_to_text plugin.
  void _initSpeech() async {
    // Get the system locale to use for speech recognition
    final systemLocale = await _speechToText.systemLocale();
    _deviceLocaleId = systemLocale?.localeId ?? 'en_US'; // Fallback to en_US

    
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
          // Process the final text after listening stops automatically
          if (_lastWords.isNotEmpty) {
         
            _processVoiceInput(_lastWords);
          }
        }
      },
    );

   
    if (mounted) {
      setState(() {
       
      }); // Update UI after initialization
    }

    if (!_speechEnabled && mounted) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available or permissions denied.')),
      );
    }
  }

  /// Starts a speech recognition session
  void _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available. Please check permissions.')),
      );
      return;
    }

    _lastWords = ''; // Clear previous voice input text
    _dateController.clear();
    _amountController.clear();
    _descriptionController.clear();
    setState(() {}); // Clear UI immediately

    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30), // Listen for up to 30 seconds
      pauseFor: const Duration(seconds: 3), // Pause detection after 3 seconds of silence
      localeId: _deviceLocaleId ?? 'en_US', // Use the determined device locale
    );

    setState(() {
      _isListening = true;
    });

    _showVoiceInputDialog();
  }

  /// Manually stops the active speech recognition session
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });

    // Ensure the dialog is dismissed if it's still open
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Callback when SpeechToText plugin returns a result.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });

    // If it's the final result, process it immediately
    if (result.finalResult) {
    
      _stopListening(); // Stop listening and trigger processing
    }
  }

  /// Shows a dialog to provide real-time feedback during voice input.
  void _showVoiceInputDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Don't allow dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Speak Your Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isListening ? 'Listening...' : 'Processing...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _lastWords.isEmpty
                        ? 'Say something like: "I spent 500 rupees on groceries yesterday"'
                        : _lastWords,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _stopListening,
                    icon: Icon(_isListening ? Icons.mic_off : Icons.check),
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

  /// Parses the recognized voice text to extract amount, date, and description.
  void _processVoiceInput(String voiceText) {
   

    String lowerCaseText = voiceText.toLowerCase();
    double? parsedAmount;

    // --- AMOUNT PARSING DEBUGGING ---
    RegExp amountRegex = RegExp(r'(?:rupees|rs|\$|€|£)\s*(\d+(?:[\.,]\d{2})?)|\b(\d+(?:[\.,]\d{2})?)\s*(?:rupees|rs|\$|€|£)?');
    Iterable<RegExpMatch> amountMatches = amountRegex.allMatches(lowerCaseText);

   
    bool amountFound = false;
    for (var match in amountMatches.toList().reversed) {
      String? amountString = match.group(1) ?? match.group(2);
     
      if (amountString != null) {
        amountString = amountString.replaceAll(',', '.');
        parsedAmount = double.tryParse(amountString);
        if (parsedAmount != null) {
          amountFound = true;
       
          break; // Found and parsed, stop
        } else {
          
        }
      }
    }

    if (!amountFound) {
      
    }

    _amountController.text = parsedAmount?.toStringAsFixed(2) ?? '';
   

    // --- DATE PARSING DEBUGGING ---
    DateTime? parsedDate;
  

    if (lowerCaseText.contains('today')) {
      parsedDate = DateTime.now();
     
    } else if (lowerCaseText.contains('yesterday')) {
      parsedDate = DateTime.now().subtract(const Duration(days: 1));
      
    } else if (lowerCaseText.contains('tomorrow')) {
      parsedDate = DateTime.now().add(const Duration(days: 1));
   
    } else {
      RegExp explicitDateRegex = RegExp(
        r'(?:on|for)\s*(?:the\s*)?(\d{1,2}(?:st|nd|rd|th)?\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{4}|\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})',
        caseSensitive: false,
      );

      var dateMatch = explicitDateRegex.firstMatch(lowerCaseText);
      if (dateMatch != null) {
        String? potentialDate = dateMatch.group(1);
      
        if (potentialDate != null) {
          List<DateFormat> formats = [
            DateFormat('dd MMMM yyyy'), // 01 June 2025
            DateFormat('MMMM dd yyyy'), // June 01 2025
            DateFormat('MM/dd/yyyy'),
            DateFormat('dd/MM/yyyy'),
            DateFormat('yyyy/MM/dd'),
            DateFormat('MM-dd-yyyy'),
            DateFormat('dd-MM-yyyy'),
            DateFormat('yyyy-MM-dd'),
            DateFormat('MM/dd/yy'), // For 2-digit years
            DateFormat('dd/MM/yy'),
          ];

          bool dateParsedExplicitly = false;
          for (var format in formats) {
            try {
              // Remove ordinal suffixes (st, nd, rd, th) before parsing
              parsedDate = format.parseLoose(potentialDate.replaceAll(RegExp(r'(st|nd|rd|th)'), ''));
              dateParsedExplicitly = true;
           
              break;
            } catch (e) {
              // print('    Failed to parse with ${format.pattern}: $e');
            }
          }

          if (!dateParsedExplicitly) {
          
          }
        }
      } else {
       
      }
    }

    // If no date is found, use the current date
    parsedDate ??= DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(parsedDate);
    

    // --- DESCRIPTION PARSING DEBUGGING ---
    String description = voiceText;
  

    // Remove identified amount from description
    if (parsedAmount != null) {
      // Create a regex to match the parsed amount in various forms (e.g., "500", "500 rupees", "rs 500")
      String amountPattern = parsedAmount.toStringAsFixed(2).replaceAll('.', r'\.');
      RegExp amountRemovalRegex = RegExp(
        r'\b(?:rupees|rs|\$|€|£)?\s*' + amountPattern + r'\b|\b' + amountPattern + r'\s*(?:rupees|rs|\$|€|£)?\b',
        caseSensitive: false,
      );
      description = description.replaceAll(amountRemovalRegex, '').trim();
     
    }

    // Remove identified date phrases from description
    description = description.replaceAll(RegExp(r'\b(today|yesterday|tomorrow)\b', caseSensitive: false), '').trim();
    description = description.replaceAll(RegExp(r'\b(on|for)\s*(?:the\s*)?\b', caseSensitive: false), '').trim();

    // Remove month-date-year combinations (e.g., June 1st 2025 or 1st June 2025)
    description = description.replaceAll(
      RegExp(r'\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}(?:st|nd|rd|th)?(?:\s+\d{4})?\b', caseSensitive: false),
      ''
    ).trim();
    description = description.replaceAll(
      RegExp(r'\b\d{1,2}(?:st|nd|rd|th)?\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\s+\d{4})?\b', caseSensitive: false),
      ''
    ).trim();

    // Remove date formats like 01/06/2025, 2025-06-01 etc.
    description = description.replaceAll(RegExp(r'\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b'), '').trim();
    description = description.replaceAll(RegExp(r'\b\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}\b'), '').trim();

    // Remove extra spaces and punctuation left behind by removals
    description = description.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[,\. ]+|[,\. ]+$'), '').trim();

    _descriptionController.text = description;
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense by Voice'),
        actions: [
          IconButton(
            icon: Icon(Icons.mic, color: _isListening ? Colors.red : null),
            onPressed: _isListening ? _stopListening : _startListening,
            tooltip: _isListening ? 'Stop Listening' : 'Start Voice Input',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
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
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              child: const Text('Save Expense'),
              onPressed: () {
                // Add your save logic here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense saved!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}