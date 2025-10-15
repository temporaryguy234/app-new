class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'],
      photoUrl: map['photoUrl'],
      createdAt: DateTime.parse(map['createdAt']),
      lastLoginAt: map['lastLoginAt'] != null 
          ? DateTime.parse(map['lastLoginAt']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
