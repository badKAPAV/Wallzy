class Tag {
  final String id;
  final String name;

  Tag({required this.id, required this.name});

  factory Tag.fromMap(String id, Map<String, dynamic> data) {
    return Tag(id: id, name: data['name']);
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}
