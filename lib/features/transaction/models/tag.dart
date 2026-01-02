class Tag {
  final String id;
  final String name;
  final int? color;

  Tag({required this.id, required this.name, this.color});

  factory Tag.fromMap(String id, Map<String, dynamic> data) {
    return Tag(
      id: id,
      name: data['name'],
      color: data['color'] is int ? data['color'] : null,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'color': color};
}
