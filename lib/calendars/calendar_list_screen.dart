import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/calendar.dart';
import '../services/calendar_service.dart';
import 'calendar_edit_screen.dart';

class CalendarListScreen extends StatelessWidget {
  const CalendarListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Kalender',
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarEditScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Calendar>>(
        stream: CalendarService.calendarsStream(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cals = snap.data!;
          if (cals.isEmpty) {
            return const Center(
              child: Text(
                'Keine Kalender.\nTippe + um einen zu erstellen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            itemCount: cals.length,
            separatorBuilder: (ctx, i) =>
                const Divider(color: AppColors.divider, height: 1),
            itemBuilder: (context, i) {
              final cal = cals[i];
              return ListTile(
                leading: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(cal.color),
                  ),
                ),
                title: Text(cal.name,
                    style:
                        const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(
                  cal.icsFeeds.isEmpty
                      ? 'Manuell'
                      : '${cal.icsFeeds.length} Feed${cal.icsFeeds.length > 1 ? "s" : ""}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: cal.blocksAutoShift
                    ? const Icon(Icons.block,
                        size: 14, color: AppColors.textDisabled)
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CalendarEditScreen(calendar: cal)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
