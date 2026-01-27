class Goal {
  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final DateTime targetDate;
  final List<String> accountsList;
  final DateTime createdAt;
  final String? iconKey;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.targetDate,
    required this.accountsList,
    required this.createdAt,
    this.iconKey,
  });

  factory Goal.fromMap(String id, Map<String, dynamic> data) {
    return Goal(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      targetAmount: (data['amount'] ?? 0.0).toDouble(),
      targetDate: data['targetDate'] != null
          ? DateTime.parse(data['targetDate'])
          : DateTime.now(),
      accountsList: List<String>.from(data['accountsList'] ?? []),
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      iconKey: data['iconKey'],
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'amount': targetAmount,
    'targetDate': targetDate.toIso8601String(),
    'accountsList': accountsList,
    'createdAt': createdAt.toIso8601String(),
    'iconKey': iconKey,
  };

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    double? targetAmount,
    DateTime? targetDate,
    List<String>? accountsList,
    DateTime? createdAt,
    String? iconKey,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
      accountsList: accountsList ?? this.accountsList,
      createdAt: createdAt ?? this.createdAt,
      iconKey: iconKey ?? this.iconKey,
    );
  }
}
