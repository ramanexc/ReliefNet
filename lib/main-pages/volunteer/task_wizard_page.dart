import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'step_info.dart';
import 'step_geofence.dart';
import 'step_resolve.dart';
import 'step_done.dart';
import 'step_rejected.dart';

class TaskWizardPage extends StatefulWidget {
  final String docId;
  const TaskWizardPage({super.key, required this.docId});

  @override
  State<TaskWizardPage> createState() => _TaskWizardPageState();
}

class _TaskWizardPageState extends State<TaskWizardPage> {
  final PageController _pageController = PageController();
  int _currentStepIndex = 0;
  bool _initialized = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToStep(int index) {
    setState(() {
      _currentStepIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleDecline() async {
    final reasonController = TextEditingController();
    bool showError = false;
    final quickReasons = ["Too far away", "Wrong skillset", "Wrongfully assigned"];

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Decline this task?"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Please select a reason or write one below:"),
                const SizedBox(height: 12),
                
                // Quick Choice Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickReasons.map((reason) {
                    final isSelected = reasonController.text.trim() == reason;
                    return ChoiceChip(
                      label: Text(reason, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                      selected: isSelected,
                      selectedColor: Colors.red.shade600,
                      onSelected: (selected) {
                        setDialog(() {
                          reasonController.text = reason;
                          showError = false;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  onChanged: (_) {
                    if (showError) setDialog(() => showError = false);
                  },
                  decoration: InputDecoration(
                    hintText: "Add specific comments or detail your reason...",
                    filled: true,
                    errorText: showError ? "Please provide a reason." : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  setDialog(() => showError = true);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text("Decline", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (!mounted || confirmed != true) return;

    final reason = reasonController.text.trim();
    Navigator.pop(context); // Close detail page

    await FirebaseFirestore.instance.collection('reports').doc(widget.docId).update({
      'status': 'rejected',
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').doc(widget.docId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_initialized) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("Error fetching task details.")));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'assigned';

        // Direct redirects if final state
        if (status == 'completed') {
          return StepDone(data: data, docId: widget.docId);
        }
        if (status == 'rejected') {
          return StepRejected(data: data);
        }

        // Active steps setup
        int unlockedMaxIndex = 0;
        if (status == 'in_progress') {
          unlockedMaxIndex = 1;
        } else if (status == 'reached') {
          unlockedMaxIndex = 2;
        }

        // Set initial step based on status only once
        if (!_initialized) {
          _currentStepIndex = unlockedMaxIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(_currentStepIndex);
            }
          });
          _initialized = true;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Active Assignment"),
            centerTitle: true,
            actions: [
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'decline') _handleDecline();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'decline',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 20),
                        SizedBox(width: 10),
                        Text("Decline Task", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? Colors.black.withValues(alpha: 0.1) : Colors.grey.shade100,
                child: Row(
                  children: [
                    _buildStepIndicatorTab(0, "1. Information", unlockedMaxIndex),
                    _buildStepIndicatorTab(1, "2. Arrival", unlockedMaxIndex),
                    _buildStepIndicatorTab(2, "3. Resolution", unlockedMaxIndex),
                  ],
                ),
              ),
            ),
          ),
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Enforce button-triggered or tab-triggered progression
            onPageChanged: (index) {
              setState(() {
                _currentStepIndex = index;
              });
            },
            children: [
              StepInfo(
                docId: widget.docId,
                data: data,
                onNext: () => _navigateToStep(1),
              ),
              StepGeofence(
                docId: widget.docId,
                data: data,
                onSuccess: () => _navigateToStep(2),
              ),
              StepResolve(
                docId: widget.docId,
                data: data,
                onSuccess: () {
                  // Rebuilding automatically moves user to StepDone
                  _initialized = false;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepIndicatorTab(int index, String label, int unlockedMaxIndex) {
    final isSelected = _currentStepIndex == index;
    final isUnlocked = index <= unlockedMaxIndex;
    final colorScheme = Theme.of(context).colorScheme;

    Color tabColor = Colors.grey.shade400;
    if (isSelected) {
      tabColor = colorScheme.primary;
    } else if (isUnlocked) {
      tabColor = Colors.green.shade600;
    }

    return Expanded(
      child: GestureDetector(
        onTap: isUnlocked ? () => _navigateToStep(index) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: tabColor,
                width: isSelected ? 3.0 : 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected || isUnlocked ? FontWeight.bold : FontWeight.normal,
                  color: tabColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
