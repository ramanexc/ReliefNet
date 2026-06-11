import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reliefnet/components/phone_formatter.dart';
import 'package:reliefnet/l10n/app_localizations.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    _phoneController.text = "+91 ";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());
        final baseName = _nameController.text.trim().toLowerCase().replaceAll(' ', '_');
        final username = '${baseName}_${user.uid.substring(0, 4)}';

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'username': username,
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'isVolunteer': false,
          'volunteerId': '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        await FirebaseAuth.instance.signOut();
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      String error = "Signup failed. Please try again.";
      if (e.code == 'email-already-in-use') {
        error = "An account with this email already exists.";
      } else if (e.code == 'weak-password') error = "Password is too weak. Use at least 8 characters.";
      else if (e.code == 'invalid-email') error = "The email address is badly formatted.";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.create_account, style: textTheme.bodyLarge?.copyWith(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(l10n.join_reliefnet_desc, style: textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: l10n.full_name, icon: Icons.person_outline),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal),
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(hintText: "John Doe", prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Full name is required" : null,
                      ),
                      const SizedBox(height: 20),

                      _FieldLabel(label: l10n.phone_number, icon: Icons.phone_outlined),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                          IndiaPhoneFormatter(),
                        ],
                        decoration: const InputDecoration(
                          hintText: "+91 70655 58444",
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty || v.trim() == "+91") return "Phone number is required";
                          final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                          if (digits.length != 12) return "Enter a valid 10-digit number";
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _FieldLabel(label: l10n.email, icon: Icons.email_outlined),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal),
                        decoration: const InputDecoration(hintText: "your@email.com", prefixIcon: Icon(Icons.email_outlined)),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Email is required";
                          if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.\w{2,}$').hasMatch(v.trim())) return "Enter a valid email address";
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _FieldLabel(label: l10n.password, icon: Icons.lock_outline),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure1,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal),
                        decoration: InputDecoration(
                          hintText: "Min. 8 characters",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscure1 = !_obscure1)),
                        ),
                        validator: (v) => (v == null || v.length < 8) ? "Password must be at least 8 characters" : null,
                      ),
                      const SizedBox(height: 20),

                      _FieldLabel(label: l10n.confirm_password, icon: Icons.lock_outline),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscure2,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal),
                        decoration: InputDecoration(
                          hintText: l10n.re_enter_password,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscure2 = !_obscure2)),
                        ),
                        validator: (v) => (v != _passwordController.text) ? "Passwords do not match" : null,
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: _isLoading ? null : () => _signUp(l10n),
                          child: _isLoading
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.person_add_rounded), const SizedBox(width: 8), Text(l10n.create_account, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: RichText(
                            text: TextSpan(
                              style: textTheme.bodyMedium,
                              children: [
                                TextSpan(text: l10n.already_have_account),
                                TextSpan(text: l10n.sign_in, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
