import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/annual_event.dart';
import '../services/local_service.dart';
import 'annual_event_edit_screen.dart';

class YearlyPlannerScreen extends StatelessWidget {
  const YearlyPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = [currentYear, currentYear + 1, currentYear - 1];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Jahresplanung',
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AnnualEventEditScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AnnualEvent>>(
        stream: LocalService.annualEvents(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!;
          if (events.isEmpty) {
            return const Center(
              child: Text(
                'Noch keine Jahres-Events.\nTippe + um eines hinzuzufügen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: years.length,
            itemBuilder: (context, yi) {
              final year = years[yi];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '$year',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                  ...events.map((e) {
                    final occ = e.occurrenceForYear(year);
                    final hasDate = occ?.hasDate ?? false;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.colorHex != null
                              ? Color(e.colorHex!)
                              : AppColors.forCategory(e.category),
                        ),
                      ),
                      title: Text(e.name,
                          style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: hasDate
                          ? Text(
                              _formatDates(occ!),
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            )
                          : const Text(
                              '⚠️ Datum noch nicht geplant',
                              style: TextStyle(
                                  color: Colors.orangeAccent, fontSize: 12),
                            ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AnnualEventEditScreen(event: e, initialYear: year)),
                      ),
                    );
                  }),
                  const Divider(color: AppColors.divider),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatDates(AnnualOccurrence occ) {
    if (occ.startDate == null) return '';
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    if (occ.endDate != null) {
      return '${fmt(occ.startDate!)} – ${fmt(occ.endDate!)}';
    }
    return fmt(occ.startDate!);
  }
}
