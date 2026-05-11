import 'package:flutter/material.dart';

enum RepeatType { none, daily, weekly, monthly, yearly }

enum EventCategory { work, sport, vacation, personal }

enum EventStatus { pending, started, paused, done }

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isFixed;
  final bool isAllDay;
  final RepeatType repeatType;
  final String? repeatNote;
  final EventCategory category;
  final String source; // 'app' | 'outlook'
  final String? outlookEventId; // Graph API event ID für PATCH-Calls
  final EventStatus status;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final int pausedMinutes;
  final DateTime? pauseStart;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.isFixed = false,
    this.isAllDay = false,
    this.repeatType = RepeatType.none,
    this.repeatNote,
    this.category = EventCategory.personal,
    this.source = 'app',
    this.outlookEventId,
    this.status = EventStatus.pending,
    this.actualStart,
    this.actualEnd,
    this.pausedMinutes = 0,
    this.pauseStart,
  });

  Duration get scheduledDuration => endTime.difference(startTime);

  int get timeSavedMinutes {
    if (status != EventStatus.done || actualEnd == null) return 0;
    final scheduled = endTime;
    final actual = actualEnd!.add(Duration(minutes: pausedMinutes));
    final diff = scheduled.difference(actual).inMinutes;
    return diff > 0 ? diff : 0;
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isFixed,
    bool? isAllDay,
    RepeatType? repeatType,
    String? repeatNote,
    EventCategory? category,
    String? source,
    String? outlookEventId,
    EventStatus? status,
    DateTime? actualStart,
    DateTime? actualEnd,
    int? pausedMinutes,
    DateTime? pauseStart,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isFixed: isFixed ?? this.isFixed,
      isAllDay: isAllDay ?? this.isAllDay,
      repeatType: repeatType ?? this.repeatType,
      repeatNote: repeatNote ?? this.repeatNote,
      category: category ?? this.category,
      source: source ?? this.source,
      outlookEventId: outlookEventId ?? this.outlookEventId,
      status: status ?? this.status,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      pausedMinutes: pausedMinutes ?? this.pausedMinutes,
      pauseStart: pauseStart ?? this.pauseStart,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'isFixed': isFixed,
        'isAllDay': isAllDay,
        'repeatType': repeatType.name,
        'repeatNote': repeatNote,
        'category': category.name,
        'source': source,
        'outlookEventId': outlookEventId,
        'status': status.name,
        'actualStart': actualStart?.toUtc().toIso8601String(),
        'actualEnd': actualEnd?.toUtc().toIso8601String(),
        'pausedMinutes': pausedMinutes,
        'pauseStart': pauseStart?.toUtc().toIso8601String(),
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        startTime: DateTime.parse(json['startTime'] as String).toLocal(),
        endTime: DateTime.parse(json['endTime'] as String).toLocal(),
        isFixed: json['isFixed'] as bool? ?? false,
        isAllDay: json['isAllDay'] as bool? ?? false,
        repeatType: RepeatType.values.firstWhere(
          (e) => e.name == json['repeatType'],
          orElse: () => RepeatType.none,
        ),
        repeatNote: json['repeatNote'] as String?,
        category: EventCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => EventCategory.personal,
        ),
        source: json['source'] as String? ?? 'app',
        outlookEventId: json['outlookEventId'] as String?,
        status: EventStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => EventStatus.pending,
        ),
        actualStart: json['actualStart'] != null
            ? DateTime.parse(json['actualStart'] as String).toLocal()
            : null,
        actualEnd: json['actualEnd'] != null
            ? DateTime.parse(json['actualEnd'] as String).toLocal()
            : null,
        pausedMinutes: json['pausedMinutes'] as int? ?? 0,
        pauseStart: json['pauseStart'] != null
            ? DateTime.parse(json['pauseStart'] as String).toLocal()
            : null,
      );

  // Hilfsmethode: TimeOfDay aus startTime
  TimeOfDay get startTimeOfDay =>
      TimeOfDay(hour: startTime.hour, minute: startTime.minute);
}
