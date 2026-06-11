import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ApplyVolunteerPage extends StatefulWidget {
  const ApplyVolunteerPage({super.key});

  @override
  State<ApplyVolunteerPage> createState() => _ApplyVolunteerPageState();
}

class _ApplyVolunteerPageState extends State<ApplyVolunteerPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _reasonController = TextEditingController();
  final _experienceController = TextEditingController();

  bool _isLoading = false;
  DocumentSnapshot? _existingApplication;
  Stream<DocumentSnapshot>? _applicationStream;

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
  final List<String> _selectedSkills = [];

  final List<String> _availableLanguages = [
    "English", "Hindi", "Bengali", "Punjabi", "Marathi", "Tamil", "Telugu", "Urdu"
  ];
  final List<String> _selectedLanguages = [];

  @override
  void initState() {
    super.initState();
    _checkExistingApplication();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.email != null) _emailController.text = user.email!;
      _applicationStream = FirebaseFirestore.instance
          .collection('volunteer_applications')
          .doc(user.uid)
          .snapshots();
    }
  }

  Future<void> _checkExistingApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('volunteer_applications').doc(user.uid).get();
      if (doc.exists && mounted) setState(() => _existingApplication = doc);
    } catch (e) {
      debugPrint("Error checking application: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _contactNameController.text.trim().isEmpty ||
        _contactPhoneController.text.trim().isEmpty ||
        _reasonController.text.trim().isEmpty ||
        _selectedSkills.isEmpty ||
        _selectedLanguages.isEmpty ||
        _selectedAvailability == null ||
        _selectedFitness == null ||
        _selectedAgeRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all the required fields")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('volunteer_applications').doc(user.uid).set({
        'uid': user.uid,
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'reason': _reasonController.text.trim(),
        'skills': _selectedSkills,
        'languages': _selectedLanguages,
        'experience': _experienceController.text.trim(),
        'availability': _selectedAvailability,
        'fitness': _selectedFitness,
        'ageRange': _selectedAgeRange,
        'servingArea': _locationController.text.trim(),
        'emergencyContactName': _contactNameController.text.trim(),
        'emergencyContactPhone': _contactPhoneController.text.trim(),
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Application submitted successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _reasonController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in")));

    return StreamBuilder<DocumentSnapshot>(
      stream: _applicationStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _existingApplication == null && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'];
          final volunteerId = data['volunteerId'];
          return _StatusView(status: status, volunteerId: volunteerId, uid: user.uid, textTheme: textTheme);
        }

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Join our team of volunteers and help make a difference!",
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),

                // 1. Contact Information Card
                _buildSectionCard(
                  title: "Contact Information",
                  icon: Icons.contact_mail_outlined,
                  theme: theme,
                  children: [
                    _buildLabel("Email Address for Updates *", textTheme),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: "Enter your email address...",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel("Phone Number *", textTheme),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: "Enter your phone number...",
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),

                // 2. Personal Profile Card
                _buildSectionCard(
                  title: "Volunteer Profile",
                  icon: Icons.person_outline,
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
                          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
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
                          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
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
                          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: isSel ? theme.colorScheme.primary : null,
                            fontWeight: isSel ? FontWeight.bold : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel("Area / District of Service *", textTheme),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: "Enter serving area or district...",
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),

                // 3. Emergency Contact Card
                _buildSectionCard(
                  title: "Emergency Contact",
                  icon: Icons.contact_emergency_outlined,
                  theme: theme,
                  children: [
                    _buildLabel("Emergency Contact Name *", textTheme),
                    TextField(
                      controller: _contactNameController,
                      decoration: const InputDecoration(
                        hintText: "Contact person name...",
                        prefixIcon: Icon(Icons.person_pin_outlined),
                      ),
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel("Emergency Contact Phone *", textTheme),
                    TextField(
                      controller: _contactPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: "Contact phone number...",
                        prefixIcon: Icon(Icons.phone_iphone_outlined),
                      ),
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),

                // 4. Skills & Languages
                _buildSectionCard(
                  title: "Skills & Languages",
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
                          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
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
                          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
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

                // 5. Why Volunteer & Experience
                _buildSectionCard(
                  title: "Why Volunteer & Experience",
                  icon: Icons.volunteer_activism_outlined,
                  theme: theme,
                  children: [
                    _buildLabel("Why do you want to volunteer? *", textTheme),
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: "Tell us about your motivation...",
                      ),
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel("Previous Experience (Optional)", textTheme),
                    TextField(
                      controller: _experienceController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: "Tell us about any relevant work you've done...",
                      ),
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                SelectableText(
                  "Your UID: ${user.uid}",
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Submit Application",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text, TextTheme textTheme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: textTheme.bodyMedium),
      );
}


class _StatusView extends StatelessWidget {
  final String? status;
  final dynamic volunteerId;
  final String uid;
  final TextTheme textTheme;
  const _StatusView({
    required this.status,
    required this.volunteerId,
    required this.uid,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isApproved ? Icons.check_circle_outline : Icons.hourglass_empty,
              size: 80,
              color: isApproved ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              isApproved
                  ? "Congratulations! Your application is approved."
                  : "Your application is currently being reviewed.",
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (isApproved && volunteerId != null) ...[
              const Text("Your Unique Volunteer UID:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: volunteerId.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Copied to clipboard!"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Text(
                    volunteerId.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Copy this 12-digit UID and enter it in your Profile section to unlock all volunteer features.",
                textAlign: TextAlign.center,
              ),
            ],
            if (status == 'pending') ...[
              const Text(
                "Our team is performing a thorough check. You will receive your unique 12-digit UID once approved.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 10),
              SelectableText(
                "Firestore Document ID: $uid",
                style: textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/home'),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Back to Home"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
