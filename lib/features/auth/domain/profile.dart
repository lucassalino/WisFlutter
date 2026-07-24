class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.phone,
    this.birthday,
  });

  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String? phone;
  final DateTime? birthday;

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    id: map['id'] as String,
    email: map['email'] as String,
    fullName: map['full_name'] as String? ?? '',
    avatarUrl: map['avatar_url'] as String?,
    phone: map['phone'] as String?,
    birthday: map['birthday'] != null
        ? DateTime.parse(map['birthday'] as String)
        : null,
  );
}
