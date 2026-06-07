import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reliefnet/main-pages/dashboard_page.dart';
import 'package:reliefnet/secondary-pages/profile_page.dart';
import 'package:reliefnet/main-pages/report_page.dart';
import 'package:reliefnet/secondary-pages/settings_page.dart';
import 'package:reliefnet/main-pages/volunteer_page.dart';
import 'package:reliefnet/main-pages/apply_volunteer_page.dart';
import 'package:reliefnet/components/app_bar.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int selectedindex = 0;
  bool _isVolunteer = false;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeContent(
        isVolunteer: _isVolunteer,
        onNavigateToReport: () => setState(() => selectedindex = 1),
        onNavigateToApply: () => setState(() => selectedindex = 4),
        onNavigateToVolunteer: () => setState(() => selectedindex = 3),
      ),
      const ReportPage(),
      const DashboardPage(),
      const VolunteerPage(),
      const ApplyVolunteerPage(),
      const ProfilePage(),
      const SettingsPage(),
    ];
    _checkVolunteerStatus();
  }

  Future<void> _checkVolunteerStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _isVolunteer = doc.data()?['isVolunteer'] ?? false;
            // Update the HomeContent within the list when status changes
            _pages[0] = HomeContent(
              isVolunteer: _isVolunteer,
              onNavigateToReport: () => setState(() => selectedindex = 1),
              onNavigateToApply: () => setState(() => selectedindex = 4),
              onNavigateToVolunteer: () => setState(() => selectedindex = 3),
            );
          });
        }
      });
    }
  }

  final List<String> _pageTitles = [
    'Relief Net',
    'Report Issue',
    'Dashboard',
    'My Tasks',
    'Application status',
    'Profile',
    'Settings',
  ];

  void _navigate(int index) {
    setState(() => selectedindex = index);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _makeCall(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('Could not launch dialer for $number');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBarComponent(appBarText: _pageTitles[selectedindex]),

      body: _pages[selectedindex],

      drawer: Drawer(
        width: 240,
        child: Column(
          children: [
            /// 🔹 Header
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/logo.png", height: 80),
                  const SizedBox(height: 10),
                  Text("ReliefNet", style: textTheme.bodyLarge),
                ],
              ),
            ),

            /// 🔹 Main Items
            _buildTile(Icons.home_outlined, "Home", 0, textTheme),
            _buildTile(Icons.report_outlined, "Report", 1, textTheme),

            if (_isVolunteer) ...[
              _buildTile(Icons.dashboard_outlined, "Dashboard", 2, textTheme),
              _buildTile(Icons.help_outline, "Volunteer", 3, textTheme),
            ] else
              ListTile(
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: Text("Apply as Volunteer", style: textTheme.bodyMedium),
                selected: selectedindex == 4, // Highlight when index is 4
                onTap: () => _navigate(4), // Navigate to index 4
              ),

            /// 🔹 Secondary Items (Updated Indices)
            _buildTile(Icons.person_outline, "Profile", 5, textTheme),
            _buildTile(Icons.settings_outlined, "Settings", 6, textTheme),
            const Spacer(),

            /// 🔹 Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                "Logout",
                style: textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
              onTap: () => _showLogoutDialog(context, textTheme),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 🔥 Reusable Tile (cleaner code)
  Widget _buildTile(
    IconData icon,
    String title,
    int index,
    TextTheme textTheme,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: textTheme.bodyMedium),
      selected: selectedindex == index,
      onTap: () => _navigate(index),
    );
  }

  /// 🔥 Logout Dialog (clean + themed)
  void _showLogoutDialog(BuildContext context, TextTheme textTheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout", style: textTheme.bodyLarge),
        content: Text(
          "Are you sure you want to logout?",
          style: textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: textTheme.bodySmall),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
            },
            child: Text(
              "Logout",
              style: textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final bool isVolunteer;
  final VoidCallback onNavigateToReport;
  final VoidCallback onNavigateToApply;
  final VoidCallback onNavigateToVolunteer;

  const HomeContent({
    super.key,
    required this.isVolunteer,
    required this.onNavigateToReport,
    required this.onNavigateToApply,
    required this.onNavigateToVolunteer,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Future<void> makeCall(String number) async {
      final Uri uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Greeting Header ──────────────────────────────────────
          Text(
            "Hello, ${user?.displayName?.split(' ').first ?? 'there'} 👋",
            style: textTheme.bodyLarge,
          ),
          Text(
            isVolunteer ? "You're an active volunteer." : "How can we help you today?",
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // ── 1) Report an Issue Button ─────────────────────────────
          GestureDetector(
            onTap: onNavigateToReport,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade300.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.report_problem_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Report an Issue",
                          style: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Need help? Let us know immediately.",
                          style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── New: Emergency Quick Actions ──────────────────────────
          const _SectionHeader(title: "Quick Emergency Actions", icon: Icons.bolt_rounded),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _EmergencyActionBtn(
                icon: Icons.local_police_outlined,
                label: "Police",
                color: Colors.blue,
                onTap: () => makeCall('100'),
              ),
              _EmergencyActionBtn(
                icon: Icons.medical_services_outlined,
                label: "Ambulance",
                color: Colors.red,
                onTap: () => makeCall('102'),
              ),
              _EmergencyActionBtn(
                icon: Icons.local_fire_department_outlined,
                label: "Fire",
                color: Colors.orange,
                onTap: () => makeCall('101'),
              ),
              _EmergencyActionBtn(
                icon: Icons.sos_rounded,
                label: "SOS",
                color: Colors.red.shade900,
                onTap: () => makeCall('112'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── New: Safety Tips Carousel ─────────────────────────────
          const _SectionHeader(title: "Safety & Preparedness", icon: Icons.security_rounded),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _SafetyTipCard(
                  title: "Earthquake Safety",
                  desc: "Drop, Cover, and Hold On! Stay away from glass.",
                  icon: Icons.terrain_rounded,
                  color: Colors.brown,
                ),
                _SafetyTipCard(
                  title: "First Aid Basics",
                  desc: "Keep a kit ready with bandages, antiseptic, and meds.",
                  icon: Icons.health_and_safety_rounded,
                  color: Colors.teal,
                ),
                _SafetyTipCard(
                  title: "Fire Emergency",
                  desc: "Crawl low under smoke and use stairs, not elevators.",
                  icon: Icons.fireplace_rounded,
                  color: Colors.deepOrange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 2) Become a Volunteer Banner ──────────────────────────
          if (!isVolunteer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.volunteer_activism, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Make a Difference", style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text("Join our team of volunteers today!", style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onNavigateToApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Apply"),
                  ),
                ],
              ),
            ),

          if (!isVolunteer) const SizedBox(height: 24),

          // ── New: Community Impact ─────────────────────────────────
          _ImpactSummaryCard(isDark: isDark),
          const SizedBox(height: 24),

          // ── 3) My Active Reports ──────────────────────────────────
          _SectionHeader(title: "My Active Reports", icon: Icons.list_alt_rounded),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .where('submittedBy', isEqualTo: user?.uid)
                .where('status', isNotEqualTo: 'completed')
                .orderBy('status')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const _EmptyState(
                  icon: Icons.inbox_rounded,
                  message: "No active reports. You're all caught up!",
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final issue = doc['issueType'] ?? 'Unknown';
                  final status = doc['status'] ?? '';
                  return _ActiveReportCard(issue: issue, status: status);
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // ── 4) Pending Tasks (volunteers only) ────────────────────
          if (isVolunteer) ...[
            const _SectionHeader(title: "My Pending Tasks", icon: Icons.assignment_turned_in_outlined),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('assignedVolunteers', arrayContains: user?.uid)
                  .where('status', whereIn: ['assigned', 'in_progress', 'reached'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    message: "No pending tasks. Great work!",
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final issue = doc['issueType'] ?? 'Task';
                    final urgency = doc['urgency'] ?? 'Normal';
                    final status = doc['status'] ?? 'assigned';
                    return _PendingTaskCard(
                      issue: issue,
                      urgency: urgency,
                      status: status,
                      onTap: onNavigateToVolunteer,
                    );
                  },
                );
              },
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Shared Section Header ─────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Active Report Card ────────────────────────────────────────────────────────
class _ActiveReportCard extends StatelessWidget {
  final String issue;
  final String status;
  const _ActiveReportCard({required this.issue, required this.status});

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'food': return Icons.fastfood_rounded;
      case 'medical': return Icons.medical_services_rounded;
      case 'shelter': return Icons.house_rounded;
      case 'fire': return Icons.local_fire_department_rounded;
      case 'water': return Icons.water_drop_rounded;
      default: return Icons.help_center_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'food': return Colors.orange;
      case 'medical': return Colors.red;
      case 'shelter': return Colors.indigo;
      case 'fire': return Colors.deepOrange;
      case 'water': return Colors.blue;
      default: return Colors.blueGrey;
    }
  }

  Color _colorForStatus(String s) {
    switch (s) {
      case 'assigned': return Colors.blue.shade600;
      case 'in_progress': return Colors.orange.shade600;
      case 'reached': return Colors.purple.shade600;
      default: return Colors.grey.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(issue);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_iconForType(issue), color: color, size: 22),
        ),
        title: Text(issue, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          "Status: ${status.replaceAll('_', ' ')}",
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _colorForStatus(status),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ── Emergency Action Button ──────────────────────────────────────────────────
class _EmergencyActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _EmergencyActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Safety Tip Card ──────────────────────────────────────────────────────────
class _SafetyTipCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;

  const _SafetyTipCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Impact Summary Card ──────────────────────────────────────────────────────
class _ImpactSummaryCard extends StatelessWidget {
  final bool isDark;
  const _ImpactSummaryCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [Colors.blueGrey.shade800, Colors.blueGrey.shade900]
            : [Colors.indigo.shade50, Colors.indigo.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            "Community Impact",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ImpactStat(label: "Resolved", value: "1.2k", color: Colors.green),
              _ImpactStat(label: "Volunteers", value: "450+", color: Colors.blue),
              _ImpactStat(label: "Active", value: "84", color: Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ImpactStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── Pending Task Card (Volunteer) ─────────────────────────────────────────────
class _PendingTaskCard extends StatelessWidget {
  final String issue;
  final String urgency;
  final String status;
  final VoidCallback onTap;

  const _PendingTaskCard({
    required this.issue,
    required this.urgency,
    required this.status,
    required this.onTap,
  });

  Color _urgencyColor(String u) {
    switch (u.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uColor = _urgencyColor(urgency);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [uColor.withValues(alpha: 0.2), uColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assignment_late_rounded, color: uColor, size: 28),
                ),
                const SizedBox(width: 16),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              issue,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          _UrgencyBadge(label: urgency, color: uColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.radio_button_checked_rounded,
                            size: 14,
                            color: isDark ? Colors.blue.shade400 : Colors.blue.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.blue.shade400 : Colors.blue.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

