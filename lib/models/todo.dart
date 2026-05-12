import 'package:flutter/material.dart';
import 'calendar_event.dart';

enum TodoStatus { pending, started, paused, done }

class RepeatConfig {
  final int? dayOfWeek;   // 1=Mo ... 7=So
  final int? dayOfMonth;  // 1-31

  RepeatConfig({this.dayOfWeek, this.dayOfMonth});

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'dayOfMonth': dayOfMonth,
      };

  factory RepeatConfig.fromJson(Map<String, dynamic> json) => RepeatConfig(
        dayOfWeek: json['dayOfWeek'] as int?,
        dayOfMonth: json['dayOfMonth'] as int?,
      );
}

enum TodoContextMode {
  anyTime,        // überall planbar (Standard)
  freeTime,       // nur in freien Slots (kein Event überlappend)
  categoryEvent,  // nur während Events einer bestimmten Kategorie
  opportunistic,  // weich an nächstes passendes Event hängen
}

enum DaylightMode {
  none,    // kein Tageslicht-Filter
  gps,     // Sonnenauf/-untergang per GPS
  manual,  // manuelles Zeitfenster (dueWindowStartHour/EndHour)
}

class Todo {
  final String id;
  final String title;
  final String description;
  final int estimatedMinutes;
  final bool isCompleted;
  final DateTime? scheduledDate;
  final int? scheduledStartHour;
  final int? scheduledStartMinute;
  final RepeatType repeatType;
  final RepeatConfig? repeatConfig;
  final bool isFixed;
  final TodoStatus status;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final int pausedMinutes;
  final DateTime? pauseStart;
  final String category;
  final DateTime createdAt;
  final String? outlookTaskId;  // Microsoft To Do Task ID
  final String? outlookListId;  // Microsoft To Do List ID
  final TodoContextMode contextMode;
  final EventCategory? requiredCategory;   // für categoryEvent + opportunistic
  final List<int>? allowedWeekdays;        // null=alle; [1..5]=Mo-Fr (1=Mo,7=So)
  final DaylightMode daylightMode;

  Todo({
    required this.id,
    required this.title,
    this.description = '',
    this.estimatedMinutes = 30,
    this.isCompleted = false,
    this.scheduledDate,
    this.scheduledStartHour,
    this.scheduledStartMinute,
    this.repeatType = RepeatType.none,
    this.repeatConfig,
    this.isFixed = false,
    this.status = TodoStatus.pending,
    this.actualStart,
    this.actualEnd,
    this.pausedMinutes = 0,
    this.pauseStart,
    this.category = 'personal',
    required this.createdAt,
    this.outlookTaskId,
    this.outlookListId,
    this.contextMode = TodoContextMode.anyTime,
    this.requiredCategory,
    this.allowedWeekdays,
    this.daylightMode = DaylightMode.none,
  });

  bool get isScheduled => scheduledDate != null;

  TimeOfDay? get scheduledStartTime {
    if (scheduledStartHour == null || scheduledStartMinute == null) return null;
    return TimeOfDay(hour: scheduledStartHour!, minute: scheduledStartMinute!);
  }

  DateTime? get scheduledEndTime {
    if (scheduledDate == null || scheduledStartHour == null) return null;
    final start = DateTime(
      scheduledDate!.year,
      scheduledDate!.month,
      scheduledDate!.day,
      scheduledStartHour!,
      scheduledStartMinute ?? 0,
    );
    return start.add(Duration(minutes: estimatedMinutes));
  }

  int get timeSavedMinutes {
    if (status != TodoStatus.done || actualEnd == null || scheduledEndTime == null) {
      return 0;
    }
    final diff = scheduledEndTime!.difference(actualEnd!).inMinutes - pausedMinutes;
    return diff > 0 ? diff : 0;
  }

  static const Object _unset = Object();

