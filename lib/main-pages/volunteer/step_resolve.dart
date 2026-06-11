import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class StepResolve extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onSuccess;
  const StepResolve({super.key, required this.docId, required this.data, required this.onSuccess});

  @override
  State<StepResolve> createState() => _StepResolveState();
}

class _StepResolveState extends State<StepResolve> with AutomaticKeepAliveClientMixin {
  File? _proofFile;
  bool _isVideo = false;
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _mediaError;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Add Resolution Proof",
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Proof of resolution is mandatory to resolve this task.",
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.camera_alt_outlined,
                    label: "Camera\nPhoto",
                    color: Colors.blue,
                    onTap: () => Navigator.pop(ctx, 'photo_camera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.photo_library_outlined,
                    label: "Gallery\nPhoto",
                    color: Colors.purple,
                    onTap: () => Navigator.pop(ctx, 'photo_gallery'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.videocam_outlined,
                    label: "Camera\nVideo",
                    color: Colors.orange,
                    onTap: () => Navigator.pop(ctx, 'video_camera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.video_library_outlined,
                    label: "Gallery\nVideo",
                    color: Colors.green,
                    onTap: () => Navigator.pop(ctx, 'video_gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;
    final picker = ImagePicker();
    XFile? picked;
    bool isVideoPicked = false;

    if (choice == 'photo_camera') {
      picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    } else if (choice == 'photo_gallery') {
      picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    } else if (choice == 'video_camera') {
      picked = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
      isVideoPicked = true;
    } else if (choice == 'video_gallery') {
      picked = await picker.pickVideo(source: ImageSource.gallery);
      isVideoPicked = true;
    }

    if (picked != null) {
      setState(() {
        _proofFile = File(picked!.path);
        _isVideo = isVideoPicked;
        _mediaError = null;
      });
    }
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitResolution() async {
    setState(() {
      _mediaError = null;
    });

    final hasNote = _formKey.currentState!.validate();
    if (_proofFile == null) {
      setState(() {
        _mediaError = "Proof image or video is mandatory.";
      });
      return;
    }

    if (!hasNote) return;

    setState(() => _isSubmitting = true);

    // Enforce 1km Geofence Check strictly before completing task
    try {
      final reportLat = (widget.data['lat'] as num?)?.toDouble();
      final reportLng = (widget.data['lng'] as num?)?.toDouble();

      if (reportLat != null && reportLng != null) {
        // Check Location Permissions
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          setState(() => _isSubmitting = false);
          _showLocationWarning("Location permission is required to verify your proximity before completing the task.");
          return;
        }

        // Get live coordinates
        Position currentPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        double dist = Geolocator.distanceBetween(currentPos.latitude, currentPos.longitude, reportLat, reportLng);

        if (dist > 1000) {
          setState(() => _isSubmitting = false);
          _showLocationWarning(
            "Geofence verification failed. You are currently ${(dist / 1000).toStringAsFixed(2)} km away.\n\nYou must remain within a 1km radius of the incident to mark this task as resolved.",
          );
          return;
        }
      }
    } catch (e) {
      // If GPS fails, alert user but enforce security
      setState(() => _isSubmitting = false);
      _showLocationWarning("Proximity check failed. Could not retrieve GPS lock. Please check your signal.");
      return;
    }

    // Proximity verified - proceed with Storage upload and Firestore update
    try {
      String? proofUrl;
      if (_proofFile != null) {
        final ext = _isVideo ? 'mp4' : 'jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('proof/${widget.docId}_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await ref.putFile(_proofFile!);
        proofUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('reports').doc(widget.docId).update({
        'status': 'completed',
        'proofMedia': proofUrl,
        if (_isVideo) 'proofIsVideo': true,
        'resolutionNote': _noteController.text.trim(),
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      widget.onSuccess();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLocationWarning(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.wrong_location, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text("Proximity Denied"),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by KeepAlive
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Step 3: Resolve Incident",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Please complete the task by providing your notes and mandatory proof of resolution.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            // Mandatory Media Upload Area
            const Row(
              children: [
                Icon(Icons.add_a_photo, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "SUBMIT PROOF (MANDATORY)",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.green),
                ),
                SizedBox(width: 4),
                Text("*", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            
            GestureDetector(
              onTap: _isSubmitting ? null : _pickMedia,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _proofFile != null ? (_isVideo ? 140 : 200) : 130,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _mediaError != null
                        ? Colors.red
                        : (_proofFile != null ? Colors.green : colorScheme.outline.withValues(alpha: 0.3)),
                    width: 2,
                  ),
                ),
                child: _proofFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _isVideo
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.videocam, size: 48, color: Colors.green),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Resolution Video Selected",
                                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _proofFile!.path.split('/').last,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  )
                                : Image.file(_proofFile!, fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _proofFile = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 30, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                              const SizedBox(width: 14),
                              Icon(Icons.videocam_outlined, size: 30, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Tap to capture Photo or Video",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Files must show clear resolution proof",
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
              ),
            ),
            if (_mediaError != null) ...[
              const SizedBox(height: 8),
              Text(
                _mediaError!,
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 24),

            // Resolution note input field
            const Row(
              children: [
                Icon(Icons.edit_note, size: 16),
                SizedBox(width: 8),
                Text(
                  "RESOLUTION NOTES",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                SizedBox(width: 4),
                Text("*", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteController,
              maxLines: 4,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: "Detail the specific actions taken to resolve this crisis... (e.g. food distributed, medical aid rendered)",
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? "Notes are required to complete the task." : null,
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _submitResolution,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _isSubmitting ? "Uploading Proof & Completing..." : "Submit Proof & Complete Task",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
