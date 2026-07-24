/// Pessoa da organização, para seletores (adicionar a um ministério, escalar
/// para um evento, etc.) — não é o mesmo que `Profile` porque só carrega os
/// campos necessários para listar/escolher.
class OrgMemberOption {
  const OrgMemberOption({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
  });

  final String userId;
  final String fullName;
  final String? avatarUrl;

  factory OrgMemberOption.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>?;
    return OrgMemberOption(
      userId: map['user_id'] as String,
      fullName: profile?['full_name'] as String? ?? '',
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
