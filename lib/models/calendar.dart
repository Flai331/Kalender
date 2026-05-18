import 'ics_source.dart';

class Calendar {
  final String id;
  final String name;
  final int color; // ARGB
  final List<IcsSource> icsFeeds;
  final bool blocksAutoShift;

  const Calendar({
    required this.id,
    required this.name,
    required this.color,
    this.icsFeeds = const [],
    this.blocksAutoShift = false,
  });

  Calendar copyWith({
    String? id,
    String? name,
    int? color,
    List<IcsSource>? icsFeeds,
    bool? blocksAutoShift,
  }) =>
      Calendar(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        icsFeeds: icsFeeds ?? this.icsFeeds,
        blocksAutoShift: blocksAutoShift ?? this.blocksAutoShift,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'icsFeeds': icsFeeds.map((f) => f.toJson()).toList(),
        'blocksAutoShift': blocksAutoShift,
      };

  factory Calendar.fromJson(Map<String, dynamic> json) => Calendar(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as int,
        icsFeeds: (json['icsFeeds'] as List<dynamic>?)
                ?.map((e) => IcsSource.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        blocksAutoShift: json['blocksAutoShift'] as bool? ?? false,
      );
}
