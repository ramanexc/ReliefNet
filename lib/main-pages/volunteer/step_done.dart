import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class StepDone extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  const StepDone({super.key, required this.data, required this.docId});

  @override
  State<StepDone> createState() => _StepDoneState();
}

class _StepDoneState extends State<StepDone> with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    // Trigger confetti after a short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _showConfetti = true);
        _confettiController.forward();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final issue = data['issueType'] ?? 'Unknown Issue';
    final description = data['description'] ?? '';
    final proofMedia = data['proofMedia'] ?? data['proofImage'];
    final proofIsVideo = data['proofIsVideo'] == true;
    final resolutionNote = data['resolutionNote'] ?? 'No resolution notes provided.';
    final resolvedAt = data['resolvedAt'] as Timestamp?;
    final reporterName = data['reporterName'] ?? data['userName'] ?? data['submittedByName'] ?? 'Anonymous';
    final colorScheme = Theme.of(context).colorScheme;

    String resolvedTime = '';
    if (resolvedAt != null) {
      resolvedTime = DateFormat('dd MMM yyyy, hh:mm a').format(resolvedAt.toDate());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Mission Completed"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Celebration Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.verified, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Mission Accomplished!",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        resolvedTime.isNotEmpty ? "Completed on $resolvedTime" : "Successfully resolved",
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Taken / Resolution Note
                _buildCard(
                  context: context,
                  title: "RESOLUTION ACTION TAKEN",
                  icon: Icons.edit_note_outlined,
                  child: Text(
                    resolutionNote,
                    style: const TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),

                // Proof Media
                if (proofMedia != null) ...[
                  _buildCard(
                    context: context,
                    title: proofIsVideo ? "RESOLUTION PROOF VIDEO" : "RESOLUTION PROOF PHOTO",
                    icon: proofIsVideo ? Icons.videocam_outlined : Icons.photo_outlined,
                    child: proofIsVideo
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.play_circle_outline, size: 56, color: Colors.green),
                                const SizedBox(height: 8),
                                const Text(
                                  "Video proof attached",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    final uri = Uri.parse(proofMedia);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text("Open Video"),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              proofMedia,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) => progress == null
                                  ? child
                                  : Container(
                                      height: 200,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Original Incident Report Details
                _buildCard(
                  context: context,
                  title: "ORIGINAL INCIDENT REPORT",
                  icon: Icons.assignment_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              issue,
                              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Reported by $reporterName",
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        description.isNotEmpty ? description : "No description provided.",
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.8), height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Back Button
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text("Done & Go Back", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          
          // Confetti overlay
          if (_showConfetti)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  if (_confettiController.value > 0.9) return const SizedBox.shrink();
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _ConfettiPainter(progress: _confettiController.value),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final _rng = Random(123);

  static final List<_ConfettiParticle> _particles = List.generate(80, (i) {
    return _ConfettiParticle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble() * 0.5,
      size: 5 + _rng.nextDouble() * 12,
      color: [
        Colors.green.shade400,
        Colors.green.shade600,
        Colors.lightGreenAccent.shade400,
        Colors.teal.shade300,
        Colors.amber,
        Colors.orange.shade400,
        Colors.white,
      ][_rng.nextInt(7)],
      shape: _rng.nextInt(3),
      delay: _rng.nextDouble() * 0.3,
      vx: (_rng.nextDouble() - 0.5) * 0.4,
      vy: 0.3 + _rng.nextDouble() * 0.6,
      rotation: _rng.nextDouble() * pi * 2,
      rotSpeed: (_rng.nextDouble() - 0.5) * 10,
    );
  });

  const _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final opacity = t < 0.2 ? t / 0.2 : (1.0 - (t - 0.2) / 0.8).clamp(0.0, 1.0);
      final x = (p.x + p.vx * t) * size.width;
      final y = (p.y + p.vy * t) * size.height;
      final currentSize = p.size * (1.0 + t * 0.3);
      final angle = p.rotation + p.rotSpeed * t;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.toDouble())
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      switch (p.shape) {
        case 0: // circle
          canvas.drawCircle(Offset.zero, currentSize / 2, paint);
          break;
        case 1: // star/cross
          final path = Path();
          for (int j = 0; j < 4; j++) {
            final a = j * pi / 2;
            path.moveTo(0, 0);
            path.lineTo(cos(a) * currentSize / 2, sin(a) * currentSize / 2);
          }
          canvas.drawPath(
            path,
            paint
              ..strokeWidth = 2.5
              ..style = PaintingStyle.stroke,
          );
          break;
        case 2: // rect
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: currentSize, height: currentSize * 0.6),
              const Radius.circular(2),
            ),
            paint,
          );
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _ConfettiParticle {
  final double x, y, size, delay, vx, vy, rotation, rotSpeed;
  final Color color;
  final int shape;

  const _ConfettiParticle({
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
