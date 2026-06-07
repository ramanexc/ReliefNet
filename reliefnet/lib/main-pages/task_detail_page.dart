import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

class TaskDetailPage extends StatelessWidget {
  final String docId;
  const TaskDetailPage({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .doc(docId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'assigned';

        if (status == 'completed') {
          return _CompletedDetailPage(data: data, docId: docId);
        }
        if (status == 'rejected') {
          return _RejectedDetailPage(data: data);
        }

        // ✅ Use a fixed key so Flutter reuses the widget instead of recreating it
        return _ActiveDetailPage(
          key: ValueKey(docId),
          data: data,
          docId: docId,
        );
      },
    );
  }
}

// ─── ACTIVE DETAIL PAGE ──────────────────────────────────────────────────────

class _ActiveDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _ActiveDetailPage({
    super.key,
    required this.data,
    required this.docId,
  }); // add super.key

  @override
  State<_ActiveDetailPage> createState() => _ActiveDetailPageState();
}

class _ActiveDetailPageState extends State<_ActiveDetailPage> {
  bool _locationChecking = false;

  Future<void> _updateStatus(String status) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.docId)
        .update({'status': status});
  }

  Future<void> _handleDecline() async {
    final reasonController = TextEditingController();
    bool showError = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Decline this task?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Please give a reason. This helps the NGO reassign appropriately.",
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                onChanged: (_) {
                  if (showError) setDialog(() => showError = false);
                },
                decoration: InputDecoration(
                  hintText: "e.g. Can't reach location, wrong skill set...",
                  filled: true,
                  errorText: showError ? "Please provide a reason." : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  setDialog(() => showError = true);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text(
                "Decline",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (confirmed != true) return;

    final reason = reasonController.text.trim();

    Navigator.pop(context);

    await FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.docId)
        .update({
          'status': 'rejected',
          'rejectionReason': reason,
          'rejectedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _handleReached() async {
    final lat = widget.data['lat'];
    final lng = widget.data['lng'];

    // No coords on report — just update
    if (lat == null || lng == null) {
      await _updateStatus('reached');
      return;
    }

    setState(() => _locationChecking = true);

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() => _locationChecking = false);
        _showLocationDialog(
          icon: Icons.location_off,
          iconColor: Colors.red,
          title: "Location Permission Denied",
          body:
              "Can't verify your location. Grant location permission in settings to continue.",
          canOverride: false,
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final distMeters = _haversineDistance(
        pos.latitude,
        pos.longitude,
        (lat as num).toDouble(),
        (lng as num).toDouble(),
      );

      setState(() => _locationChecking = false);

      if (distMeters <= 1000) {
        // Within 1km — confirmed
        await _updateStatus('reached');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    distMeters < 1000
                        ? "Location verified! ${distMeters.round()}m from the site."
                        : "Location verified! You're at the site.",
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        // Beyond 1km — hard block with exact distance shown
        _showLocationDialog(
          icon: Icons.wrong_location_outlined,
          iconColor: Colors.red,
          title: "Too Far Away",
          body:
              "You are ${(distMeters / 1000).toStringAsFixed(1)}km from the incident site.\n\nYou must be within 1km to mark yourself as reached. Please travel to the location first.",
          canOverride: false,
        );
      }
    } catch (e) {
      setState(() => _locationChecking = false);
      // GPS error — allow override so volunteers aren't blocked by device issues
      _showLocationDialog(
        icon: Icons.gps_off,
        iconColor: Colors.orange,
        title: "GPS Error",
        body:
            "Couldn't get your location ($e). You can still proceed manually if you're sure you've arrived.",
        canOverride: true,
        onOverride: () => _updateStatus('reached'),
      );
    }
  }

  void _showLocationDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required bool canOverride,
    VoidCallback? onOverride,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
          ],
        ),
        content: Text(body, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
          if (canOverride && onOverride != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onOverride();
              },
              child: const Text(
                "Proceed Anyway",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showResolveSheet() async {
    File? proofFile;
    bool isVideo = false;
    final noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text(
                  "Mark as Resolved",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Describe what was done. Photo/video proof is optional but encouraged.",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Media picker area
                GestureDetector(
                  onTap: () async {
                    final choice = await showModalBottomSheet<String>(
                      context: ctx,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _MediaPickerOptions(),
                    );
                    if (choice == null) return;

                    final picker = ImagePicker();
                    if (choice == 'photo_camera') {
                      final picked = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (picked != null) {
                        setSheet(() {
                          proofFile = File(picked.path);
                          isVideo = false;
                        });
                      }
                    } else if (choice == 'photo_gallery') {
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (picked != null) {
                        setSheet(() {
                          proofFile = File(picked.path);
                          isVideo = false;
                        });
                      }
                    } else if (choice == 'video_camera') {
                      final picked = await picker.pickVideo(
                        source: ImageSource.camera,
                      );
                      if (picked != null) {
                        setSheet(() {
                          proofFile = File(picked.path);
                          isVideo = true;
                        });
                      }
                    } else if (choice == 'video_gallery') {
                      final picked = await picker.pickVideo(
                        source: ImageSource.gallery,
                      );
                      if (picked != null) {
                        setSheet(() {
                          proofFile = File(picked.path);
                          isVideo = true;
                        });
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: proofFile != null ? (isVideo ? 120 : 180) : 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: proofFile != null
                            ? Colors.green.shade400
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: proofFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                isVideo
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.videocam,
                                            size: 40,
                                            color: Colors.green.shade600,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Video selected",
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            proofFile!.path.split('/').last,
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      )
                                    : Image.file(proofFile!, fit: BoxFit.cover),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setSheet(() => proofFile = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
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
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 28,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.videocam_outlined,
                                    size: 28,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Tap to add photo or video (optional)",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "What was done? How was it resolved?",
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.green.shade400,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                _SubmitButton(
                  docId: widget.docId,
                  proofFile: proofFile,
                  isVideo: isVideo,
                  noteController: noteController,
                  onSuccess: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final issue = data['issueType'] ?? 'Unknown Issue';
    final description = data['description'] ?? '';
    final status = data['status'] ?? 'assigned';
    final lat = data['lat'];
    final lng = data['lng'];
    final address = data['address'] ?? data['location'] ?? '';
    // FIX: show username/name not UID
    final reporterName =
        data['reporterName'] ??
        data['userName'] ??
        data['submittedByName'] ??
        '';
    final color = _issueColor(issue);
    final icon = _issueIcon(issue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final steps = ['assigned', 'in_progress', 'reached', 'completed'];
    final currentStep = steps.indexOf(status).clamp(0, 3);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: color,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(
                issue: issue,
                status: _statusLabel(status),
                icon: icon,
                color: color,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FlowStepper(currentStep: currentStep),
                  const SizedBox(height: 20),

                  _SectionCard(
                    title: "REPORT DETAILS",
                    icon: Icons.description_outlined,
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description.isEmpty
                              ? "No description provided."
                              : description,
                          style: const TextStyle(fontSize: 15, height: 1.7),
                        ),
                        if (reporterName.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Divider(color: Colors.grey.shade200),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: color.withOpacity(0.12),
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Reported by",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    reporterName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (lat != null && lng != null)
                    _SectionCard(
                      title: "INCIDENT LOCATION",
                      icon: Icons.location_on_outlined,
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (address.isNotEmpty) ...[
                            Text(
                              address,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            "${(lat as num).toStringAsFixed(5)}, ${(lng as num).toStringAsFixed(5)}",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.blue.shade400),
                                foregroundColor: Colors.blue.shade600,
                              ),
                              onPressed: () async {
                                final uri = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                                );
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              icon: const Icon(Icons.navigation_outlined),
                              label: const Text(
                                "Open in Google Maps",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),

                  // ── Action area ──
                  // Replace the entire action area block (the if-status checks at the bottom of build)
                  if (status == 'assigned') ...[
                    _ActionButton(
                      label: "Accept & Start",
                      icon: Icons.directions_run,
                      color: Colors.blue.shade600,
                      onTap: () => _updateStatus('in_progress'),
                    ),
                    const SizedBox(height: 12),
                    _OutlineActionButton(
                      label: "Decline Task",
                      color: Colors.red,
                      onTap: () => Future.microtask(() => _handleDecline()),
                    ),
                  ],

                  if (status == 'in_progress') ...[
                    if (_locationChecking)
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              "Verifying your location...",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    else
                      _ActionButton(
                        label: "I've Reached the Site",
                        icon: Icons.location_on,
                        color: Colors.orange.shade700,
                        onTap: _handleReached,
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "You must be within 1km of the site to confirm arrival.",
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _OutlineActionButton(
                      label: "Decline Task",
                      color: Colors.red,
                      onTap: () => Future.microtask(() => _handleDecline()),
                    ),
                  ],

                  if (status == 'reached') ...[
                    _ActionButton(
                      label: "Mark as Resolved",
                      icon: Icons.check_circle_outline,
                      color: Colors.green.shade700,
                      onTap: _showResolveSheet,
                    ),
                    const SizedBox(height: 12),
                    _OutlineActionButton(
                      label: "Decline Task",
                      color: Colors.red,
                      onTap: () => Future.microtask(() => _handleDecline()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Media Picker Bottom Sheet Options ───────────────────────────────────────

class _MediaPickerOptions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Add Proof",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PickerOption(
                  icon: Icons.camera_alt_outlined,
                  label: "Camera\nPhoto",
                  color: Colors.blue,
                  onTap: () => Navigator.pop(context, 'photo_camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerOption(
                  icon: Icons.photo_library_outlined,
                  label: "Gallery\nPhoto",
                  color: Colors.purple,
                  onTap: () => Navigator.pop(context, 'photo_gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerOption(
                  icon: Icons.videocam_outlined,
                  label: "Camera\nVideo",
                  color: Colors.orange,
                  onTap: () => Navigator.pop(context, 'video_camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerOption(
                  icon: Icons.video_library_outlined,
                  label: "Gallery\nVideo",
                  color: Colors.green,
                  onTap: () => Navigator.pop(context, 'video_gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Submit button (own StatefulWidget for loading state) ────────────────────

class _SubmitButton extends StatefulWidget {
  final String docId;
  final File? proofFile;
  final bool isVideo;
  final TextEditingController noteController;
  final VoidCallback onSuccess;

  const _SubmitButton({
    required this.docId,
    required this.proofFile,
    required this.isVideo,
    required this.noteController,
    required this.onSuccess,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _loading = false;

  Future<void> _submit() async {
    if (widget.noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please describe what was done.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      String? proofUrl;

      if (widget.proofFile != null) {
        final ext = widget.isVideo ? 'mp4' : 'jpg';
        final ref = FirebaseStorage.instance.ref().child(
          'proof/${widget.docId}_${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        await ref.putFile(widget.proofFile!);
        proofUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.docId)
          .update({
            'status': 'completed',
            'proofMedia': ?proofUrl,
            if (widget.isVideo) 'proofIsVideo': true,
            'resolutionNote': widget.noteController.text.trim(),
            'resolvedAt': FieldValue.serverTimestamp(),
          });

      widget.onSuccess();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        onPressed: _loading ? null : _submit,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle),
        label: Text(
          _loading ? "Submitting..." : "Submit & Complete",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

// ─── COMPLETED DETAIL PAGE ───────────────────────────────────────────────────

class _CompletedDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _CompletedDetailPage({required this.data, required this.docId});

  @override
  State<_CompletedDetailPage> createState() => _CompletedDetailPageState();
}

class _CompletedDetailPageState extends State<_CompletedDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _graffitiController;
  bool _showGraffiti = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '🟢 _ActiveDetailPage initialized, status: ${widget.data['status']}',
    );

    _graffitiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Trigger graffiti after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _showGraffiti = true);
        _graffitiController.forward();
      }
    });
  }

  @override
  void dispose() {
    _graffitiController.dispose();
    debugPrint('🔴 _ActiveDetailPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final issue = data['issueType'] ?? 'Unknown';
    final description = data['description'] ?? '';
    // Supports both old 'proofImage' field and new 'proofMedia'
    final proofMedia = data['proofMedia'] ?? data['proofImage'];
    final proofIsVideo = data['proofIsVideo'] == true;
    final resolutionNote = data['resolutionNote'] ?? '';
    final resolvedAt = data['resolvedAt'] as Timestamp?;
    final reporterName =
        data['reporterName'] ??
        data['userName'] ??
        data['submittedByName'] ??
        '';
    final color = _issueColor(issue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String resolvedTime = '';
    if (resolvedAt != null) {
      resolvedTime = DateFormat(
        'dd MMM yyyy, hh:mm a',
      ).format(resolvedAt.toDate());
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: Colors.green.shade600,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: _CompletedHeroHeader(
                    issue: issue,
                    resolvedTime: resolvedTime,
                    controller: _graffitiController,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Completion banner ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade600,
                              Colors.green.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Mission Accomplished!",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  if (resolvedTime.isNotEmpty)
                                    Text(
                                      resolvedTime,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Report ──
                      _SectionCard(
                        title: "INCIDENT REPORT",
                        icon: Icons.description_outlined,
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              description.isEmpty
                                  ? "No description."
                                  : description,
                              style: const TextStyle(fontSize: 15, height: 1.7),
                            ),
                            if (reporterName.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Divider(color: Colors.grey.shade200),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: color.withOpacity(0.12),
                                    child: Icon(
                                      Icons.person,
                                      size: 16,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Reported by",
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        reporterName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Resolution note ──
                      if (resolutionNote.isNotEmpty)
                        _SectionCard(
                          title: "VOLUNTEER'S RESOLUTION NOTE",
                          icon: Icons.edit_note_outlined,
                          isDark: isDark,
                          accentColor: Colors.green.shade600,
                          child: Text(
                            resolutionNote,
                            style: const TextStyle(fontSize: 15, height: 1.7),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // ── Proof media ──
                      if (proofMedia != null)
                        _SectionCard(
                          title: proofIsVideo ? "PROOF VIDEO" : "PROOF PHOTO",
                          icon: proofIsVideo
                              ? Icons.videocam_outlined
                              : Icons.photo_outlined,
                          isDark: isDark,
                          child: proofIsVideo
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.play_circle_outline,
                                        size: 52,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Video proof attached",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final uri = Uri.parse(proofMedia);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text("Open Video"),
                                      ),
                                    ],
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    proofMedia,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (ctx, child, progress) =>
                                        progress == null
                                        ? child
                                        : SizedBox(
                                            height: 200,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value:
                                                    progress.expectedTotalBytes !=
                                                        null
                                                    ? progress.cumulativeBytesLoaded /
                                                          progress
                                                              .expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Graffiti confetti overlay ──
          if (_showGraffiti)
            IgnorePointer(
              child: _GraffitiOverlay(controller: _graffitiController),
            ),
        ],
      ),
    );
  }
}

// ─── Graffiti / Celebration overlay ─────────────────────────────────────────

class _GraffitiOverlay extends StatelessWidget {
  final AnimationController controller;
  const _GraffitiOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        if (controller.value > 0.85) return const SizedBox();
        return CustomPaint(
          size: Size.infinite,
          painter: _GraffitiPainter(progress: controller.value),
        );
      },
    );
  }
}

class _GraffitiPainter extends CustomPainter {
  final double progress;
  static final _rng = Random(42);

  static final List<_Particle> _particles = List.generate(60, (i) {
    return _Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble() * 0.6,
      size: 6 + _rng.nextDouble() * 14,
      color: [
        Colors.green.shade400,
        Colors.green.shade600,
        Colors.teal.shade400,
        Colors.lightGreen.shade300,
        Colors.yellow.shade600,
        Colors.white,
        Colors.greenAccent.shade400,
      ][_rng.nextInt(7)],
      shape: _rng.nextInt(3), // 0=circle, 1=star, 2=rect
      delay: _rng.nextDouble() * 0.4,
      vx: (_rng.nextDouble() - 0.5) * 0.3,
      vy: 0.2 + _rng.nextDouble() * 0.6,
      rotation: _rng.nextDouble() * pi * 2,
      rotSpeed: (_rng.nextDouble() - 0.5) * 8,
    );
  });

  const _GraffitiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final opacity = t < 0.3 ? t / 0.3 : (1 - (t - 0.3) / 0.7).clamp(0.0, 1.0);
      final x = (p.x + p.vx * t) * size.width;
      final y = (p.y + p.vy * t) * size.height;
      final currentSize = p.size * (1 + t * 0.5);
      final angle = p.rotation + p.rotSpeed * t;

      final paint = Paint()
        ..color = p.color.withOpacity(opacity.toDouble())
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      switch (p.shape) {
        case 0: // circle
          canvas.drawCircle(Offset.zero, currentSize / 2, paint);
          break;
        case 1: // star / cross
          final path = Path();
          for (int j = 0; j < 4; j++) {
            final a = j * pi / 2;
            path.moveTo(0, 0);
            path.lineTo(cos(a) * currentSize / 2, sin(a) * currentSize / 2);
          }
          canvas.drawPath(
            path,
            paint
              ..strokeWidth = 3
              ..style = PaintingStyle.stroke,
          );
          break;
        case 2: // rounded rect
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: currentSize,
                height: currentSize * 0.5,
              ),
              const Radius.circular(3),
            ),
            paint,
          );
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GraffitiPainter old) => old.progress != progress;
}

class _Particle {
  final double x, y, size, delay, vx, vy, rotation, rotSpeed;
  final Color color;
  final int shape;

  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.shape,
    required this.delay,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotSpeed,
  });
}

// ─── Completed Hero Header with graffiti stamp ───────────────────────────────

class _CompletedHeroHeader extends StatelessWidget {
  final String issue;
  final String resolvedTime;
  final AnimationController controller;

  const _CompletedHeroHeader({
    required this.issue,
    required this.resolvedTime,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade800, Colors.green.shade500],
        ),
      ),
      child: Stack(
        children: [
          // Big faded check in background
          Positioned(
            right: -30,
            bottom: -30,
            child: Icon(
              Icons.check_circle_rounded,
              size: 180,
              color: Colors.white.withOpacity(0.06),
            ),
          ),

          // Animated "DONE" stamp
          Positioned(
            right: 20,
            top: 50,
            child: AnimatedBuilder(
              animation: controller,
              builder: (_, _) {
                final t = Curves.elasticOut.transform(
                  controller.value.clamp(0.0, 1.0),
                );
                return Transform.scale(
                  scale: t,
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Text(
                        "RESOLVED",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned(
            left: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "✓ Task Complete",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  issue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (resolvedTime.isNotEmpty)
                  Text(
                    resolvedTime,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── REJECTED DETAIL PAGE ────────────────────────────────────────────────────

class _RejectedDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RejectedDetailPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final issue = data['issueType'] ?? 'Unknown';
    final description = data['description'] ?? '';
    final reporterName =
        data['reporterName'] ??
        data['userName'] ??
        data['submittedByName'] ??
        '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.red.shade600,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.red.shade800, Colors.red.shade400],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.cancel_rounded,
                        size: 170,
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Task Declined",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            issue,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(isDark ? 0.15 : 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "This task was declined. The NGO has been notified and will reassign it to another volunteer.",
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _SectionCard(
                    title: "INCIDENT REPORT",
                    icon: Icons.description_outlined,
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description.isEmpty ? "No description." : description,
                          style: const TextStyle(fontSize: 15, height: 1.7),
                        ),
                        if (reporterName.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Divider(color: Colors.grey.shade200),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.red.withOpacity(0.12),
                                child: const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Reported by",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    reporterName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SHARED WIDGETS ──────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String issue;
  final String status;
  final IconData icon;
  final Color color;

  const _HeroHeader({
    required this.issue,
    required this.status,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.95), color.withOpacity(0.65)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(icon, size: 170, color: Colors.white.withOpacity(0.07)),
          ),
          Positioned(
            left: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        issue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStepper extends StatelessWidget {
  final int currentStep;
  const _FlowStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = [
      (Icons.assignment_outlined, "Assigned", Colors.blue.shade600),
      (Icons.directions_run, "En Route", Colors.orange.shade700),
      (Icons.location_on, "Reached", Colors.purple.shade600),
      (Icons.check_circle_outline, "Done", Colors.green.shade600),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length, (i) {
          final (icon, label, color) = steps[i];
          final isActive = i <= currentStep;
          final isCurrent = i == currentStep;
          final isLast = i == steps.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        width: isCurrent ? 42 : 32,
                        height: isCurrent ? 42 : 32,
                        decoration: BoxDecoration(
                          color: isActive
                              ? color
                              : (isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200),
                          shape: BoxShape.circle,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.45),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          icon,
                          size: isCurrent ? 20 : 15,
                          color: isActive ? Colors.white : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive ? color : Colors.grey.shade400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: i < currentStep
                            ? LinearGradient(
                                colors: [steps[i].$3, steps[i + 1].$3],
                              )
                            : null,
                        color: i < currentStep
                            ? null
                            : (isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade200),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool isDark;
  final Color? accentColor;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: accentColor != null
            ? Border.all(color: accentColor!.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor ?? Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: accentColor ?? Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─── Utilities ───────────────────────────────────────────────────────────────

String _statusLabel(String s) {
  switch (s) {
    case 'assigned':
      return 'Assigned';
    case 'in_progress':
      return 'En Route';
    case 'reached':
      return 'On Site';
    default:
      return 'Unknown';
  }
}

Color _issueColor(String type) {
  switch (type.toLowerCase()) {
    case 'medical':
      return Colors.red.shade600;
    case 'food':
      return Colors.orange.shade700;
    case 'shelter':
      return Colors.indigo.shade600;
    case 'fire':
      return Colors.deepOrange.shade600;
    case 'water':
      return Colors.blue.shade600;
    default:
      return Colors.blueGrey.shade600;
  }
}

IconData _issueIcon(String type) {
  switch (type.toLowerCase()) {
    case 'medical':
      return Icons.medical_services;
    case 'food':
      return Icons.fastfood;
    case 'shelter':
      return Icons.house;
    case 'fire':
      return Icons.local_fire_department;
    case 'water':
      return Icons.water_drop;
    default:
      return Icons.report_problem;
  }
}

double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _toRad(double deg) => deg * pi / 180;
