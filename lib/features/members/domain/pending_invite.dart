import '../../onboarding/domain/membership_role.dart';

class PendingInvite {
  const PendingInvite({
    required this.id,
    required this.orgId,
    required this.email,
    required this.name,
    required this.role,
  });

  final String id;
  final String orgId;
  final String email;
  final String name;
  final MembershipRole role;

  factory PendingInvite.fromMap(Map<String, dynamic> map) => PendingInvite(
    id: map['id'] as String,
    orgId: map['org_id'] as String,
    email: map['email'] as String,
    name: map['name'] as String,
    role: MembershipRole.fromString(map['role'] as String),
  );
}
