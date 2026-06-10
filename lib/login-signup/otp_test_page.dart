import 'package:flutter/material.dart';
import 'package:reliefnet/services/auth_service.dart';

class OTPTestPage extends StatefulWidget {
  const OTPTestPage({super.key});

  @override
  State<OTPTestPage> createState() => _OTPTestPageState();
}

class _OTPTestPageState extends State<OTPTestPage> {
  final _phoneController = TextEditingController(text: "+91 ");
  final _logs = <String>[];
  bool _isLoading = false;
  String? _verificationId;

  void _addLog(String msg) {
    final time = DateTime.now().toString().split('.').first.split(' ').last;
    setState(() {
      _logs.insert(0, "[$time] $msg");
    });
    debugPrint("OTP_TEST: $msg");
  }

  Future<void> _startVerification() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.length < 10) {
      _addLog("ERROR: Invalid phone format");
      return;
    }

    setState(() {
      _isLoading = true;
      _logs.clear();
    });

    _addLog("Starting verification for $phone...");
    _addLog("Waiting for Firebase response (this can take 30s)...");

    // Add a manual timeout log if nothing happens in 20 seconds
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted && _isLoading) {
        _addLog("WARNING: Still waiting. If this persists, reCAPTCHA might be blocked or SHA-1 is missing.");
      }
    });

    try {
      await AuthService().verifyPhoneNumber(
        phone,
        onCodeSent: (vid, token) {
          setState(() {
            _isLoading = false;
            _verificationId = vid;
          });
          _addLog("SUCCESS: Code Sent! ID: ${vid.substring(0, 5)}...");
        },
        onFailed: (e) {
          setState(() => _isLoading = false);
          _addLog("FAILED: ${e.code}");
          _addLog("MESSAGE: ${e.message}");
          
          if (e.code == 'app-not-verified') {
            _addLog("TIP: Check SHA-1/SHA-256 in Firebase Console.");
          } else if (e.code == 'too-many-requests') {
            _addLog("TIP: Number blocked temporarily. Use a different number or wait.");
          } else if (e.code == 'invalid-phone-number') {
            _addLog("TIP: Ensure number is in +91XXXXXXXXXX format.");
          }
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _addLog("UNEXPECTED ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OTP Audit Tool")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Step 1: Send OTP to verify configuration",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Phone Number (E.164)",
                        hintText: "+917065558444",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _startVerification,
                        child: _isLoading 
                          ? const CircularProgressIndicator() 
                          : const Text("Trigger Verification"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.terminal, size: 16),
                SizedBox(width: 8),
                Text("Live Audit Logs", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final isError = _logs[index].contains("FAILED") || _logs[index].contains("ERROR");
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _logs[index],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isError ? Colors.red : Colors.green[700],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
