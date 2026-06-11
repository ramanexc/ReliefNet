import 'package:flutter/material.dart';
import 'package:reliefnet/main-pages/volunteer/task_wizard_page.dart';

class TaskDetailPage extends StatelessWidget {
  final String docId;
  const TaskDetailPage({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    return TaskWizardPage(docId: docId);
  }
}