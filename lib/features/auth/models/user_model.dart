/// Represents an authenticated user profile within the BMS Mobile ecosystem.
/// Encapsulates user identity, clinical or administrative role, and contact information.
class UserModel {
  /// Unique identifier of the user (UUID or MongoDB ObjectId).
  final String id;

  /// User login name.
  final String username;

  /// User primary email address.
  final String email;

  /// Full display name of the user or patient.
  final String fullName;

  /// Optional telephone number.
  final String? phoneNumber;

  /// Assigned system role (e.g., Patient, Doctor, LabUser, Receptionist, Manager, Admin).
  final String role;

  /// Creates a new [UserModel] instance.
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
