import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import the new pages
import 'package:reliefnet/secondary-pages/profile_pages/submitted_reports_page.dart';
import 'package:reliefnet/secondary-pages/profile_pages/tasks_page.dart';
import 'package:reliefnet/secondary-pages/profile_pages/apply_volunteer_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _volunteerIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  File? _image;
  String? _existingPhotoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  String? _selectedAgeRange;
  String? _selectedAvailability;
  String? _selectedFitness;

  final List<String> _availableSkills = [
    "First Aid & CPR",
    "Search & Rescue",
    "Medical & Nursing",
    "Psychological First Aid",
    "Driving (4x4 / Heavy)",
    "Logistics & Inventory",
    "Cooking & Catering",
    "Radio Operation (HAM)",
    "Construction & Carpentry",
    "Electrical & Generators",
    "Water & Sanitation (WASH)",
    "Language Translation",
    "Community Outreach",
    "Security & Crowd Control",
    "IT & Telecommunications",
    "Child & Elder Care"
  ];
  List<String> _selectedSkills = [];

  final List<String> _availableLanguages = [
    "English", "Hindi", "Bengali", "Punjabi", "Marathi", "Tamil", "Telugu", "Urdu"
  ];
  List<String> _selectedLanguages = [];

  List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return List<String>.from(value.map((e) => e.toString()));
    }
    if (value is String) {
      if (value.trim().isEmpty) return [];
      if (value.startsWith('[') && value.endsWith(']')) {
        final stripped = value.substring(1, value.length - 1);
        if (stripped.trim().isEmpty) return [];
        return stripped.split(',').map((e) => e.replaceAll('"', '').replaceAll("'", "").trim()).toList();
      }
      if (value.contains(',')) {
        return value.split(',').map((e) => e.trim()).toList();
      }
      return [value.trim()];
    }
    return [];
  }

  // ── Profile data ──────────────────────────────────────────────────────────
  Map<String, dynamic>? _profile;

  // ── Stats ─────────────────────────────────────────────────────────────────
  int _tasksAccepted = 0;
  int _tasksCompleted = 0;
  int _reportsSubmitted = 0;

  // ── Recent activity ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _recentActivity = [];

  final _picker = ImagePicker();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _volunteerIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadProfile(), _loadStats(), _loadRecentActivity()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      Map<String, dynamic> mergedData = {};
      if (userDoc.exists) {
        mergedData.addAll(userDoc.data()!);
      }

      final volDoc = await FirebaseFirestore.instance
          .collection('volunteer_applications')
          .doc(uid)
          .get();
      if (volDoc.exists) {
        volDoc.data()!.forEach((key, value) {
          if (value != null && mergedData[key] == null) {
            mergedData[key] = value;
          }
        });
      }

      if (mounted) {
        setState(() {
          _profile = mergedData;
          _nameController.text = mergedData['name'] ?? '';
          _usernameController.text = mergedData['username'] ?? '';
          _volunteerIdController.text = mergedData['volunteerId'] ?? '';
          _existingPhotoUrl = mergedData['profilePic'];

          _emailController.text = mergedData['email'] ?? '';
          _phoneController.text = mergedData['phone'] ?? '';
          _locationController.text = mergedData['servingArea'] ?? '';
          _contactNameController.text = mergedData['emergencyContactName'] ?? '';
          _contactPhoneController.text = mergedData['emergencyContactPhone'] ?? '';

          _selectedAgeRange = mergedData['ageRange'];
          _selectedAvailability = mergedData['availability'];
          _selectedFitness = mergedData['fitness'];
          
          _selectedSkills = _parseList(mergedData['skills']);
          _selectedLanguages = _parseList(mergedData['languages']);
        });
      }
    } catch (e) {
      debugPrint('loadProfile error: $e');
    }
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final submittedSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('submittedBy', isEqualTo: uid)
          .get();

      final acceptedSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('assignedVolunteers', arrayContains: uid)
          .get();

      int completed = 0;
      for (final doc in acceptedSnap.docs) {
        final data = doc.data();
        if ((data['status'] ?? '') == 'completed') {
          final proofSnap = await FirebaseFirestore.instance
              .collection('reports')
              .doc(doc.id)
              .collection('proofs')
              .where('volunteerId', isEqualTo: uid)
              .limit(1)
              .get();
          if (proofSnap.docs.isNotEmpty) completed++;
        }
      }

      if (mounted) {
        setState(() {
          _reportsSubmitted = submittedSnap.docs.length;
          _tasksAccepted = acceptedSnap.docs.length;
          _tasksCompleted = completed;
        });
      }
    } catch (e) {
      debugPrint('loadStats error: $e');
    }
  }

  Future<void> _loadRecentActivity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final submittedSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('submittedBy', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      final acceptedSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('assignedVolunteers', arrayContains: uid)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      final all = <Map<String, dynamic>>[];

      for (final doc in submittedSnap.docs) {
        final d = doc.data();
        d['_docId'] = doc.id;
        d['_activityType'] = 'submitted';
        all.add(d);
      }
      for (final doc in acceptedSnap.docs) {
        final d = doc.data();
        d['_docId'] = doc.id;
        d['_activityType'] = 'accepted';
        if (!all.any((x) => x['_docId'] == doc.id)) all.add(d);
      }

      all.sort((a, b) {
        final ta = (a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      if (mounted) {
        setState(() => _recentActivity = all.take(5).toList());
      }
    } catch (e) {
      debugPrint('loadRecentActivity error: $e');
    }
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null && mounted) {
      setState(() => _image = File(picked.path));
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final enteredId = _volunteerIdController.text.trim();

    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      _snack('Name, username, email, and phone number are required');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isAlreadyVolunteer = _profile?['isVolunteer'] == true;
      bool isValidVolunteer = isAlreadyVolunteer;
      // Validate volunteer ID if entered and it changed
      if (enteredId.isNotEmpty && enteredId != _profile?['volunteerId']) {
        final doc = await FirebaseFirestore.instance
            .collection('volunteer_applications')
            .doc(uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final approved = data['status'] == 'approved';
          final correctId = data['volunteerId'] == enteredId;

          if (approved && correctId) {
            isValidVolunteer = true;
          } else {
            _snack('Invalid Volunteer ID or not approved yet');
            setState(() => _isSaving = false);
            return;
          }
        } else {
          _snack('No volunteer application found');
          setState(() => _isSaving = false);
          return;
        }
      } else if (enteredId.isEmpty) {
        isValidVolunteer = false;
      }

      // Validate volunteer specific fields if they are a volunteer
      if (isValidVolunteer) {
        if (_locationController.text.trim().isEmpty ||
            _contactNameController.text.trim().isEmpty ||
            _contactPhoneController.text.trim().isEmpty ||
            _selectedSkills.isEmpty ||
            _selectedLanguages.isEmpty ||
            _selectedAvailability == null ||
            _selectedFitness == null ||
            _selectedAgeRange == null) {
          _snack('Please fill in all volunteer profile fields');
          setState(() => _isSaving = false);
          return;
        }
      }

      // Upload image
      String? imageUrl;
      if (_image != null) {
        final ref = FirebaseStorage.instance.ref('profile_pics/$uid.jpg');
        await ref.putFile(_image!);
        imageUrl = await ref.getDownloadURL();
      }

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'volunteerId': isValidVolunteer ? (enteredId.isNotEmpty ? enteredId : (_profile?['volunteerId'] ?? '')) : '',
        'isVolunteer': isValidVolunteer,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null) data['profilePic'] = imageUrl;

      if (isValidVolunteer) {
        data['ageRange'] = _selectedAgeRange;
        data['availability'] = _selectedAvailability;
        data['fitness'] = _selectedFitness;
        data['servingArea'] = _locationController.text.trim();
        data['emergencyContactName'] = _contactNameController.text.trim();
        data['emergencyContactPhone'] = _contactPhoneController.text.trim();
        data['skills'] = _selectedSkills;
        data['languages'] = _selectedLanguages;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));

      // Sync to volunteer_applications if volunteer
      if (isValidVolunteer) {
        final volData = <String, dynamic>{
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'ageRange': _selectedAgeRange,
          'availability': _selectedAvailability,
          'fitness': _selectedFitness,
          'servingArea': _locationController.text.trim(),
          'emergencyContactName': _contactNameController.text.trim(),
          'emergencyContactPhone': _contactPhoneController.text.trim(),
          'skills': _selectedSkills,
          'languages': _selectedLanguages,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await FirebaseFirestore.instance
            .collection('volunteer_applications')
            .doc(uid)
            .set(volData, SetOptions(merge: true));
      }

      await _loadProfile();

      if (mounted) {
        setState(() => _isEditing = false);
        _snack('Profile updated!');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  /// Opens a volunteer-gated page. If not a volunteer, goes to ApplyVolunteerPage.
  /// If user applies from there, reloads the profile so isVolunteer updates.
  Future<void> _openVolunteerPage(Widget page) async {
    final isVolunteer = _profile?['isVolunteer'] == true;
    if (!isVolunteer) {
      final applied = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const ApplyVolunteerPage()),
      );
      if (applied == true) {
        // Reload so the profile reflects the new volunteer status
        await _loadAll();
      }
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _onReportsStatTap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubmittedReportsPage()),
    );
  }

  void _onAcceptedStatTap() {
    _openVolunteerPage(const TasksPage(filter: TasksFilter.accepted));
  }

  void _onCompletedStatTap() {
    _openVolunteerPage(const TasksPage(filter: TasksFilter.completed));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _memberSince() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.metadata.creationTime == null) return '';
    final dt = user!.metadata.creationTime!;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Member since ${months[dt.month - 1]} ${dt.year}';
  }

  Color _urgencyColor(String u) {
    switch (u) {
      case 'High':
        return const Color(0xFFEF4444);
      case 'Medium':
        return const Color(0xFFF59E0B);
      case 'Low':
        return const Color(0xFF22C55E);
      default:
        return Colors.grey;
    }
  }

  IconData _issueIcon(String type) {
    switch (type) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Medical':
        return Icons.local_hospital_outlined;
      case 'Shelter':
        return Icons.home_outlined;
      default:
        return Icons.help_outline;
    }
  }

  int get _successRate {
    if (_tasksAccepted == 0) return 0;
    return ((_tasksCompleted / _tasksAccepted) * 100).round();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVolunteer = _profile?['isVolunteer'] == true;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Hero ─────────────────────────────────────────────
            _ProfileHero(
              profile: _profile,
              image: _image,
              existingPhotoUrl: _existingPhotoUrl,
              isEditing: _isEditing,
              isVolunteer: isVolunteer,
              memberSince: _memberSince(),
              onPickImage: _pickImage,
              onEditToggle: () => setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  _nameController.text = _profile?['name'] ?? '';
                  _usernameController.text = _profile?['username'] ?? '';
                  _volunteerIdController.text = _profile?['volunteerId'] ?? '';
                  _emailController.text = _profile?['email'] ?? '';
                  _phoneController.text = _profile?['phone'] ?? '';
                  _locationController.text = _profile?['servingArea'] ?? '';
                  _contactNameController.text = _profile?['emergencyContactName'] ?? '';
                  _contactPhoneController.text = _profile?['emergencyContactPhone'] ?? '';

                  _selectedAgeRange = _profile?['ageRange'];
                  _selectedAvailability = _profile?['availability'];
                  _selectedFitness = _profile?['fitness'];
                  
                  _selectedSkills = _parseList(_profile?['skills']);
                  _selectedLanguages = _parseList(_profile?['languages']);
                  _image = null;
                }
              }),
            ),

            // ── Edit Form ─────────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _isEditing
                  ? _buildEditForm(theme, theme.textTheme)
                  : const SizedBox.shrink(),
            ),

            if (!_isEditing) ...[
              const SizedBox(height: 24),
              _SectionLabel(label: 'Profile Details'),
              const SizedBox(height: 10),
              _buildReadOnlyProfileDetails(theme),
              
              if (isVolunteer) ...[
                const SizedBox(height: 24),
                _SectionLabel(label: 'Volunteer Profile'),
                const SizedBox(height: 10),
                _buildReadOnlyVolunteerProfile(theme),
                
                const SizedBox(height: 24),
                _SectionLabel(label: 'Emergency Contact'),
                const SizedBox(height: 10),
                _buildReadOnlyEmergencyContact(theme),
              ],
            ],

            const SizedBox(height: 24),

            // ── Stats Row ─────────────────────────────────────────────────
            _SectionLabel(label: 'Activity Stats'),
            const SizedBox(height: 10),
            _StatsGrid(
              reportsSubmitted: _reportsSubmitted,
              tasksAccepted: _tasksAccepted,
              tasksCompleted: _tasksCompleted,
              successRate: _successRate,
              isVolunteer: isVolunteer,
              onReportsTap: _onReportsStatTap,
              onAcceptedTap: _onAcceptedStatTap,
              onCompletedTap: _onCompletedStatTap,
            ),

            const SizedBox(height: 28),

            // ── Volunteer Badge ───────────────────────────────────────────
            if (isVolunteer) ...[
              _SectionLabel(label: 'Volunteer Status'),
              const SizedBox(height: 10),
              _VolunteerBadgeCard(volunteerId: _profile?['volunteerId'] ?? ''),
              const SizedBox(height: 28),
            ],

            // ── Recent Activity ───────────────────────────────────────────
            if (_recentActivity.isNotEmpty) ...[
              _SectionLabel(label: 'Recent Activity'),
              const SizedBox(height: 10),
              ..._recentActivity.map(
                (item) => _ActivityCard(
                  data: item,
                  timeAgo: _timeAgo(item['timestamp'] as Timestamp?),
                  urgencyColor: _urgencyColor(item['urgency'] ?? 'Low'),
                  issueIcon: _issueIcon(item['issueType'] ?? 'Other'),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ── Account Actions ───────────────────────────────────────────
            _SectionLabel(label: 'Account'),
            const SizedBox(height: 10),
            _AccountActions(onSignOut: _signOut),
          ],
        ),
      ),
    );
  }

  // ── Helper UI Methods inside _ProfilePageState ──

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required ThemeData theme,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlyProfileDetails(ThemeData theme) {
    return _buildSectionCard(
      title: 'Contact Information',
      icon: Icons.contact_mail_outlined,
      theme: theme,
      children: [
        _buildInfoRow(Icons.email_outlined, 'Email Address', _profile?['email'] ?? 'Not set', theme),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.phone_outlined, 'Phone Number', _profile?['phone'] ?? 'Not set', theme),
      ],
    );
  }

  Widget _buildReadOnlyVolunteerProfile(ThemeData theme) {
    final skills = _parseList(_profile?['skills']);
    final languages = _parseList(_profile?['languages']);

    return _buildSectionCard(
      title: 'Volunteer Profile',
      icon: Icons.volunteer_activism_outlined,
      theme: theme,
      children: [
        _buildInfoRow(Icons.cake_outlined, 'Age Range', _profile?['ageRange'] ?? 'Not set', theme),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.schedule_outlined, 'Availability', _profile?['availability'] ?? 'Not set', theme),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.fitness_center_outlined, 'Physical Fitness', _profile?['fitness'] ?? 'Not set', theme),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.map_outlined, 'Serving Area', _profile?['servingArea'] ?? 'Not set', theme),
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Skills', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: skills.map((skill) => Chip(
              label: Text(skill, style: const TextStyle(fontSize: 12)),
              backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
        ],
        if (languages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Languages', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: languages.map((lang) => Chip(
              label: Text(lang, style: const TextStyle(fontSize: 12)),
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.08),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyEmergencyContact(ThemeData theme) {
    return _buildSectionCard(
      title: 'Emergency Contact',
      icon: Icons.contact_emergency_outlined,
      theme: theme,
      children: [
        _buildInfoRow(Icons.person_pin_outlined, 'Contact Name', _profile?['emergencyContactName'] ?? 'Not set', theme),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.phone_iphone_outlined, 'Contact Phone', _profile?['emergencyContactPhone'] ?? 'Not set', theme),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm(ThemeData theme, TextTheme textTheme) {
    final isVolunteer = _profile?['isVolunteer'] == true;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Personal Details',
            icon: Icons.person_outline,
            theme: theme,
            children: [
              _buildEditField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline, theme: theme),
              const SizedBox(height: 12),
              _buildEditField(controller: _usernameController, label: 'Username', icon: Icons.alternate_email, theme: theme),
              const SizedBox(height: 12),
              _buildEditField(controller: _emailController, label: 'Email Address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, theme: theme),
              const SizedBox(height: 12),
              _buildEditField(controller: _phoneController, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, theme: theme),
              const SizedBox(height: 12),
              _buildEditField(
                controller: _volunteerIdController,
                label: 'Volunteer ID (optional)',
                icon: Icons.badge_outlined,
                hint: 'Enter to access volunteer features',
                theme: theme,
              ),
            ],
          ),

          if (isVolunteer) ...[
            _buildSectionCard(
              title: 'Volunteer Profile',
              icon: Icons.volunteer_activism_outlined,
              theme: theme,
              children: [
                _buildLabel("Age Range *", textTheme),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ["Under 18", "18-30", "31-50", "51+"].map((age) {
                    final isSel = _selectedAgeRange == age;
                    return ChoiceChip(
                      label: Text(age),
                      selected: isSel,
                      onSelected: (selected) {
                        setState(() => _selectedAgeRange = selected ? age : null);
                      },
                      selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: isSel ? theme.colorScheme.primary : null,
                        fontWeight: isSel ? FontWeight.bold : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildLabel("Availability *", textTheme),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ["Full time", "Weekends only", "On-call"].map((avail) {
                    final isSel = _selectedAvailability == avail;
                    return ChoiceChip(
                      label: Text(avail),
                      selected: isSel,
                      onSelected: (selected) {
                        setState(() => _selectedAvailability = selected ? avail : null);
                      },
                      selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: isSel ? theme.colorScheme.primary : null,
                        fontWeight: isSel ? FontWeight.bold : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildLabel("Physical Fitness Level *", textTheme),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ["Low", "Medium", "High"].map((fit) {
                    final isSel = _selectedFitness == fit;
                    return ChoiceChip(
                      label: Text(fit),
                      selected: isSel,
                      onSelected: (selected) {
                        setState(() => _selectedFitness = selected ? fit : null);
                      },
                      selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: isSel ? theme.colorScheme.primary : null,
                        fontWeight: isSel ? FontWeight.bold : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  controller: _locationController,
                  label: 'Area / District of Service',
                  icon: Icons.map_outlined,
                  theme: theme,
                ),
              ],
            ),

            _buildSectionCard(
              title: 'Emergency Contact',
              icon: Icons.contact_emergency_outlined,
              theme: theme,
              children: [
                _buildEditField(controller: _contactNameController, label: 'Emergency Contact Name', icon: Icons.person_pin_outlined, theme: theme),
                const SizedBox(height: 12),
                _buildEditField(controller: _contactPhoneController, label: 'Emergency Contact Phone', icon: Icons.phone_iphone_outlined, keyboardType: TextInputType.phone, theme: theme),
              ],
            ),

            _buildSectionCard(
              title: 'Skills & Languages',
              icon: Icons.auto_awesome_outlined,
              theme: theme,
              children: [
                _buildLabel("Languages Spoken (Select all that apply) *", textTheme),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableLanguages.map((lang) {
                    final isSel = _selectedLanguages.contains(lang);
                    return FilterChip(
                      label: Text(lang),
                      selected: isSel,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedLanguages.add(lang);
                          } else {
                            _selectedLanguages.remove(lang);
                          }
                        });
                      },
                      selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                      checkmarkColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSel ? theme.colorScheme.primary : null,
                        fontWeight: isSel ? FontWeight.bold : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildLabel("Your Skills (Select all that apply) *", textTheme),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSkills.map((skill) {
                    final isSel = _selectedSkills.contains(skill);
                    return FilterChip(
                      label: Text(skill),
                      selected: isSel,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSkills.add(skill);
                          } else {
                            _selectedSkills.remove(skill);
                          }
                        });
                      },
                      selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                      checkmarkColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSel ? theme.colorScheme.primary : null,
                        fontWeight: isSel ? FontWeight.bold : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    required ThemeData theme,
  }) {
    return TextField(
      controller: controller,
      style: theme.textTheme.bodyMedium,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: theme.textTheme.bodySmall,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
      ),
    );
  }

  Widget _buildLabel(String text, TextTheme textTheme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Hero  (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.image,
    required this.existingPhotoUrl,
    required this.isEditing,
    required this.isVolunteer,
    required this.memberSince,
    required this.onPickImage,
    required this.onEditToggle,
  });

  final Map<String, dynamic>? profile;
  final File? image;
  final String? existingPhotoUrl;
  final bool isEditing;
  final bool isVolunteer;
  final String memberSince;
  final VoidCallback onPickImage;
  final VoidCallback onEditToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile?['name'] ?? 'Your Name';
    final username = profile?['username'] ?? 'username';

    ImageProvider? avatarImage;
    if (image != null) {
      avatarImage = FileImage(image!);
    } else if (existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(existingPhotoUrl!);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: isEditing ? onPickImage : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Icon(Icons.person_rounded, size: 42, color: theme.colorScheme.primary)
                          : null,
                    ),
                    if (isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (memberSince.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(memberSince, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onEditToggle,
                icon: Icon(isEditing ? Icons.close_rounded : Icons.edit_outlined, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (isVolunteer) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.7),
                  ]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Verified Volunteer',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Helper classes removed. Inline _buildEditForm is used now.

// ─────────────────────────────────────────────────────────────────────────────
// Stats Grid  ← UPDATED: tappable cards with volunteer lock indicator
// ─────────────────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.reportsSubmitted,
    required this.tasksAccepted,
    required this.tasksCompleted,
    required this.successRate,
    required this.isVolunteer,
    required this.onReportsTap,
    required this.onAcceptedTap,
    required this.onCompletedTap,
  });

  final int reportsSubmitted;
  final int tasksAccepted;
  final int tasksCompleted;
  final int successRate;
  final bool isVolunteer;
  final VoidCallback onReportsTap;
  final VoidCallback onAcceptedTap;
  final VoidCallback onCompletedTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dynamicRatio = screenWidth > 600 ? 1.5 : 1.1;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: dynamicRatio,
      children: [
        _StatCard(
          label: 'Reports Submitted',
          value: '$reportsSubmitted',
          icon: Icons.description_outlined,
          color: const Color(0xFF6366F1),
          onTap: onReportsTap,
          // Reports are always accessible (no lock)
          isLocked: false,
        ),
        _StatCard(
          label: 'Tasks Accepted',
          value: isVolunteer ? '$tasksAccepted' : '—',
          icon: Icons.handshake_outlined,
          color: const Color(0xFFF59E0B),
          onTap: onAcceptedTap,
          isLocked: !isVolunteer,
        ),
        _StatCard(
          label: 'Tasks Completed',
          value: isVolunteer ? '$tasksCompleted' : '—',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF22C55E),
          onTap: onCompletedTap,
          isLocked: !isVolunteer,
        ),
        _StatCard(
          label: 'Success Rate',
          value: isVolunteer ? '$successRate%' : '—',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFFEF4444),
          // Success rate is just a derived stat, no detail page — no onTap
          onTap: null,
          isLocked: !isVolunteer,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isLocked,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                // Lock icon for volunteer-only stats
                if (isLocked)
                  Icon(Icons.lock_outline_rounded, size: 14, color: theme.textTheme.bodySmall?.color?.withOpacity(0.5)),
                // Chevron for tappable, non-locked cards
                if (!isLocked && onTap != null)
                  Icon(Icons.chevron_right, size: 16, color: theme.textTheme.bodySmall?.color?.withOpacity(0.4)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isLocked ? theme.textTheme.bodySmall?.color?.withOpacity(0.4) : null,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Volunteer Badge Card  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _VolunteerBadgeCard extends StatelessWidget {
  const _VolunteerBadgeCard({required this.volunteerId});
  final String volunteerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Volunteer ID',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, letterSpacing: 0.5),
                ),
                const SizedBox(height: 3),
                Text(
                  volunteerId,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: volunteerId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Volunteer ID copied'), duration: Duration(seconds: 1)),
              );
            },
            icon: const Icon(Icons.copy_outlined, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Card  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.data,
    required this.timeAgo,
    required this.urgencyColor,
    required this.issueIcon,
  });

  final Map<String, dynamic> data;
  final String timeAgo;
  final Color urgencyColor;
  final IconData issueIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityType = data['_activityType'] as String? ?? 'submitted';
    final issueType = data['issueType'] as String? ?? 'Other';
    final description = data['description'] as String? ?? '';
    final status = data['status'] as String? ?? 'unassigned';
    final urgency = data['urgency'] as String? ?? 'Low';
    final isAccepted = activityType == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: theme.shadowColor.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(issueIcon, color: theme.colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(issueType, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: urgencyColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(urgency, style: TextStyle(color: urgencyColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _MiniChip(
                      label: isAccepted ? 'Accepted' : 'Submitted',
                      color: isAccepted ? const Color(0xFF6366F1) : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    _MiniChip(
                      label: status[0].toUpperCase() + status.substring(1),
                      color: status == 'completed'
                          ? const Color(0xFF22C55E)
                          : status == 'assigned'
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF9CA3AF),
                    ),
                    const Spacer(),
                    Text(timeAgo, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account Actions  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: theme.shadowColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.info_outline,
            label: 'App Version',
            trailing: Text('1.0.0', style: theme.textTheme.bodySmall),
            onTap: null,
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
          _ActionTile(icon: Icons.logout_rounded, label: 'Sign Out', color: Colors.red, onTap: onSignOut),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, this.trailing, this.color, this.onTap});

  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = color ?? theme.textTheme.bodyLarge?.color;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: tileColor, size: 20),
      title: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: tileColor, fontWeight: FontWeight.w500)),
      trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, size: 18, color: theme.textTheme.bodySmall?.color) : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Label  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: theme.colorScheme.primary),
    );
  }
}