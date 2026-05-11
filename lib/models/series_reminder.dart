class SeriesReminder {
  final String id;
  final String title;
  final String outlookCalendarId;
  final String triggerEventKeyword;
  final int normalTriggerDay;
  final String fallbackCondition; // 'if_event_on_day' | 'always'
  final int fallbackDay;
  final int fallbackOffsetMinutes;
  final int windowStartHour;
  final int windowStartMinute;
  final int windowEndHour;
  final int windowEndMinute;
  final String message;
  final bool isActive;

  SeriesReminder({
    required this.id,
    required this.title,
    this.outlookCalendarId = '',
    this.triggerEventKeyword = '',
    required this.normalTriggerDay,
    this.fallbackCondition = 'if_event_on_day',
    required this.fallbackDay,
    this.fallbackOffsetMinutes = 60,
    this.windowStartHour = 8,
    this.windowStartMinute = 0,
    this.windowEndHour = 22,
    this.windowEndMinute = 0,
    required this.message,
    this.isActive = true,
  });

  SeriesReminder copyWith({
    String? id,
    String? title,
    String? outlookCalendarId,
    String? triggerEventKeyword,
    int? normalTriggerDay,
    String? fallbackCondition,
    int? fallbackDay,
    int? fallbackOffsetMinutes,
    int? windowStartHour,
    int? windowStartMinute,
    int? windowEndHour,
    int? windowEndMinute,
    String? message,
    bool? isActive,
  }) {
    return SeriesReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      outlookCalendarId: outlookCalendarId ?? this.outlookCalendarId,
      triggerEventKeyword: triggerEventKeyword ?? this.triggerEventKeyword,
      normalTriggerDay: normalTriggerDay ?? this.normalTriggerDay,
      fallbackCondition: fallbackCondition ?? this.fallbackCondition,
      fallbackDay: fallbackDay ?? this.fallbackDay,
      fallbackOffsetMinutes:
          fallbackOffsetMinutes ?? this.fallbackOffsetMinutes,
      windowStartHour: windowStartHour ?? this.windowStartHour,
      windowStartMinute: windowStartMinute ?? this.windowStartMinute,
      windowEndHour: windowEndHour ?? this.windowEndHour,
      windowEndMinute: windowEndMinute ?? this.windowEndMinute,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'outlookCalendarId': outlookCalendarId,
        'triggerEventKeyword': triggerEventKeyword,
        'normalTriggerDay': normalTriggerDay,
        'fallbackCondition': fallbackCondition,
        'fallbackDay': fallbackDay,
        'fallbackOffsetMinutes': fallbackOffsetMinutes,
        'windowStartHour': windowStartHour,
        'windowStartMinute': windowStartMinute,
        'windowEndHour': windowEndHour,
        'windowEndMinute': windowEndMinute,
        'message': message,
        'isActive': isActive,
      };

  factory SeriesReminder.fromJson(Map<String, dynamic> json) => SeriesReminder(
        id: json['id'] as String,
        title: json['title'] as String,
        outlookCalendarId: json['outlookCalendarId'] as String? ?? '',
        triggerEventKeyword: json['triggerEventKeyword'] as String? ?? '',
        normalTriggerDay: json['normalTriggerDay'] as int,
        fallbackCondition:
            json['fallbackCondition'] as String? ?? 'if_event_on_day',
        fallbackDay: json['fallbackDay'] as int,
        fallbackOffsetMinutes: json['fallbackOffsetMinutes'] as int? ?? 60,
        windowStartHour: json['windowStartHour'] as int? ?? 8,
        windowStartMinute: json['windowStartMinute'] as int? ?? 0,
        windowEndHour: json['windowEndHour'] as int? ?? 22,
        windowEndMinute: json['windowEndMinute'] as int? ?? 0,
        message: json['message'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
      );
}
