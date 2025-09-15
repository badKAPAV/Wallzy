class Person {
  final String id;
  final String name;

  Person({required this.id, required this.name});

  factory Person.fromMap(String id, Map<String, dynamic> data) {
    return Person(id: id, name: data['name']);
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}
