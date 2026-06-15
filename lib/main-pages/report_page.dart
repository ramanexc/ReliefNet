import 'dart:io';
import 'dart:async' as async;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:reliefnet/services/gemini_service.dart';
import 'package:reliefnet/widgets/ai_summary_card.dart';
import 'package:reliefnet/l10n/app_localizations.dart';
import 'package:reliefnet/services/offline_report_service.dart';
import 'dart:math' as math;

class ReportPage extends StatefulWidget {
  final bool isEmergency;
  const ReportPage({super.key, this.isEmergency = false});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _formKey = GlobalKey<FormState>();

  String? _issueType;
  String? _urgency;
  bool _isSubmitting = false;
  final _descController = TextEditingController();
  final _mathAnswerController = TextEditingController();

  // New state variables for the redesign
  bool _isLifeThreatening = false;
  final List<String> _selectedLifeThreateningScenarios = [];
  final List<String> _selectedNeeds = [];
  String? _peopleAffected;
  final _landmarkController = TextEditingController();
  bool _allowContact = false;
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  double? _accuracy;
  DateTime? _locationTimestamp;
  async.Timer? _debounce;

  int _num1 = 0;
  int _num2 = 0;
  String _mathOperation = '+';
  int _correctMathResult = 0;

  int _offlineDraftsCount = 0;
  String _syncStatusText = '';
  bool _isSyncRunning = false;

