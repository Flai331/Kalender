import 'dart:convert';

class IcsSource {
  final String id;
  final String name;
  final String url; // https:// URL oder lokaler Dateipfad
  final bool isFile;
  final int? color; // ARGB int, null = App-Standard
  final bool allowTodoDrop;

  const IcsSource({
    required this.id,
    required this.name,
    required this.url,
    this.isFile = false,
    this.color,
    this.allowTodoDrop = false,
  });

  IcsSource copyWith({
    String? id,
    String? name,
    String? url,
    bool? isFile,
    int? color,
    bool clearColor = false,
    bool? allowTodoDrop,
  }) => IcsSource(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    isFile: isFile ?? this.isFile,
    color: clearColor ? null : (color ?? this.color),
    allowTodoDrop: allowTodoDrop ?? this.allowTodoDrop,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'isFile': isFile,
        'color': color,
        'allowTodoDrop': allowTodoDrop,
      };

  factory IcsSource.fromJson(Map<String, dynamic> json) => IcsSource(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        isFile: json['isFile'] as bool? ?? false,
        color: json['color'] as int?,
        allowTodoDrop: json['allowTodoDrop'] as bool? ?? false,
      );

  static List<IcsSource> listFromJson(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => IcsSource.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<IcsSource> sources) =>
      jsonEncode(sources.map((s) => s.toJson()).toList());
}
