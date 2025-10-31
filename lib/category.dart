import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String name;
  final int colorHex; // ex.: 0xFFE57373

  Category({
    String? id,
    required this.name,
    required this.colorHex,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'],
        name: map['name'],
        colorHex: map['colorHex'],
      );
}
