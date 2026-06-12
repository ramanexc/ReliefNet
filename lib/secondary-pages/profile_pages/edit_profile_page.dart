import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // ── Controllers ──────────────────────────────────────────────────────────
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _volunteerIdController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;

  // ── State ─────────────────────────────────────────────────────────────────
  File? _image;
  String? _existingPhotoUrl;
  bool _isSaving = false;

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

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final data = widget.profile ?? {};

    _nameController = TextEditingController(text: data['name'] ?? '');
    _usernameController = TextEditingController(text: data['username'] ?? '');
    _volunteerIdController = TextEditingController(text: data['volunteerId'] ?? '');
    _emailController = TextEditingController(text: data['email'] ?? '');
    _phoneController = TextEditingController(text: data['phone'] ?? '');
    _locationController = TextEditingController(text: data['servingArea'] ?? '');
    _contactNameController = TextEditingController(text: data['emergencyContactName'] ?? '');
    _contactPhoneController = TextEditingController(text: data['emergencyContactPhone'] ?? '');

    _existingPhotoUrl = data['profilePic'];
    _selectedAgeRange = data['ageRange'];
    _selectedAvailability = data['availability'];
    _selectedFitness = data['fitness'];

    _selectedSkills = _parseList(data['skills']);
    _selectedLanguages = _parseList(data['languages']);
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
    super.dispose();
  }

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null && mounted) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final enteredId = _volunteerIdController.text.trim();

    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty) {
      _snack('Name and username are required');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isAlreadyVolunteer = widget.profile?['isVolunteer'] == true;
      bool isValidVolunteer = isAlreadyVolunteer;

      // Validate volunteer ID if entered and it changed
      if (enteredId.isNotEmpty && enteredId != widget.profile?['volunteerId']) {
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
        'volunteerId': isValidVolunteer ? (enteredId.isNotEmpty ? enteredId : (widget.profile?['volunteerId'] ?? '')) : '',
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

      if (mounted) {
        _snack('Profile updated!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    required ThemeData theme,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: enabled ? null : theme.disabledColor,
      ),
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: theme.textTheme.bodySmall,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
        filled: !enabled,
        fillColor: enabled ? null : theme.disabledColor.withOpacity(0.05),
      ),
    );
  }

  Widget _buildLabel(String text, TextTheme textTheme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isVolunteer = widget.profile?['isVolunteer'] == true;

    final hasVolunteerId = widget.profile != null &&
        widget.profile!['volunteerId'] != null &&
        widget.profile!['volunteerId'].toString().trim().isNotEmpty;

    ImageProvider? avatarImage;
    if (_image != null) {
      avatarImage = FileImage(_image!);
    } else if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_existingPhotoUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Photo Editor Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? Icon(Icons.person_rounded, size: 36, color: theme.colorScheme.primary)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
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
                              Text('Profile Photo', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Tap to change avatar image', style: textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Personal Details Card
                  _buildSectionCard(
                    title: 'Personal Details',
                    icon: Icons.person_outline,
                    theme: theme,
                    children: [
                      _buildEditField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline, theme: theme),
                      const SizedBox(height: 12),
                      _buildEditField(controller: _usernameController, label: 'Username', icon: Icons.alternate_email, theme: theme),
                      const SizedBox(height: 12),
                      _buildEditField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        theme: theme,
                        enabled: false, // locked
                      ),
                      const SizedBox(height: 12),
                      _buildEditField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        theme: theme,
                        enabled: false, // locked
                      ),
                      const SizedBox(height: 12),
                      _buildEditField(
                        controller: _volunteerIdController,
                        label: hasVolunteerId ? 'Volunteer ID (Locked)' : 'Volunteer ID (optional)',
                        icon: Icons.badge_outlined,
                        hint: 'Enter to access volunteer features',
                        theme: theme,
                        enabled: !hasVolunteerId, // locked if already set
                      ),
                    ],
                  ),

                  if (isVolunteer) ...[
                    // Volunteer Profile Card
                    _buildSectionCard(
                      title: 'Volunteer Profile',
                      icon: Icons.volunteer_activism_outlined,
                      theme: theme,
                      children: [
                        _buildLabel("Age Range", textTheme),
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
                        _buildLabel("Availability", textTheme),
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
                        _buildLabel("Physical Fitness Level", textTheme),
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

                    // Emergency Contact Card
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

                    // Skills & Languages Card
                    _buildSectionCard(
                      title: 'Skills & Languages',
                      icon: Icons.auto_awesome_outlined,
                      theme: theme,
                      children: [
                        _buildLabel("Languages Spoken (Select all that apply)", textTheme),
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
                        _buildLabel("Your Skills (Select all that apply)", textTheme),
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
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
