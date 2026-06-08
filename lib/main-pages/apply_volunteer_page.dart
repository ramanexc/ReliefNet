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
  final _reasonController = TextEditingController();
  final _experienceController = TextEditingController();
  bool _isLoading = false;
  DocumentSnapshot? _existingApplication;
  Stream<DocumentSnapshot>? _applicationStream;

  final List<String> _availableSkills = [
    "Animal Care / Veterinary", "Carpentry", "Child Care", "Community Outreach", "Cooking",
    "Counseling", "CPR", "Crisis Communication", "Data Entry", "Debris Removal",
    "Driving", "Elderly Care", "Electrical Work", "Emergency Response", "Event Coordination",
    "Firefighting", "First Aid", "Fundraising", "Heavy Machinery Operation", "Inventory Management",
    "IT Support", "Legal Support", "Logistics", "Medical Assistance", "Mental Health Support",
    "Nursing", "Nutrition & Dietetics", "Photography / Videography", "Plumbing", "Radio Operation",
    "Search & Rescue", "Security Services", "Social Media Management", "Supply Distribution",
    "swimming", "Teaching", "Translation", "Water Purification"
  ];
  final List<String> _selectedSkills = [];

  final List<String> _availableLanguages = [
    "Assamese", "Bengali", "English", "Gujarati", "Hindi", "Kannada", "Malayalam",
    "Marathi", "Nepali", "Odia", "Punjabi", "Sanskrit", "Tamil", "Telugu", "Urdu"
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

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(padding: const EdgeInsets.all(16.0), child: Text("Select Languages Spoken", style: Theme.of(context).textTheme.titleLarge)),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _availableLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = _availableLanguages[index];
                    final isSelected = _selectedLanguages.contains(lang);
                    return CheckboxListTile(
                      title: Text(lang),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setModalState(() {
                          if (value == true) _selectedLanguages.add(lang);
                          else _selectedLanguages.remove(lang);
                        });
                        setState(() {}); // Still need to update parent display but only text
                      },
                    );
                  },
                ),
              ),
              Padding(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Done")))),
            ],
          ),
        ),
      ),
    );
  }

  void _showSkillPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(padding: const EdgeInsets.all(16.0), child: Text("Select Your Skills", style: Theme.of(context).textTheme.titleLarge)),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _availableSkills.length,
                  itemBuilder: (context, index) {
                    final skill = _availableSkills[index];
                    final isSelected = _selectedSkills.contains(skill);
                    return CheckboxListTile(
                      title: Text(skill),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setModalState(() {
                          if (value == true) _selectedSkills.add(skill);
                          else _selectedSkills.remove(skill);
                        });
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              Padding(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Done")))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_emailController.text.isEmpty || _reasonController.text.isEmpty || _selectedSkills.isEmpty || _selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in the required fields")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('volunteer_applications').doc(user.uid).set({
        'uid': user.uid,
        'email': _emailController.text.trim(),
        'reason': _reasonController.text.trim(),
        'skills': _selectedSkills,
        'languages': _selectedLanguages,
        'experience': _experienceController.text.trim(),
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application submitted successfully!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _reasonController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Join our team of volunteers and help make a difference!", style: textTheme.bodyLarge),
                const SizedBox(height: 25),
                _buildLabel("Email Address for Updates *", textTheme),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: "Enter your email address...", prefixIcon: Icon(Icons.email_outlined)),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _buildLabel("Why do you want to volunteer? *", textTheme),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: "Tell us about your motivation..."),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _buildLabel("Languages Spoken *", textTheme),
                _SelectionButton(onTap: _showLanguagePicker, selection: _selectedLanguages, hint: "Select Languages...", textTheme: textTheme),
                const SizedBox(height: 20),
                _buildLabel("Your Skills *", textTheme),
                _SelectionButton(onTap: _showSkillPicker, selection: _selectedSkills, hint: "Select Skills...", textTheme: textTheme),
                const SizedBox(height: 20),
                _buildLabel("Previous Experience (Optional)", textTheme),
                TextField(
                  controller: _experienceController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: "Tell us about any relevant work you've done..."),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 30),
                SelectableText("Your UID: ${user.uid}", style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitApplication,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Submit Application"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text, TextTheme textTheme) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: textTheme.bodyMedium));
}

class _SelectionButton extends StatelessWidget {
  final VoidCallback onTap;
  final List<String> selection;
  final String hint;
  final TextTheme textTheme;
  const _SelectionButton({required this.onTap, required this.selection, required this.hint, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(selection.isEmpty ? hint : selection.join(", "), style: textTheme.bodyMedium?.copyWith(color: selection.isEmpty ? Colors.grey : null), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  final String? status;
  final dynamic volunteerId;
  final String uid;
  final TextTheme textTheme;
  const _StatusView({required this.status, required this.volunteerId, required this.uid, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isApproved ? Icons.check_circle_outline : Icons.hourglass_empty, size: 80, color: isApproved ? Colors.green : Colors.orange),
            const SizedBox(height: 24),
            Text(isApproved ? "Congratulations! Your application is approved." : "Your application is currently being reviewed.", textAlign: TextAlign.center, style: textTheme.bodyLarge),
            const SizedBox(height: 16),
            if (isApproved && volunteerId != null) ...[
              const Text("Your Unique Volunteer UID:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: volunteerId.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard!"), duration: Duration(seconds: 2)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade300)),
                  child: Text(volunteerId.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 24),
              const Text("Copy this 12-digit UID and enter it in your Profile section to unlock all volunteer features.", textAlign: TextAlign.center),
            ],
            if (status == 'pending') ...[
              const Text("Our team is performing a thorough check. You will receive your unique 12-digit UID once approved.", textAlign: TextAlign.center),
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 10),
              SelectableText("Firestore Document ID: $uid", style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
            const SizedBox(height: 40),
            ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/home'), child: const Padding(padding: EdgeInsets.all(8.0), child: Text("Back to Home"))),
          ],
        ),
      ),
    );
  }
}
