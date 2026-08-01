import '../../onboarding/domain/membership_role.dart';

/// Uma pessoa da organização com o seu perfil — para a lista de "Pessoas".
///
/// Nota: `email` vem tal como devolvido pela API (a policy RLS de
/// `profiles` permite leitura a qualquer autenticado — não há, por agora,
/// masking ao nível do servidor). Esconder o campo na UI para não-admins
/// é só uma medida de interface, não uma fronteira de segurança real;
/// ver README para a função `fetch_org_members` proposta (ainda por aplicar).
class OrgMember {
  const OrgMember({
    required this.membershipId,
    required this.userId,
    required this.role,
    required this.isActive,
    required this.fullName,
    required this.email,
    required this.joinedAt,
    this.avatarUrl,
    this.phone,
  });

  final String membershipId;
  final String userId;
  final MembershipRole role;
  final bool isActive;
  final String fullName;
  final String email;
  final DateTime joinedAt;
  final String? avatarUrl;
  final String? phone;

  factory OrgMember.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>? ?? const {};
    return OrgMember(
      membershipId: map['id'] as String,
      userId: map['user_id'] as String,
      role: MembershipRole.fromString(map['role'] as String),
      isActive: map['is_active'] as bool? ?? true,
      fullName: profile['full_name'] as String? ?? '',
      email: profile['email'] as String? ?? '',
      joinedAt:
          DateTime.tryParse(map['joined_at'] as String? ?? '') ??
          DateTime.now(),
      avatarUrl: profile['avatar_url'] as String?,
      phone: profile['phone'] as String?,
    );
  }
}
