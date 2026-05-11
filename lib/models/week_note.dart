class WeekNote {
  final String weekKey; // Format: "2026-W14"
  final String content;
  final List<String> goals;

  WeekNote({
    required this.weekKey,
    this.content = '',
    List<String>? goals,
  }) : goals = goals ?? [];

  WeekNote copyWith({
    String? weekKey,
    String? content,
    List<String>? goals,
  }) {
    return WeekNote(
      weekKey: weekKey ?? this.weekKey,
      content: content ?? this.content,
      goals: goals ?? List.from(this.goals),
    );
  }

  Map<String, dynamic> toJson() => {
        'weekKey': weekKey,
        'content': content,
        'goals': goals,
      };

  factory WeekNote.fromJson(Map<String, dynamic> json) => WeekNote(
        weekKey: json['weekKey'] as String,
        content: json['content'] as String? ?? '',
        goals: (json['goals'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  static String keyForDate(DateTime date) {
    final weekNumber = _isoWeekNumber(date);
    return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  static int _isoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(
      '${date.difference(DateTime(date.year, 1, 1)).inDays + 1}',
    );
    final wday = date.weekday;
    return ((dayOfYear - wday + 10) / 7).floor();
  }
}
