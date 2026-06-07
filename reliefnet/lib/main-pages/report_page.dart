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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _descController.dispose();
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

  Future<void> _generateLiveSummary() async {
    if (_issueType == null || _urgency == null || _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select type, urgency, and enter a description first')),
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
      case 'Low': return Colors.green;
      case 'Medium': return Colors.amber;
      case 'High': return Colors.red;
      default: return Colors.grey;
    }
  }

  // ── MEDIA ────────────────────────────────────────────────────────────────

  Future<void> _pickMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: Text('Take Photo', style: Theme.of(context).textTheme.bodyMedium), onTap: () => Navigator.pop(ctx, 'camera_photo')),
            ListTile(leading: const Icon(Icons.videocam), title: Text('Record Video', style: Theme.of(context).textTheme.bodyMedium), onTap: () => Navigator.pop(ctx, 'camera_video')),
            ListTile(leading: const Icon(Icons.photo_library), title: Text('Photo from Gallery', style: Theme.of(context).textTheme.bodyMedium), onTap: () => Navigator.pop(ctx, 'gallery_photo')),
            ListTile(leading: const Icon(Icons.video_library), title: Text('Video from Gallery', style: Theme.of(context).textTheme.bodyMedium), onTap: () => Navigator.pop(ctx, 'gallery_video')),
          ],
        ),
      ),
    );

    if (choice == null) return;
    XFile? file;
    switch (choice) {
      case 'camera_photo': file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75); break;
      case 'camera_video': file = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60)); break;
      case 'gallery_photo': file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75); break;
      case 'gallery_video': file = await _picker.pickVideo(source: ImageSource.gallery); break;
    }
    if (file != null) setState(() => _mediaFiles.add(file!));
  }

  void _removeMedia(int index) => setState(() => _mediaFiles.removeAt(index));

  bool _isVideo(XFile file) {
    final ext = p.extension(file.name).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
  }

  Future<List<String>> _uploadMedia(String docId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
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

  // ── SUBMIT ───────────────────────────────────────────────────────────────

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fetch location first')));
      return;
    }
    _formKey.currentState!.save();

    final submittedType = _issueType!;
    final submittedUrgency = _urgency!;
    final submittedDesc = _descController.text;
    final submittedLat = _latitude!;
    final submittedLng = _longitude!;

    setState(() => _isSubmitting = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('reports').doc();
      final docId = docRef.id;

      List<String> mediaUrls = [];
      if (_mediaFiles.isNotEmpty) mediaUrls = await _uploadMedia(docId);

      // Step 1: Save to Firestore
      await docRef.set({
        'issueType': submittedType,
        'urgency': submittedUrgency,
        'description': submittedDesc,
        'lat': submittedLat,
        'lng': submittedLng,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unassigned',
        'assignedVolunteers': [],
        'submittedBy': FirebaseAuth.instance.currentUser!.uid,
        'mediaUrls': mediaUrls,
        'aiSummary': null,
      });

      // Step 2: Call Gemini
      print('DEBUG: Requesting AI Summary for: $submittedType');
      final aiSummary = await GeminiService.analyzeReport(
        issueType: submittedType,
        urgency: submittedUrgency,
        description: submittedDesc,
      );
      print('DEBUG: AI Summary result: ${aiSummary != null ? "Success" : "Failed (null)"}');

      // Step 3: Write AI summary back
      if (aiSummary != null) {
        try {
          await docRef.update({'aiSummary': aiSummary});
        } catch (e) {
          print('DEBUG: Failed to update Firestore with AI summary: $e');
        }
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
        });

        _showConfirmation(
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── CONFIRMATION DIALOG ──────────────────────────────────────────────────

  void _showConfirmation({
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
              const Text('Report Submitted!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Original summary
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
                    _summaryRow('Issue Type', issueType),
                    const SizedBox(height: 8),
                    _summaryRow('Urgency', urgency, valueColor: _getUrgencyColor(urgency)),
                    const SizedBox(height: 8),
                    _summaryRow('Location', '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'),
                    if (mediaCount > 0) ...[const SizedBox(height: 8), _summaryRow('Media', '$mediaCount file${mediaCount > 1 ? 's' : ''} uploaded')],
                    const SizedBox(height: 8),
                    _summaryRow('Description', description),
                  ],
                ),
              ),

              // AI Analysis card
              if (aiSummary != null) ...[
                const SizedBox(height: 16),
                AiSummaryCard(aiSummary: aiSummary),
              ],

              const SizedBox(height: 16),
              const Text('Report ID', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              SelectableText(docId, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text('Copy ID'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: docId));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report ID copied')));
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share, size: 15),
                    label: const Text('Share'),
                    onPressed: () => Share.share(shareText, subject: 'ReliefNet Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))),
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

  // ── LOCATION ─────────────────────────────────────────────────────────────

  Future<void> _getLocation() async {
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
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission permanently denied')));
      setState(() => _isFetchingLocation = false);
      return;
    }
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _locationText = 'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}';
      _isFetchingLocation = false;
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report an Issue', style: textTheme.bodyLarge),
            Text('Fill in the details below and we\'ll dispatch help quickly.', style: textTheme.bodySmall),
            const SizedBox(height: 24),

            _FieldLabel(label: 'Issue Type', icon: Icons.category_outlined),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _issueType,
              hint: Text('Select issue type', style: textTheme.bodySmall),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.help_outline_rounded)),
              items: _issueTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _issueType = val),
              validator: (val) => val == null ? 'Please select an issue type' : null,
              onSaved: (val) => _issueType = val,
            ),
            const SizedBox(height: 20),

            _FieldLabel(label: 'Urgency Level', icon: Icons.priority_high_rounded),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _urgency,
              hint: Text('Select urgency', style: textTheme.bodySmall),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.flag_outlined)),
              items: _urgencyLevels.map((e) {
                return DropdownMenuItem(value: e, child: Row(children: [Icon(Icons.circle, color: _getUrgencyColor(e), size: 10), const SizedBox(width: 10), Text(e)]));
              }).toList(),
              onChanged: (val) => setState(() => _urgency = val),
              validator: (val) => val == null ? 'Please select urgency' : null,
              onSaved: (val) => _urgency = val,
            ),
            const SizedBox(height: 20),

            _FieldLabel(label: 'Location', icon: Icons.location_on_outlined),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    style: textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Tap to fetch your location',
                      prefixIcon: Icon(_latitude != null ? Icons.location_on : Icons.location_off_outlined, color: _latitude != null ? colorScheme.primary : null),
                    ),
                    controller: TextEditingController(text: _locationText),
                    validator: (val) => _latitude == null ? 'Please fetch location' : null,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _isFetchingLocation ? null : _getLocation,
                  child: _isFetchingLocation
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _FieldLabel(label: 'Photos / Videos', icon: Icons.photo_library_outlined),
            const SizedBox(height: 8),
            FormField<List<XFile>>(
              initialValue: _mediaFiles,
              validator: (files) => null,
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
                                      ? Container(width: 110, height: 110, color: Colors.black12, child: const Icon(Icons.videocam_rounded, size: 40, color: Colors.black45))
                                      : Image.file(File(_mediaFiles[i].path), width: 110, height: 110, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 4, right: 4,
                                  child: GestureDetector(
                                    onTap: () { _removeMedia(i); field.didChange(_mediaFiles); },
                                    child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 18)),
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
                        side: BorderSide(color: colorScheme.primary.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      onPressed: _mediaFiles.length >= 5 ? null : () async { await _pickMedia(); field.didChange(_mediaFiles); },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(_mediaFiles.isEmpty ? 'Add Photo / Video' : 'Add More (${_mediaFiles.length}/5)'),
                    ),
                    if (field.hasError) Padding(padding: const EdgeInsets.only(top: 6, left: 12), child: Text(field.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            _FieldLabel(label: 'Description', icon: Icons.description_outlined),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              style: textTheme.bodyMedium,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Describe the situation in detail...', alignLabelWithHint: true),
              validator: (val) => val == null || val.isEmpty ? 'Please enter a description' : null,
              onChanged: (val) {
                _description = val;
              },
              onSaved: (val) => _description = val!,
            ),

            const SizedBox(height: 16),

            // AI Preview Section
            if (_liveAiSummary != null || _isAnalyzing) ...[
              const SizedBox(height: 12),
              if (_isAnalyzing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('AI is analyzing your report...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else if (_liveAiSummary != null)
                AiSummaryCard(aiSummary: _liveAiSummary!),
              const SizedBox(height: 12),
            ],

            Center(
              child: TextButton.icon(
                onPressed: _isAnalyzing ? null : _generateLiveSummary,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_liveAiSummary == null ? 'Get AI Analysis Preview' : 'Refresh AI Analysis'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded),
                          SizedBox(width: 8),
                          Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
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