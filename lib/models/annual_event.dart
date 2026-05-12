class AnnualOccurrence {
  final int year;
  final DateTime? startDate;
  final DateTime? endDate;
  final String notes;

  AnnualOccurrence({
    required this.year,
    this.startDate,
    this.endDate,
    this.notes = '',
  });

  bool get hasDate => startDate != null;

  AnnualOccurrence copyWith({
    int? year,
    Object? startDate = _unset,
    Object? endDate = _unset,
    String? notes,
  }) {
    return AnnualOccurrence(
      year: year ?? this.year,
      startDate: startDate == _unset ? this.startDate : startDate as DateTime?,
      endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
      notes: notes ?? this.notes,
    );
  }

  static const _unset = Object();

  Map<String, dynamic> toJson() => {
        'year': year,
        'startDate': startDate?.toUtc().toIso8601String(),
        'endDate': endDate?.toUtc().toIso8601String(),
        'notes': notes,
      };

  factory AnnualOccurrence.fromJson(Map<String, dynamic> json) =>
      AnnualOccurrence(
        year: json['year'] as int,
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String).toLocal()
            : null,
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String).toLocal()
            : null,
        notes: json['notes'] as String? ?? '',
      );
}

class AnnualEvent {
  final String id;
  final String name;
  final String category;
  final int? colorHex;
  final List<AnnualOccurrence> occurrences;

  AnnualEvent({
    required this.id,
    required this.name,
    this.category = 'personal',
    this.colorHex,
    this.occurrences = const [],
  });

  AnnualOccurrence? occurrenceForYear(int year) {
    final matches = occurrences.where((o) => o.year == year);
    return matches.isEmpty ? null : matches.first;
  }

  AnnualEvent copyWith({
    String? id,
    String? name,
    String? category,
    Object? colorHex = _unset,
    List<AnnualOccurrence>? occurrences,
  }) {
    return AnnualEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      colorHex: colorHex == _unset ? this.colorHex : colorHex as int?,
      occurrences: occurrences ?? this.occurrences,
    );
  }

  static const _unset = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'colorHex': colorHex,
        'occurrences': occurrences.map((o) => o.toJson()).toList(),
      };

  factory AnnualEvent.fromJson(Map<String, dynamic> json) => AnnualEvent(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'personal',
        colorHex: json['colorHex'] as int?,
        occurrences: (json['occurrences'] as List<dynamic>?)
                ?.map((e) =>
                    AnnualOccurrence.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
