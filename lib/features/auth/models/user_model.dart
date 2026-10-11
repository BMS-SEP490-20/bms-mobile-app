class UserModel {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String role;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'],
      role: json['role'] ?? 'Patient',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'fullName': fullName,
    'phoneNumber': phoneNumber,
    'role': role,
  };
}
