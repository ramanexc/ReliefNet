import 'dart:io';
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
import 'dart:math' as math;

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _formKey = GlobalKey<FormState>();

  String? _issueType;
  String? _urgency;
  String _description = '';
  bool _isSubmitting = false;
  final _descController = TextEditingController();
  final _mathAnswerController = TextEditingController();

  int _num1 = 0;
  int _num2 = 0;
  String _mathOperation = '+';
  int _correctMathResult = 0;

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser == null) {
      _generateMathChallenge();
    }
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
    _descController.dispose();
    _mathAnswerController.dispose();
    super.dispose();
  }

  String _locationText = '';
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  final List<XFile> _mediaFiles = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _issueTypes = ['Food', 'Medical', 'Shelter', 'Other'];
  final List<String> _urgencyLevels = ['Low', 'Medium', 'High'];

  bool _isAnalyzing = false;
  Map<String, dynamic>? _liveAiSummary;

  Future<void> _generateLiveSummary(AppLocalizations l10n) async {
    if (_issueType == null ||
        _urgency == null ||
        _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.select_issue_type}, ${l10n.select_urgency}, and enter a description first',
          ),
        ),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final summary = await GeminiService.analyzeReport(
        issueType: _issueType!,
        urgency: _urgency!,
        description: _descController.text,
      );
      setState(() => _liveAiSummary = summary);
    } finally {
      setState(() => _isAnalyzing = false);
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
              title: Text('Take Photo', style: Theme.of(context).textTheme.bodyMedium),
              onTap: () => Navigator.pop(ctx, 'camera_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: Text('Record Video', style: Theme.of(context).textTheme.bodyMedium),
              onTap: () => Navigator.pop(ctx, 'camera_video'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Photo from Gallery', style: Theme.of(context).textTheme.bodyMedium),
              onTap: () => Navigator.pop(ctx, 'gallery_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: Text('Video from Gallery', style: Theme.of(context).textTheme.bodyMedium),
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
        file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
        break;
      case 'camera_video':
        file = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
        break;
      case 'gallery_photo':
        file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
        break;
      case 'gallery_video':
        file = await _picker.pickVideo(source: ImageSource.gallery);
        break;
    }
    if (file != null) setState(() => _mediaFiles.add(file!));
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
      final ref = FirebaseStorage.instance.ref().child('reports/$uid/$docId/$fileName');
      await ref.putFile(File(file.path));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _submitForm(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    
    // 1. Mandatory Media Check
    if (_mediaFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Visual proof is mandatory. Please attach at least one photo of the incident."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fetch_location_hint)),
      );
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
            content: Text('Bot check failed: Incorrect math answer. Please try again.'),
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

    try {
      // 2. Multimodal AI Credibility Check
      final List<Uint8List> imageBytesList = [];
      for (var file in _mediaFiles.take(2)) {
        if (!_isVideo(file)) {
          imageBytesList.add(await file.readAsBytes());
        }
      }

      final credibility = await GeminiService.checkCredibility(
        issueType: submittedType,
        description: submittedDesc,
        imageBytesList: imageBytesList.isNotEmpty ? imageBytesList : null,
      );

      // 3. User Warning if suspected spam
      if (credibility['status'] == 'suspected_spam' || credibility['isSpam'] == true) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Low Credibility Detected"),
            content: Text("Our AI system flagged this report as potentially unclear or unrelated to the photo. \n\nReason: ${credibility['reason']}\n\nAre you sure you want to submit?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Edit Report")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Submit Anyway")),
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
        'status': credibility['status'] == 'suspected_spam' ? 'flagged' : 'unassigned',
        'assignedVolunteers': [],
        'submittedBy': user?.uid ?? 'anonymous',
        'isAnonymous': user == null,
        'mediaUrls': mediaUrls,
        'aiSummary': null,
        'credibility': credibility, // Save AI verdict
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
        _formKey.currentState!.reset();
        _descController.clear();
        setState(() {
          _issueType = null;
          _urgency = null;
          _description = '';
          _locationText = '';
          _latitude = null;
          _longitude = null;
          _mediaFiles.clear();
          _liveAiSummary = null;
          if (FirebaseAuth.instance.currentUser == null) {
            _mathAnswerController.clear();
            _generateMathChallenge();
          }
        });

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
    final shareText = 'ReliefNet Report\n─────────────────\nID: $docId\nIssue: $issueType\nUrgency: $urgency\nLocation: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}\nDescription: $description';

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
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 72),
              const SizedBox(height: 12),
              Text(l10n.report_submitted, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow(l10n.issue_type, issueType),
                    const SizedBox(height: 8),
                    _summaryRow(l10n.urgency_level, urgency, valueColor: _getUrgencyColor(urgency)),
                    const SizedBox(height: 8),
                    _summaryRow(l10n.location, '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'),
                    if (mediaCount > 0) ...[
                      const SizedBox(height: 8),
                      _summaryRow(l10n.photos_videos, '$mediaCount files uploaded'),
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
              const Text('Report ID', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              SelectableText(
                docId,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report ID copied')));
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share, size: 15),
                    label: Text(l10n.share),
                    onPressed: () => Share.share(shareText, subject: 'ReliefNet Report'),
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
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor))),
      ],
    );
  }

  Future<void> _getLocation(AppLocalizations l10n) async {
    setState(() => _isFetchingLocation = true);
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled')));
      setState(() => _isFetchingLocation = false);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        setState(() => _isFetchingLocation = false);
        return;
      }
    }
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _locationText = 'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}';
      _isFetchingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.report_issue, style: textTheme.bodyLarge),
            Text(l10n.fill_details_desc, style: textTheme.bodySmall),
            const SizedBox(height: 24),

            _FieldLabel(label: l10n.issue_type, icon: Icons.category_outlined),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _issueType,
              hint: Text(l10n.select_issue_type, style: textTheme.bodySmall),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.help_outline_rounded)),
              items: _issueTypes.map((e) {
                String label = e;
                if (e == 'Food') {
                  label = l10n.food;
                } else if (e == 'Medical') label = l10n.medical;
                else if (e == 'Shelter') label = l10n.shelter;
                else if (e == 'Other') label = l10n.other;
                return DropdownMenuItem(value: e, child: Text(label));
              }).toList(),
              onChanged: (val) => setState(() => _issueType = val),
              validator: (val) => val == null ? l10n.select_issue_type : null,
              onSaved: (val) => _issueType = val,
            ),
            const SizedBox(height: 20),

            _FieldLabel(label: l10n.urgency_level, icon: Icons.priority_high_rounded),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _urgency,
              hint: Text(l10n.select_urgency, style: textTheme.bodySmall),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.flag_outlined)),
              items: _urgencyLevels.map((e) {
                String label = e;
                if (e == 'Low') {
                  label = l10n.low;
                } else if (e == 'Medium') label = l10n.medium;
                else if (e == 'High') label = l10n.high;
                return DropdownMenuItem(
                  value: e,
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: _getUrgencyColor(e), size: 10),
                      const SizedBox(width: 10),
                      Text(label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _urgency = val),
              validator: (val) => val == null ? l10n.select_urgency : null,
              onSaved: (val) => _urgency = val,
            ),
            const SizedBox(height: 20),

            _FieldLabel(label: l10n.location, icon: Icons.location_on_outlined),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    style: textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: l10n.fetch_location_hint,
                      prefixIcon: Icon(_latitude != null ? Icons.location_on : Icons.location_off_outlined, color: _latitude != null ? colorScheme.primary : null),
                    ),
                    controller: TextEditingController(text: _locationText),
                    validator: (val) => _latitude == null ? l10n.location : null,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _isFetchingLocation ? null : () => _getLocation(l10n),
                  child: _isFetchingLocation ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _FieldLabel(label: l10n.photos_videos, icon: Icons.photo_library_outlined),
            const SizedBox(height: 8),
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
                                  child: isVid ? Container(width: 110, height: 110, color: Colors.black12, child: const Icon(Icons.videocam_rounded, size: 40, color: Colors.black45)) : Image.file(File(_mediaFiles[i].path), width: 110, height: 110, fit: BoxFit.cover),
                                ),
                                Positioned(top: 4, right: 4, child: GestureDetector(onTap: () { _removeMedia(i); field.didChange(_mediaFiles); }, child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 18)))),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: BorderSide(color: colorScheme.primary.withOpacity(0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                      onPressed: _mediaFiles.length >= 5 ? null : () async { await _pickMedia(l10n); field.didChange(_mediaFiles); },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(_mediaFiles.isEmpty ? l10n.add_media : '${l10n.add_more_media} (${_mediaFiles.length}/5)'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            _FieldLabel(label: l10n.description, icon: Icons.description_outlined),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              style: textTheme.bodyMedium,
              maxLines: 4,
              decoration: InputDecoration(hintText: l10n.describe_situation_hint, alignLabelWithHint: true),
              validator: (val) => val == null || val.isEmpty ? l10n.description : null,
              onSaved: (val) => _description = val!,
            ),
            const SizedBox(height: 16),

            if (_liveAiSummary != null || _isAnalyzing) ...[
              const SizedBox(height: 12),
              if (_isAnalyzing) Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(l10n.ai_analyzing, style: const TextStyle(fontSize: 13, color: Colors.grey)) ])))
              else if (_liveAiSummary != null) ConstrainedBox(constraints: const BoxConstraints(maxWidth: double.infinity), child: AiSummaryCard(aiSummary: _liveAiSummary!)),
              const SizedBox(height: 12),
            ],

            Center(
              child: TextButton.icon(
                onPressed: _isAnalyzing ? null : () => _generateLiveSummary(l10n),
                icon: const Icon(Icons.auto_awesome),
                label: Text(_liveAiSummary == null ? l10n.ai_analysis_preview : l10n.refresh_ai_analysis),
                style: TextButton.styleFrom(foregroundColor: colorScheme.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
            ),
            const SizedBox(height: 16),

            if (FirebaseAuth.instance.currentUser == null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.smart_toy_outlined, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 10),
                        Text("Bot Verification", style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text("Please solve this simple math problem to verify you are a human:", style: textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text("$_num1 $_mathOperation $_num2 =", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _mathAnswerController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: "?",
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _isSubmitting ? null : () => _submitForm(l10n),
                child: _isSubmitting ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.send_rounded), const SizedBox(width: 8), Text(l10n.submit_report, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
              ),
            ),
          ],
        ),
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
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
