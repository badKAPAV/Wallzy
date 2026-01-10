class UserModel {
  final String uid;
  final String name;
  final String? email;
  final String? photoURL;
  final DateTime? userCreatedAt;
  final bool isProUser;

  const UserModel({
    required this.uid,
    required this.name,
    this.email,
    this.photoURL,
    this.userCreatedAt,
    this.isProUser = false,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      userCreatedAt: data['userCreatedAt'] != null
          ? DateTime.parse(data['userCreatedAt'])
          : null,
      isProUser: data['isProUser'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoURL': photoURL,
      'userCreatedAt': userCreatedAt?.toIso8601String(),
      'isProUser': isProUser,
    };
  }
}
