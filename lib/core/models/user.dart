class UserModel {
  final String uid;
  final String name;
  final String? email;
  final String? photoURL;

  const UserModel({required this.uid, required this.name, this.email, this.photoURL});

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoURL': photoURL,
    };
  }
}