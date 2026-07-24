class MinistryMember {
  const MinistryMember({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.functions,
  });

  final String userId;
  final String fullName;
  final String? avatarUrl;
  final List<String> functions;

  factory MinistryMember.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>?;
    return MinistryMember(
      userId: map['user_id'] as String,
      fullName: profile?['full_name'] as String? ?? '',
      avatarUrl: profile?['avatar_url'] as String?,
      functions: (map['functions'] as List? ?? const [])
          .map((f) => f as String)
          .toList(),
    );
  }
}
