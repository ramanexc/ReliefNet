import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StepRejected extends StatelessWidget {
  final Map<String, dynamic> data;
  const StepRejected({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final issue = data['issueType'] ?? 'Unknown Issue';
    final description = data['description'] ?? '';
    final rejectionReason = data['rejectionReason'] ?? 'No reason provided';
    final rejectedAt = data['rejectedAt'] as Timestamp?;
    final reporterName = data['reporterName'] ?? data['userName'] ?? data['submittedByName'] ?? 'Anonymous';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    String rejectedTime = '';
    if (rejectedAt != null) {
      rejectedTime = DateFormat('dd MMM yyyy, hh:mm a').format(rejectedAt.toDate());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Task Declined"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 20,
                    child: Icon(Icons.cancel, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Task Cancelled",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rejectedTime.isNotEmpty ? "Declined on $rejectedTime" : "Declined by volunteer",
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Rejection Reason
            _buildCard(
              context: context,
              title: "REASON FOR DECLINING",
              icon: Icons.info_outline,
              child: Text(
                rejectionReason,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.5, color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),

            // Incident Info
            _buildCard(
              context: context,
              title: "INCIDENT INFORMATION",
              icon: Icons.description_outlined,
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
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Back to Tasks", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
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
