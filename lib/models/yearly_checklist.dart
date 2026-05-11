class YearlyChecklist {
  final String id;
  final String title;
  final int reminderMonth; // 1=Januar ... 12=Dezember
  final String template;
  final int lastTriggeredYear;

  YearlyChecklist({
    required this.id,
    required this.title,
    required this.reminderMonth,
    this.template = '',
    this.lastTriggeredYear = 0,
  });

  bool shouldTrigger(DateTime now) {
    return now.month == reminderMonth && lastTriggeredYear < now.year;
  }

  YearlyChecklist copyWith({
    String? id,
    String? title,
    int? reminderMonth,
    String? template,
    int? lastTriggeredYear,
  }) {
    return YearlyChecklist(
      id: id ?? this.id,
      title: title ?? this.title,
      reminderMonth: reminderMonth ?? this.reminderMonth,
      template: template ?? this.template,
      lastTriggeredYear: lastTriggeredYear ?? this.lastTriggeredYear,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'reminderMonth': reminderMonth,
        'template': template,
        'lastTriggeredYear': lastTriggeredYear,
      };

  factory YearlyChecklist.fromJson(Map<String, dynamic> json) =>
      YearlyChecklist(
        id: json['id'] as String,
        title: json['title'] as String,
        reminderMonth: json['reminderMonth'] as int,
        template: json['template'] as String? ?? '',
        lastTriggeredYear: json['lastTriggeredYear'] as int? ?? 0,
      );

  static String monthName(int month) {
    const names = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return names[month];
  }
}
