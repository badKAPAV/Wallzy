import 'package:flutter/material.dart';
import 'package:wallzy/features/tag/services/tag_info.dart';

class Tag {
  final String id;
  final String name;
  final int? color;
  final DateTime createdAt;
  final TagBudgetResetFrequency? tagBudgetFrequency;
  final double? tagBudget;
  final DateTime? eventStartDate;
  final DateTime? eventEndDate;
  final String? iconKey;

  Tag({
    required this.id,
    required this.name,
    this.color,
    required this.createdAt,
    this.tagBudgetFrequency,
    this.tagBudget,
    this.eventStartDate,
    this.eventEndDate,
    this.iconKey,
  });

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
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      tagBudgetFrequency: data['tagBudgetFrequency'] != null
          ? TagBudgetResetFrequency.values.firstWhere(
              (e) => e.name == data['tagBudgetFrequency'],
              orElse: () => TagBudgetResetFrequency.never,
            )
          : null,
      tagBudget: (data['tagBudget'] ?? 0.0).toDouble(),
      eventStartDate: data['eventStartDate'] != null
          ? DateTime.parse(data['eventStartDate'])
          : null,
      eventEndDate: data['eventEndDate'] != null
          ? DateTime.parse(data['eventEndDate'])
          : null,
      iconKey: data['iconKey'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
    'tagBudgetFrequency': tagBudgetFrequency?.name,
    'tagBudget': tagBudget,
    'eventStartDate': eventStartDate?.toIso8601String(),
    'eventEndDate': eventEndDate?.toIso8601String(),
    'iconKey': iconKey,
  };

  Tag copyWith({
    String? id,
    String? name,
    int? color,
    DateTime? createdAt,
    TagBudgetResetFrequency? tagBudgetFrequency,
    double? tagBudget,
    DateTime? eventStartDate,
    DateTime? eventEndDate,
    String? iconKey,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      tagBudgetFrequency: tagBudgetFrequency ?? this.tagBudgetFrequency,
      tagBudget: tagBudget ?? this.tagBudget,
      eventStartDate: eventStartDate ?? this.eventStartDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      iconKey: iconKey ?? this.iconKey,
    );
  }
}
