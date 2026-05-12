import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/feedback_service.dart';

class FeedbackIconButton extends StatelessWidget {
  const FeedbackIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bug_report_outlined, color: AppColors.textDisabled),
      tooltip: 'Fehler melden',
      onPressed: () => FeedbackService.showReportDialog(context),
    );
  }
}