  @override
  void initState() {
    super.initState();
    _isLifeThreatening = widget.isEmergency;
    if (_isLifeThreatening) {
      _urgency = 'High';
    }
    _descController.addListener(_onDescriptionChanged);
    if (FirebaseAuth.instance.currentUser == null) {
      _generateMathChallenge();
    }
    _refreshOfflineCount().then((_) {
      _startOfflineSync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args['isEmergency'] == true) {
      _isLifeThreatening = true;
      _urgency = 'High';
    } else if (args is bool && args == true) {
      _isLifeThreatening = true;
      _urgency = 'High';
    }
  }

  void _onDescriptionChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = async.Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _checkAndTriggerAiAnalysis();
      }
    });
    setState(() {}); // to refresh verification score dynamically as they type
  }

  void _generateMathChallenge() {
    final rand = math.Random();
    _num1 = rand.nextInt(10) + 1; // 1-10
    _num2 = rand.nextInt(10) + 1; // 1-10
    // Randomly choose between + and -
    if (rand.nextBool()) {
      _mathOperation = '+';
      _correctMathResult = _num1 + _num2;
    } else {
      _mathOperation = '-';
      // Ensure result is positive for simplicity
      if (_num1 < _num2) {
        final temp = _num1;
        _num1 = _num2;
        _num2 = temp;
      }
      _correctMathResult = _num1 - _num2;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _descController.removeListener(_onDescriptionChanged);
    _descController.dispose();
    _mathAnswerController.dispose();
    _landmarkController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  final List<XFile> _mediaFiles = [];
  final ImagePicker _picker = ImagePicker();

  bool _isAnalyzing = false;
  Map<String, dynamic>? _liveAiSummary;

  final List<Map<String, dynamic>> _newIssueTypesList = [
    {
      'name': 'Food Assistance',
      'icon': Icons.restaurant,
      'color': Colors.orange,
    },
    {
      'name': 'Medical Assistance',
      'icon': Icons.medical_services,
      'color': Colors.red,
    },
    {'name': 'Shelter Assistance', 'icon': Icons.house, 'color': Colors.indigo},
    {
      'name': 'Water & Sanitation',
      'icon': Icons.water_drop,
      'color': Colors.blue,
    },
    {
      'name': 'Rescue Required',
      'icon': Icons.volunteer_activism,
      'color': Colors.redAccent,
    },
    {
      'name': 'Utilities & Infrastructure',
      'icon': Icons.build,
      'color': Colors.amber,
    },
    {'name': 'Other', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  int _calculateVerificationScore() {
    int score = 0;
    if (_latitude != null) score += 25;
    if (_mediaFiles.isNotEmpty) score += 25;
    if (_descController.text.trim().length >= 15) score += 25;
    if (_allowContact && _phoneController.text.trim().length >= 10) score += 25;
    return score;
  }

  List<String> _getNeedsForCategory(String? category) {
    if (category == null) return [];
    final cat = category.toLowerCase();
    if (cat.contains('food')) {
      return ["Drinking Water", "Dry Rations", "Baby Food", "Cooking Supplies"];
    } else if (cat.contains('medical')) {
      return ["First Aid", "Ambulance", "Medicines", "Doctor Required"];
    } else if (cat.contains('shelter')) {
      return ["Temporary Shelter", "Blankets", "Clothing", "Toilets"];
    } else if (cat.contains('water') || cat.contains('sanitation')) {
      return [
        "Drinking Water",
        "Water Purification",
        "Tanker Supply",
        "Toilets",
      ];
    } else if (cat.contains('rescue')) {
      return ["Evacuation", "Search & Rescue", "Transport Assistance"];
    }
    return [];
  }

  void _applyDescriptionTemplate(String category) {
    if (_descController.text.trim().isNotEmpty) {
      return; // don't overwrite user's typing
    }
    final cat = category.toLowerCase();
    if (cat.contains('food')) {
      _descController.text =
          "No food available for ___ days. Approximately ___ people affected. Immediate assistance required.";
    } else if (cat.contains('medical')) {
      _descController.text =
          "Describe injury or illness:\nNumber of affected individuals:\nCurrent condition and urgency:";
    } else if (cat.contains('shelter')) {
      _descController.text =
          "Temporary shelter needed for ___ people. Current weather conditions. Specific vulnerabilities:";
    } else if (cat.contains('water')) {
      _descController.text =
          "No drinking water available. Water source contaminated/depleted. Needs for ___ people.";
    } else if (cat.contains('rescue')) {
      _descController.text =
          "Evacuation required for ___ people. Risk: (e.g. rising waters/building crash). Any trapped individuals?";
    }
    setState(() {});
  }

  Future<void> _checkAndTriggerAiAnalysis() async {
    if (_isAnalyzing) return;
    if (_issueType != null &&
        _latitude != null &&
        _descController.text.trim().length >= 10 &&
        _mediaFiles.isNotEmpty) {
      setState(() {
        _isAnalyzing = true;
        _liveAiSummary = null;
      });
      try {
        final summary = await GeminiService.analyzeReport(
          issueType: _issueType!,
          urgency: _urgency ?? 'Medium',
          description: _descController.text.trim(),
        );
        if (mounted) {
          setState(() {
            _liveAiSummary = summary;
          });
        }
      } catch (e) {
        print("Auto AI analysis failed: $e");
      } finally {
        if (mounted) {
          setState(() => _isAnalyzing = false);
        }
      }
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.amber;
      case 'High':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _pickMedia(AppLocalizations l10n) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                'Take Photo',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: () => Navigator.pop(ctx, 'camera_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: Text(
                'Record Video',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: () => Navigator.pop(ctx, 'camera_video'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                'Photo from Gallery',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: () => Navigator.pop(ctx, 'gallery_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: Text(
                'Video from Gallery',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: () => Navigator.pop(ctx, 'gallery_video'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;
    XFile? file;
    switch (choice) {
      case 'camera_photo':
        file = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 60,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        break;
      case 'camera_video':
        file = await _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 15),
        );
        break;
      case 'gallery_photo':
        file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 60,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        break;
      case 'gallery_video':
        file = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 15),
        );
        break;
    }
    if (file != null) {
      setState(() {
        _mediaFiles.add(file!);
        _checkAndTriggerAiAnalysis();
      });
    }
  }

  void _removeMedia(int index) => setState(() => _mediaFiles.removeAt(index));

  bool _isVideo(XFile file) {
    final ext = p.extension(file.name).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
  }

  Future<List<String>> _uploadMedia(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'anonymous';
    final List<String> urls = [];
    for (final file in _mediaFiles) {
      final ext = p.extension(file.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final ref = FirebaseStorage.instance.ref().child(
        'reports/$uid/$docId/$fileName',
      );
      await ref.putFile(File(file.path));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  void _clearFormFields() {
    _formKey.currentState?.reset();
    _descController.clear();
    _landmarkController.clear();
    _phoneController.clear();
    _altPhoneController.clear();
    setState(() {
      _issueType = null;
      _urgency = null;
      _latitude = null;
      _longitude = null;
      _accuracy = null;
      _locationTimestamp = null;
      _mediaFiles.clear();
      _liveAiSummary = null;
      _isLifeThreatening = false;
      _selectedLifeThreateningScenarios.clear();
      _selectedNeeds.clear();
      _peopleAffected = null;
      _allowContact = false;
      if (FirebaseAuth.instance.currentUser == null) {
        _mathAnswerController.clear();
        _generateMathChallenge();
      }
    });
  }

  Future<void> _refreshOfflineCount() async {
    final count = await OfflineReportService.getOfflineCount();
    if (mounted) {
      setState(() {
        _offlineDraftsCount = count;
      });
    }
  }

  Future<void> _startOfflineSync() async {
    if (_isSyncRunning) return;
    final count = await OfflineReportService.getOfflineCount();
    if (count == 0) return;

    if (!await OfflineReportService.hasInternet()) {
      return;
    }

    if (mounted) {
      setState(() {
        _isSyncRunning = true;
        _syncStatusText = "Syncing $count offline report(s)...";
      });
    }

    await OfflineReportService.syncOfflineReports(
      onStatusUpdate: (status) {
        if (mounted) {
          setState(() {
            _syncStatusText = status;
          });
        }
      },
    );

    await _refreshOfflineCount();
    if (mounted) {
      setState(() {
        _isSyncRunning = false;
        _syncStatusText = '';
      });
    }
  }

  Future<void> _submitForm(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;

    if (_issueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select an issue category."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_urgency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select an urgency level."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 1. Mandatory Media Check (optional in life-threatening emergencies)
    if (_mediaFiles.isEmpty && !_isLifeThreatening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Visual proof is mandatory. Please attach at least one photo of the incident.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.fetch_location_hint)));
      return;
    }
    _formKey.currentState!.save();

    final user = FirebaseAuth.instance.currentUser;

    // Math Bot Check for anonymous users
    if (user == null) {
      final userValue = int.tryParse(_mathAnswerController.text.trim());
      if (userValue != _correctMathResult) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bot check failed: Incorrect math answer. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        _generateMathChallenge();
        _mathAnswerController.clear();
        return;
      }
    }

    final submittedType = _issueType!;
    final submittedUrgency = _urgency!;
    final submittedDesc = _descController.text;
    final submittedLat = _latitude!;
    final submittedLng = _longitude!;

    setState(() => _isSubmitting = true);

    // 1. Proactive Spam Check: Same Account + Same Location
    bool isLocationSpam = false;
    if (user != null) {
      try {
        // Query for reports from this user. 
        // Using a simpler query to avoid index errors, then filtering in memory.
        final existingReports = await FirebaseFirestore.instance
            .collection('reports')
            .where('submittedBy', isEqualTo: user.uid)
            .limit(15)
            .get();

        int nearCount = 0;
        for (var doc in existingReports.docs) {
          final data = doc.data();
          final String? status = data['status'];
          if (status == 'completed') continue; // Ignore resolved reports

          final double? lat = data['lat'];
          final double? lng = data['lng'];
          if (lat != null && lng != null) {
            final distance = Geolocator.distanceBetween(
              submittedLat,
              submittedLng,
              lat,
              lng,
            );
            if (distance < 100) {
              // 100 meter radius
              nearCount++;
            }
          }
        }

        if (nearCount >= 2) {
          isLocationSpam = true;
        }
      } catch (e) {
        print("Duplicate location check failed: $e");
      }
    }

    // Connection Check
    final hasConnection = await OfflineReportService.hasInternet();
    if (!hasConnection) {
      setState(() => _isSubmitting = true);
      try {
        final List<String> tempMediaPaths = _mediaFiles
            .map((f) => f.path)
            .toList();
        await OfflineReportService.saveReportOffline(
          issueType: submittedType,
          urgency: submittedUrgency,
          description: submittedDesc,
          latitude: submittedLat,
          longitude: submittedLng,
          accuracy: _accuracy,
          isLifeThreatening: _isLifeThreatening,
          lifeThreateningScenarios: _selectedLifeThreateningScenarios,
          immediateNeeds: _selectedNeeds,
          peopleAffected: _peopleAffected,
          landmark: _landmarkController.text.trim(),
          allowContact: _allowContact,
          contactPhone: _allowContact ? _phoneController.text.trim() : '',
          contactAltPhone: _allowContact ? _altPhoneController.text.trim() : '',
          tempMediaPaths: tempMediaPaths,
        );

        if (mounted) {
          _clearFormFields();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "No internet. Report queued offline! It will upload automatically once connection is restored.",
              ),
              backgroundColor: Colors.amber,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Offline save error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
        _refreshOfflineCount();
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 2. Multimodal AI Credibility Check
      final List<Uint8List> imageBytesList = [];
      for (var file in _mediaFiles.take(2)) {
        if (!_isVideo(file)) {
          imageBytesList.add(await file.readAsBytes());
        }
      }

      Map<String, dynamic> credibility = await GeminiService.checkCredibility(
        issueType: submittedType,
        description: submittedDesc,
        imageBytesList: imageBytesList.isNotEmpty ? imageBytesList : null,
      );

      // 3. Override if location spam detected
      if (isLocationSpam) {
        credibility = {
          'score': 10,
          'isSpam': true,
          'status': 'suspected_spam',
          'reason': 'Multiple reports detected from the same user at this specific location. Resource protection protocol activated.',
          'spamProbability': 95,
        };
      }

      if (!mounted) return;

      // 4. User Warning if suspected spam (skip warning for immediate life-threatening emergencies)
      if (!_isLifeThreatening &&
          (credibility['status'] == 'suspected_spam' ||
              credibility['isSpam'] == true)) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Low Credibility Detected"),
            content: Text(
              "Our AI system flagged this report as potentially unclear or unrelated to the photo. \n\nReason: ${credibility['reason']}\n\nAre you sure you want to submit?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Edit Report"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Submit Anyway"),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final docRef = FirebaseFirestore.instance.collection('reports').doc();
      final docId = docRef.id;

      List<String> mediaUrls = [];
      if (_mediaFiles.isNotEmpty) mediaUrls = await _uploadMedia(docId);

      await docRef.set({
        'issueType': submittedType,
        'urgency': submittedUrgency,
        'description': submittedDesc,
        'lat': submittedLat,
        'lng': submittedLng,
        'timestamp': FieldValue.serverTimestamp(),
        'status': credibility['status'] == 'suspected_spam' || credibility['isSpam'] == true
            ? 'suspected_spam'
            : 'unassigned',
        'assignedVolunteers': [],
        'submittedBy': user?.uid ?? 'anonymous',
        'isAnonymous': user == null,
        'mediaUrls': mediaUrls,
        'aiSummary': null,
        'credibility': credibility, // Save AI verdict
        // Redesign Phase 1 fields
        'isLifeThreatening': _isLifeThreatening,
        'lifeThreateningScenarios': _selectedLifeThreateningScenarios,
        'immediateNeeds': _selectedNeeds,
        'peopleAffected': _peopleAffected ?? 'Unknown',
        'landmark': _landmarkController.text.trim(),
        'allowContact': _allowContact,
        'contactPhone': _allowContact ? _phoneController.text.trim() : '',
        'contactAltPhone': _allowContact ? _altPhoneController.text.trim() : '',
        'verificationScore': _calculateVerificationScore(),
        'gpsAccuracy': _accuracy,
        'locationTimestamp': _locationTimestamp,
      });

      final aiSummary = await GeminiService.analyzeReport(
        issueType: submittedType,
        urgency: submittedUrgency,
        description: submittedDesc,
      );

      if (aiSummary != null) {
        await docRef.update({'aiSummary': aiSummary});
      }

      if (mounted) {
        _clearFormFields();

        _showConfirmation(
          l10n: l10n,
          docId: docId,
          issueType: submittedType,
          urgency: submittedUrgency,
          description: submittedDesc,
          lat: submittedLat,
          lng: submittedLng,
          mediaCount: mediaUrls.length,
          aiSummary: aiSummary,
        );
      }
      _startOfflineSync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showConfirmation({
    required AppLocalizations l10n,
    required String docId,
    required String issueType,
    required String urgency,
    required String description,
    required double lat,
    required double lng,
    required int mediaCount,
    Map<String, dynamic>? aiSummary,
  }) {
    final shareText =
        'ReliefNet Report\n─────────────────\nID: $docId\nIssue: $issueType\nUrgency: $urgency\nLocation: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}\nDescription: $description';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 72,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.report_submitted,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow(l10n.issue_type, issueType),
                    const SizedBox(height: 8),
                    _summaryRow(
                      l10n.urgency_level,
                      urgency,
                      valueColor: _getUrgencyColor(urgency),
                    ),
                    const SizedBox(height: 8),
                    _summaryRow(
                      l10n.location,
                      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    ),
                    if (mediaCount > 0) ...[
                      const SizedBox(height: 8),
                      _summaryRow(
                        l10n.photos_videos,
                        '$mediaCount files uploaded',
                      ),
                    ],
                    const SizedBox(height: 8),
                    _summaryRow(l10n.description, description),
                  ],
                ),
              ),
              if (aiSummary != null) ...[
                const SizedBox(height: 16),
                AiSummaryCard(aiSummary: aiSummary),
              ],
              const SizedBox(height: 16),
              const Text(
                'Report ID',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              SelectableText(
                docId,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 15),
                    label: Text(l10n.copy_id),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: docId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report ID copied')),
                      );
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share, size: 15),
                    label: Text(l10n.share),
                    onPressed: () =>
                        Share.share(shareText, subject: 'ReliefNet Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.done),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _getLocation(AppLocalizations l10n) async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        setState(() => _isFetchingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          setState(() => _isFetchingLocation = false);
          return;
        }
      }

      Position? position;
      try {
        // Try getting current position with a 6-second timeout
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 6),
        );
      } catch (e) {
        print(
          "GPS getCurrentPosition timed out or failed: $e. Trying last known position...",
        );
        // Fallback to last known position
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        setState(() {
          _latitude = position!.latitude;
          _longitude = position.longitude;
          _accuracy = position.accuracy;
          _locationTimestamp = position.timestamp ?? DateTime.now();
          _isFetchingLocation = false;
          _checkAndTriggerAiAnalysis();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Could not retrieve GPS coordinates. Please ensure location is enabled or try again outside.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isFetchingLocation = false);
      }
    } catch (e) {
      print("GPS retrieval error: $e");
      setState(() => _isFetchingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "File an Emergency Report",
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Your report helps responders mobilize resources quickly.",
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            if (_offlineDraftsCount > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.2 : 0.08,
                  ),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSyncRunning
                          ? Icons.sync_rounded
                          : Icons.cloud_off_rounded,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSyncRunning
                                ? _syncStatusText
                                : "$_offlineDraftsCount Offline Report(s) Queued",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.amber.shade200
                                  : Colors.amber.shade900,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _isSyncRunning
                                ? "Please keep the app open"
                                : "They will upload automatically once connection is restored.",
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.amber.shade100
                                  : Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isSyncRunning)
                      IconButton(
                        icon: const Icon(Icons.sync_rounded),
                        color: Colors.amber.shade900,
                        tooltip: "Sync Now",
                        onPressed: _startOfflineSync,
                      ),
                  ],
                ),
              ),
            ],

            Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _isLifeThreatening
                    ? Colors.red.shade900.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.08)
                    : theme.colorScheme.surface,
                border: Border.all(
                  color: _isLifeThreatening
                      ? Colors.red.shade700
                      : (theme.brightness == Brightness.dark
                          ? theme.colorScheme.outline
                          : theme.colorScheme.outline.withValues(alpha: 0.3)),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isLifeThreatening)
                        Container(width: 4, color: Colors.red.shade700),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isLifeThreatening =
                                              !_isLifeThreatening;
                                          if (_isLifeThreatening) {
                                            _urgency = 'High';
                                          } else {
                                            _selectedLifeThreateningScenarios
                                                .clear();
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.red,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "🚨 Life-Threatening Emergency",
                                                    style: textTheme.bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .red
                                                              .shade700,
                                                        ),
                                                  ),
                                                  Text(
                                                    "Toggle if lives are in immediate danger",
                                                    style: textTheme.bodySmall
                                                        ?.copyWith(
                                                          fontSize: 11,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: _isLifeThreatening,
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: Colors.red.shade600,
                                    inactiveThumbColor: theme.brightness == Brightness.dark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569),
                                    inactiveTrackColor: theme.brightness == Brightness.dark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFE2E8F0),
                                    trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return Colors.red.shade700;
                                      }
                                      return theme.brightness == Brightness.dark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1);
                                    }),
                                    onChanged: (val) {
                                      setState(() {
                                        _isLifeThreatening = val;
                                        if (_isLifeThreatening) {
                                          _urgency = 'High';
                                        } else {
                                          _selectedLifeThreateningScenarios
                                              .clear();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_isLifeThreatening) ...[
                                const Divider(height: 20),
                                Text(
                                  "Select all critical factors:",
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...[
                                  "People Trapped",
                                  "Serious Injuries",
                                  "Fire",
                                  "Flooding",
                                  "Building Collapse",
                                ].map((scenario) {
                                  final selected =
                                      _selectedLifeThreateningScenarios
                                          .contains(scenario);
                                  return CheckboxListTile(
                                    title: Text(
                                      scenario,
                                      style: textTheme.bodyMedium,
                                    ),
                                    value: selected,
                                    activeColor: Colors.red,
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (bool? checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedLifeThreateningScenarios.add(
                                            scenario,
                                          );
                                        } else {
                                          _selectedLifeThreateningScenarios
                                              .remove(scenario);
                                        }
                                      });
                                    },
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Issue Type Grid
            _FieldLabel(
              label: "Select Issue Category",
              icon: Icons.category_outlined,
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: _newIssueTypesList.length,
              itemBuilder: (context, index) {
                final item = _newIssueTypesList[index];
                final name = item['name'] as String;
                final icon = item['icon'] as IconData;
                final color = item['color'] as Color;
                final isSelected = _issueType == name;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _issueType = name;
                      _selectedNeeds.clear();
                      _applyDescriptionTemplate(name);
                      _checkAndTriggerAiAnalysis();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? color
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(icon, color: color, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle_rounded,
                            color: color,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // 3. Dynamic Needs Checklist
            if (_issueType != null &&
                _getNeedsForCategory(_issueType).isNotEmpty) ...[
              _FieldLabel(
                label: "Immediate Assistance Needs",
                icon: Icons.playlist_add_check_rounded,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _getNeedsForCategory(_issueType).map((need) {
                  final isSelected = _selectedNeeds.contains(need);
                  return FilterChip(
                    label: Text(need),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedNeeds.add(need);
                        } else {
                          _selectedNeeds.remove(need);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // 4. Urgency Level cards
            _FieldLabel(
              label: "Urgency Level",
              icon: Icons.priority_high_rounded,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildUrgencyCard(
                  'Low',
                  Colors.green,
                  "Non-critical aid needed",
                  theme,
                  textTheme,
                ),
                const SizedBox(width: 8),
                _buildUrgencyCard(
                  'Medium',
                  Colors.orange,
                  "Urgent but stable",
                  theme,
                  textTheme,
                ),
                const SizedBox(width: 8),
                _buildUrgencyCard(
                  'High',
                  Colors.red,
                  "Immediate hazard/rescue",
                  theme,
                  textTheme,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. People Affected Choice Chips
            _FieldLabel(
              label: "People Affected",
              icon: Icons.people_outline_rounded,
            ),
            const SizedBox(height: 10),
            Row(
              children:
                  [
                    "1–5 People",
                    "5–20 People",
                    "20–50 People",
                    "50+ People",
                  ].map((choice) {
                    final isSelected = _peopleAffected == choice;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text(choice),
                          selected: isSelected,
                          padding: EdgeInsets.zero,
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) _peopleAffected = choice;
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 20),

            // 6. Location Block
            _FieldLabel(
              label: "Location Details",
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _latitude != null
                            ? Icons.gps_fixed
                            : Icons.gps_not_fixed,
                        color: _latitude != null
                            ? colorScheme.primary
                            : theme.disabledColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _latitude != null
                                  ? "GPS Verified"
                                  : "Location Required",
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_latitude != null) ...[
                              Text(
                                "Coordinates: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}",
                                style: textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                              if (_accuracy != null)
                                Text(
                                  "Accuracy: ±${_accuracy!.toStringAsFixed(1)} meters",
                                  style: textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ] else
                              Text(
                                "Tap button to fetch coordinates",
                                style: textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isFetchingLocation
                            ? null
                            : () => _getLocation(l10n),
                        icon: _isFetchingLocation
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 14),
                        label: Text(
                          _isFetchingLocation ? "Fetching..." : "Get GPS",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _landmarkController,
                    style: textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: "Nearby Landmark (Optional)",
                      hintText: "e.g. Near Metro Pillar 342, Opposite School",
                      prefixIcon: Icon(Icons.pin_drop_outlined),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 7. Photos/Videos
            _FieldLabel(
              label: "Incident Proof Photos/Videos",
              icon: Icons.photo_library_outlined,
            ),
            const SizedBox(height: 10),
            FormField<List<XFile>>(
              initialValue: _mediaFiles,
              builder: (field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_mediaFiles.isNotEmpty) ...[
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _mediaFiles.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final isVid = _isVideo(_mediaFiles[i]);
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: isVid
                                      ? Container(
                                          width: 110,
                                          height: 110,
                                          color: Colors.black12,
                                          child: const Icon(
                                            Icons.videocam_rounded,
                                            size: 40,
                                            color: Colors.black45,
                                          ),
                                        )
                                      : Image.file(
                                          File(_mediaFiles[i].path),
                                          width: 110,
                                          height: 110,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      _removeMedia(i);
                                      field.didChange(_mediaFiles);
                                      setState(() {});
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: colorScheme.primary.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      onPressed: _mediaFiles.length >= 5
                          ? null
                          : () async {
                              await _pickMedia(l10n);
                              field.didChange(_mediaFiles);
                            },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        _mediaFiles.isEmpty
                            ? l10n.add_media
                            : '${l10n.add_more_media} (${_mediaFiles.length}/5)',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // 8. Description
            _FieldLabel(
              label: "Situation Description",
              icon: Icons.description_outlined,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descController,
              style: textTheme.bodyMedium,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n.describe_situation_hint,
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? l10n.description : null,
            ),
            const SizedBox(height: 20),

            // 9. Automatic AI Analysis Preview (if triggered)
            if (_liveAiSummary != null || _isAnalyzing) ...[
              _FieldLabel(
                label: "AI Assessment Preview",
                icon: Icons.auto_awesome,
              ),
              const SizedBox(height: 10),
              if (_isAnalyzing)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          l10n.ai_analyzing,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_liveAiSummary != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: AiSummaryCard(aiSummary: _liveAiSummary!),
                ),
              const SizedBox(height: 20),
            ],

            // 10. Responders Contact Details
            _FieldLabel(
              label: "Contact Information",
              icon: Icons.contact_phone_outlined,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.call_end_rounded,
                        color: Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Allow rescue teams to contact you",
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Responders can call to coordinate rescue",
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _allowContact,
                        activeThumbColor: Colors.white,
                        activeTrackColor: theme.colorScheme.primary,
                        inactiveThumbColor: theme.brightness == Brightness.dark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                        inactiveTrackColor: theme.brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return theme.colorScheme.primary;
                          }
                          return theme.brightness == Brightness.dark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1);
                        }),
                        onChanged: (val) {
                          setState(() {
                            _allowContact = val;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_allowContact) ...[
                    const Divider(height: 24),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        hintText: "Enter active mobile number",
                        prefixIcon: Icon(Icons.phone),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _altPhoneController,
                      keyboardType: TextInputType.phone,
                      style: textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        labelText: "Alternative Phone (Optional)",
                        hintText: "Enter backup mobile number",
                        prefixIcon: Icon(Icons.phone_iphone),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 11. Bot Verification (for anonymous users)
            if (FirebaseAuth.instance.currentUser == null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Bot Verification",
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Please solve this simple math problem to verify you are a human:",
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$_num1 $_mathOperation $_num2 =",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _mathAnswerController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: "?",
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _generateMathChallenge,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          tooltip: "New challenge",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 12. Verification Score
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Verification Score",
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${_calculateVerificationScore()}%",
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _calculateVerificationScore() >= 75
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _calculateVerificationScore() / 100.0,
                    backgroundColor: theme.colorScheme.outline.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _calculateVerificationScore() >= 75
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Contributing Factors:",
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildFactorRow(
                    "Location Verified",
                    _latitude != null,
                    textTheme,
                  ),
                  _buildFactorRow(
                    "Photo Attached",
                    _mediaFiles.isNotEmpty,
                    textTheme,
                  ),
                  _buildFactorRow(
                    "Detailed Description",
                    _descController.text.trim().length >= 15,
                    textTheme,
                  ),
                  _buildFactorRow(
                    "Contact Info Available",
                    _allowContact && _phoneController.text.trim().length >= 10,
                    textTheme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 13. Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLifeThreatening
                      ? Colors.red.shade700
                      : null,
                  foregroundColor: _isLifeThreatening ? Colors.white : null,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : () => _submitForm(l10n),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isLifeThreatening
                                ? Icons.emergency_rounded
                                : Icons.send_rounded,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isLifeThreatening
                                ? "SUBMIT EMERGENCY ALERT"
                                : l10n.submit_report,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyCard(
    String level,
    Color color,
    String desc,
    ThemeData theme,
    TextTheme textTheme,
  ) {
    final isSelected = _urgency == level;
    final isClickable = !_isLifeThreatening || level == 'High';
    return Expanded(
      child: Opacity(
        opacity: isClickable ? 1.0 : 0.4,
        child: InkWell(
          onTap: isClickable
              ? () {
                  setState(() {
                    _urgency = level;
                    _checkAndTriggerAiAnalysis();
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            height: 95,
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? color
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flag,
                  color: isSelected ? color : theme.disabledColor,
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  level,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 8,
                    color: isSelected ? null : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFactorRow(String label, bool verified, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            verified
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: verified ? Colors.green : Colors.grey.shade500,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: verified
                  ? textTheme.bodyMedium?.color
                  : Colors.grey.shade600,
              fontWeight: verified ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
