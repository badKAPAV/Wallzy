import 'package:flutter/material.dart';

class Tag {
  final String id;
  final String name;
  final int? color;

  Tag({required this.id, required this.name, this.color});

  static const List<Color> defaultTagColors = [
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
  ];

  factory Tag.fromMap(String id, Map<String, dynamic> data) {
    return Tag(
      id: id,
      name: data['name'],
      color: data['color'] is int ? data['color'] : null,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'color': color};
}