  Todo copyWith({
    String? id,
    String? title,
    String? description,
    int? estimatedMinutes,
    bool? isCompleted,
    DateTime? scheduledDate,
    int? scheduledStartHour,
    int? scheduledStartMinute,
    RepeatType? repeatType,
    RepeatConfig? repeatConfig,
    bool? isFixed,
    TodoStatus? status,
    DateTime? actualStart,
    DateTime? actualEnd,
    int? pausedMinutes,
    DateTime? pauseStart,
    String? category,
    DateTime? createdAt,
    String? outlookTaskId,
    String? outlookListId,
    TodoContextMode? contextMode,
    Object? requiredCategory = _unset,
    Object? allowedWeekdays = _unset,
    DaylightMode? daylightMode,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledStartHour: scheduledStartHour ?? this.scheduledStartHour,
      scheduledStartMinute: scheduledStartMinute ?? this.scheduledStartMinute,
      repeatType: repeatType ?? this.repeatType,
      repeatConfig: repeatConfig ?? this.repeatConfig,
      isFixed: isFixed ?? this.isFixed,
      status: status ?? this.status,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      pausedMinutes: pausedMinutes ?? this.pausedMinutes,
      pauseStart: pauseStart ?? this.pauseStart,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      outlookTaskId: outlookTaskId ?? this.outlookTaskId,
      outlookListId: outlookListId ?? this.outlookListId,
      contextMode: contextMode ?? this.contextMode,
      requiredCategory: requiredCategory == _unset ? this.requiredCategory : requiredCategory as EventCategory?,
      allowedWeekdays: allowedWeekdays == _unset ? this.allowedWeekdays : allowedWeekdays as List<int>?,
      daylightMode: daylightMode ?? this.daylightMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'estimatedMinutes': estimatedMinutes,
        'isCompleted': isCompleted,
        'scheduledDate': scheduledDate?.toUtc().toIso8601String(),
        'scheduledStartHour': scheduledStartHour,
        'scheduledStartMinute': scheduledStartMinute,
        'repeatType': repeatType.name,
        'repeatConfig': repeatConfig?.toJson(),
        'isFixed': isFixed,
        'status': status.name,
        'actualStart': actualStart?.toUtc().toIso8601String(),
        'actualEnd': actualEnd?.toUtc().toIso8601String(),
        'pausedMinutes': pausedMinutes,
        'pauseStart': pauseStart?.toUtc().toIso8601String(),
        'category': category,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'outlookTaskId': outlookTaskId,
        'outlookListId': outlookListId,
        'contextMode': contextMode.name,
        'requiredCategory': requiredCategory?.name,
        'allowedWeekdays': allowedWeekdays,
        'daylightMode': daylightMode.name,
      };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        estimatedMinutes: json['estimatedMinutes'] as int? ?? 30,
        isCompleted: json['isCompleted'] as bool? ?? false,
        scheduledDate: json['scheduledDate'] != null
            ? DateTime.parse(json['scheduledDate'] as String).toLocal()
            : null,
        scheduledStartHour: json['scheduledStartHour'] as int?,
        scheduledStartMinute: json['scheduledStartMinute'] as int?,
        repeatType: RepeatType.values.firstWhere(
          (e) => e.name == json['repeatType'],
          orElse: () => RepeatType.none,
        ),
        repeatConfig: json['repeatConfig'] != null
            ? RepeatConfig.fromJson(json['repeatConfig'] as Map<String, dynamic>)
            : null,
        isFixed: json['isFixed'] as bool? ?? false,
        status: TodoStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TodoStatus.pending,
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
        category: json['category'] as String? ?? 'personal',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String).toLocal()
            : DateTime.now(),
        outlookTaskId: json['outlookTaskId'] as String?,
        outlookListId: json['outlookListId'] as String?,
        contextMode: TodoContextMode.values.firstWhere(
          (e) => e.name == json['contextMode'],
          orElse: () => TodoContextMode.anyTime,
        ),
        requiredCategory: json['requiredCategory'] != null
            ? EventCategory.values.firstWhere(
                (e) => e.name == json['requiredCategory'],
                orElse: () => EventCategory.personal,
              )
            : null,
        allowedWeekdays: (json['allowedWeekdays'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        daylightMode: DaylightMode.values.firstWhere(
          (e) => e.name == json['daylightMode'],
          orElse: () => DaylightMode.none,
        ),
      );
}
