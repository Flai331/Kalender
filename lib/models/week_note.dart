/// Ein Wochenziel. Frueher stand hier nur der Text in der Liste — darum
/// liest [fromJson] beide Formen.
class WeekGoal {
  final String text;
  final bool done;

  const WeekGoal({required this.text, this.done = false});

  WeekGoal copyWith({String? text, bool? done}) =>
      WeekGoal(text: text ?? this.text, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'text': text, 'done': done};

  factory WeekGoal.fromJson(dynamic raw) {
    // Altbestand: die Liste enthielt nur Zeichenketten, nichts war abgehakt.
    if (raw is String) return WeekGoal(text: raw);
    final map = raw as Map<String, dynamic>;
    return WeekGoal(
      text: map['text'] as String? ?? '',
      done: map['done'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WeekGoal && other.text == text && other.done == done;

  @override
  int get hashCode => Object.hash(text, done);

  @override
  String toString() => done ? '[x] $text' : '[ ] $text';
}

class WeekNote {
  final String weekKey; // Format: "2026-W14"
  final String content;
  final List<WeekGoal> goals;

  WeekNote({
    required this.weekKey,
    this.content = '',
    List<WeekGoal>? goals,
  }) : goals = goals ?? [];

  WeekNote copyWith({
    String? weekKey,
    String? content,
    List<WeekGoal>? goals,
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
        'goals': goals.map((g) => g.toJson()).toList(),
      };

  factory WeekNote.fromJson(Map<String, dynamic> json) => WeekNote(
        weekKey: json['weekKey'] as String,
        content: json['content'] as String? ?? '',
        goals: (json['goals'] as List<dynamic>?)
                ?.map(WeekGoal.fromJson)
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
