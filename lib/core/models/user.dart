class UserModel {
  final String uid;
  final String name;
  final String? email;
  final String? photoURL;
  final DateTime? userCreatedAt;
  final bool isProUser;
  final DateTime? dob;
  final bool hasPassword;

  const UserModel({
    required this.uid,
    required this.name,
    this.email,
    this.photoURL,
    this.userCreatedAt,
    this.isProUser = false,
    this.dob,
    this.hasPassword = false,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      userCreatedAt: data['userCreatedAt'] != null
          ? DateTime.parse(data['userCreatedAt'])
          : DateTime.parse("2025-11-23T00:00:00.000000"),
      isProUser: data['isProUser'] ?? false,
      dob: data['dob'] != null ? DateTime.parse(data['dob']) : null,
      hasPassword: data['hasPassword'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoURL': photoURL,
      'userCreatedAt': userCreatedAt?.toIso8601String(),
      'isProUser': isProUser,
      'dob': dob?.toIso8601String(),
      'hasPassword': hasPassword,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoURL,
    DateTime? userCreatedAt,
    bool? isProUser,
    DateTime? dob,
    bool? hasPassword,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      userCreatedAt: userCreatedAt ?? this.userCreatedAt,
      isProUser: isProUser ?? this.isProUser,
      dob: dob ?? this.dob,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }
}
