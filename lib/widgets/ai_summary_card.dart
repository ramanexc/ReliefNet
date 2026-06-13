import 'package:flutter/material.dart';

/// Reusable card that displays Gemini AI analysis for a report.
/// Used in: confirmation dialog, dashboard detail sheet, volunteer task detail.
class AiSummaryCard extends StatelessWidget {
  final Map<String, dynamic> aiSummary;
  final bool
  compact; // compact = true for dashboard list cards (just skillset chips)

  const AiSummaryCard({
    super.key,
    required this.aiSummary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skills = List<String>.from(aiSummary['skillset_required'] ?? []);
    final solutions = List<String>.from(aiSummary['solutions'] ?? []);
    final summary = aiSummary['summary'] as String?;
    final priority = aiSummary['action_priority'] as String?;
    final affected = aiSummary['estimated_people_affected'] as String?;

    final priorityColor = _priorityColor(priority);

    if (compact) {
      // ── Mini version: just the skillset chips row ──────────────────────
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 12, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                'Skills needed:',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          ...skills.map((s) => _SkillChip(label: s)),
        ],
      );
    }

    // ── Full version: used in detail sheets ───────────────────────────────
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        border: Border.all(color: Colors.blue.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 15, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'AI Analysis',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Powered by Gemini',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Summary
          if (summary != null) ...[
            Text(
              summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Action priority badge
          if (priority != null) ...[
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 15, color: priorityColor),
                const SizedBox(width: 6),
                Text(
                  'Action Priority: ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: priorityColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // People affected
          if (affected != null) ...[
            Row(
              children: [
                const Icon(Icons.people_outline, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Est. Affected: ',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  affected,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Solutions
          if (solutions.isNotEmpty) ...[
            const Text(
              'Suggested Solutions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...solutions.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        e.value,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Skillset chips
          if (skills.isNotEmpty) ...[
            const Text(
              'Skills Required',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: skills.map((s) => _SkillChip(label: s)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _priorityColor(String? priority) {
    if (priority == null) return Colors.grey;
    if (priority.toLowerCase().contains('immediate')) return Colors.red;
    if (priority.toLowerCase().contains('24')) return Colors.orange;
    return Colors.green;
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.handshake_outlined, size: 11, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
