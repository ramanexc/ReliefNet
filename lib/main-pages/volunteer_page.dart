import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_detail_page.dart';
import 'package:reliefnet/l10n/app_localizations.dart';

class VolunteerPage extends StatelessWidget {
  const VolunteerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!;
    if (user == null) {
      return Center(child: Text(l10n.please_login));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          centerTitle: true,
          // title: Text(
          //   l10n.my_tasks,
          //   style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, letterSpacing: -0.5),
          // ),
          title: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? const Color(0xFF334155) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                labelColor: isDark ? Colors.white : colorScheme.primary,
                unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins'),
                tabs: [
                  Tab(text: l10n.active),
                  Tab(text: l10n.completed),
                  Tab(text: l10n.rejected),
                ],
              ),
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .where('assignedVolunteers', arrayContains: user.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText("Error: ${snapshot.error}"),
                ),
              );
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final docs = snapshot.data!.docs;
            final activeTasks = docs.where((d) {
              final s = (d.data() as Map<String, dynamic>)['status'] as String?;
              return s == 'assigned' || s == 'in_progress' || s == 'reached';
            }).toList();
            final completedTasks = docs.where((d) => d['status'] == 'completed').toList();
            final rejectedTasks = docs.where((d) => d['status'] == 'rejected').toList();

            return TabBarView(
              children: [
                _TaskGrid(tasks: activeTasks, emptyMessage: l10n.no_active_tasks, emptyIcon: Icons.assignment_outlined, l10n: l10n),
                _TaskGrid(tasks: completedTasks, emptyMessage: l10n.no_completed_tasks, emptyIcon: Icons.check_circle_outline, l10n: l10n),
                _TaskGrid(tasks: rejectedTasks, emptyMessage: l10n.no_rejected_tasks, emptyIcon: Icons.cancel_outlined, l10n: l10n),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TaskGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot> tasks;
  final String emptyMessage;
  final IconData emptyIcon;
  final AppLocalizations l10n;

  const _TaskGrid({required this.tasks, required this.emptyMessage, required this.emptyIcon, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, size: 56, color: colorScheme.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 18),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 4),
            Text(
              "No items to show in this section.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: tasks.length,
      itemBuilder: (context, i) => _TaskCard(doc: tasks[i], l10n: l10n),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final AppLocalizations l10n;
  const _TaskCard({required this.doc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final issue = data['issueType'] ?? 'Unknown';
    final description = data['description'] ?? '';
    final status = data['status'] ?? 'assigned';
    final urgency = data['urgency'] ?? 'Low';
    final timestamp = data['timestamp'] as Timestamp?;
    String address = '';

    if (data['address'] != null && data['address'] is String) {
      address = data['address'];
    } else if (data['location'] != null) {
      final loc = data['location'];
      if (loc is GeoPoint) {
        address = "Coordinates: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}";
      } else if (loc is String) {
        address = loc;
      }
    } else if (data['lat'] != null && data['lng'] != null) {
      address = "Coordinates: ${(data['lat'] as num).toStringAsFixed(4)}, ${(data['lng'] as num).toStringAsFixed(4)}";
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final statusMap = {
      'assigned': (const Color(0xFF3B82F6), l10n.assigned, Icons.assignment_ind_rounded, 0),
      'in_progress': (const Color(0xFFF59E0B), l10n.en_route, Icons.directions_run_rounded, 1),
      'reached': (const Color(0xFF8B5CF6), l10n.on_site, Icons.location_on_rounded, 2),
      'completed': (const Color(0xFF10B981), l10n.completed, Icons.check_circle_rounded, 3),
      'rejected': (const Color(0xFFEF4444), l10n.declined, Icons.cancel_rounded, 0),
    };
    final statusEntry = statusMap[status] ?? (Colors.grey.shade600, 'Unknown', Icons.help_outline_rounded, 0);

    String localizedIssue = issue;
    if (issue == 'Food') {
      localizedIssue = l10n.food;
    } else if (issue == 'Medical') {
      localizedIssue = l10n.medical;
    } else if (issue == 'Shelter') {
      localizedIssue = l10n.shelter;
    } else if (issue == 'Other') {
      localizedIssue = l10n.other;
    }

    String localizedUrgency = urgency;
    if (urgency == 'High') {
      localizedUrgency = l10n.high;
    } else if (urgency == 'Medium') {
      localizedUrgency = l10n.medium;
    } else if (urgency == 'Low') {
      localizedUrgency = l10n.low;
    }

    final urgencyColor = _urgencyColor(urgency);
    final issueColor = _issueColor(issue);
    final issueIcon = _issueIcon(issue);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
        border: Border.all(color: colorScheme.outline.withValues(alpha: isDark ? 0.08 : 0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            // Left urgency bar accent
            Container(
              width: 5,
              height: 180,
              decoration: BoxDecoration(
                color: urgencyColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
              ),
            ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailPage(docId: doc.id))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Card Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: issueColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(issueIcon, color: issueColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizedIssue,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface, letterSpacing: -0.4),
                                  ),
                                  if (timestamp != null)
                                    Text(
                                      _formatDate(timestamp.toDate(), l10n),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _StatusBadge(label: statusEntry.$2, color: statusEntry.$1, icon: statusEntry.$3),
                                const SizedBox(height: 4),
                                _UrgencyBadge(label: localizedUrgency, color: urgencyColor),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Description
                        if (description.isNotEmpty)
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                              color: colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Progress Step Bar (active only)
                        if (status != 'rejected' && status != 'completed') ...[
                          _buildStepBar(statusEntry.$4),
                          const SizedBox(height: 12),
                        ],

                        // Card Footer (Address & ID)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address.isNotEmpty ? address : "No address details",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "ID: ${doc.id.substring(0, 8).toUpperCase()}",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBar(int activeIdx) {
    return Row(
      children: List.generate(3, (idx) {
        final isCompleted = idx < activeIdx;
        final isCurrent = idx == activeIdx;
        Color stepColor = Colors.grey.shade300;
        if (isCompleted) {
          stepColor = Colors.green.shade500;
        } else if (isCurrent) {
          stepColor = Colors.blue.shade500;
        }
        
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: stepColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return l10n.today;
    if (diff.inDays == 1) return l10n.yesterday;
    return "${date.day}/${date.month}/${date.year}";
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusBadge({required this.label, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _UrgencyBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}

Color _urgencyColor(String urgency) {
  switch (urgency) {
    case 'High':
      return Colors.red.shade600;
    case 'Medium':
      return Colors.amber.shade700;
    case 'Low':
      return Colors.green.shade600;
    default:
      return Colors.grey;
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
