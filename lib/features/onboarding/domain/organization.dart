import 'membership_role.dart';

class Organization {
  const Organization({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.inviteCode,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String inviteCode;

  factory Organization.fromMap(Map<String, dynamic> map) => Organization(
    id: map['id'] as String,
    name: map['name'] as String,
    logoUrl: map['logo_url'] as String?,
    inviteCode: map['invite_code'] as String,
  );
}

/// An organization the current user belongs to, with their role in it —
/// mirrors joining `organizations` with the caller's `organization_members` row.
class OrganizationMembership {
  const OrganizationMembership({
    required this.organization,
    required this.membershipId,
    required this.role,
    required this.isActive,
  });

  final Organization organization;
  final String membershipId;
  final MembershipRole role;
  final bool isActive;

  factory OrganizationMembership.fromMap(Map<String, dynamic> map) {
    final orgMap = map['organizations'] as Map<String, dynamic>;
    return OrganizationMembership(
      organization: Organization.fromMap(orgMap),
      membershipId: map['id'] as String,
      role: MembershipRole.fromString(map['role'] as String),
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
