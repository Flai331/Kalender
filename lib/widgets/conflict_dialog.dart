import 'package:flutter/material.dart';
import '../app_colors.dart';

enum ConflictChoice { keepLocal, keepServer }

class ConflictDialog extends StatelessWidget {
  final String entityTitle;
  final String localSummary;
  final String serverSummary;

  const ConflictDialog({
    super.key,
    required this.entityTitle,
    required this.localSummary,
    required this.serverSummary,
  });

  static Future<ConflictChoice?> show(
    BuildContext context, {
    required String entityTitle,
    required String localSummary,
    required String serverSummary,
  }) {
    return showDialog<ConflictChoice>(
      context: context,
      builder: (_) => ConflictDialog(
        entityTitle: entityTitle,
        localSummary: localSummary,
        serverSummary: serverSummary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Konflikt: $entityTitle',
          style: const TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lokale Version:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(localSummary, style: const TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          const Text('Server-Version:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(serverSummary, style: const TextStyle(color: AppColors.textPrimary)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictChoice.keepServer),
          child: const Text('Server behalten', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictChoice.keepLocal),
          child: const Text('Meine Version', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
