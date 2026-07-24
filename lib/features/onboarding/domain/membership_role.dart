enum MembershipRole {
  admin,
  leader,
  member;

  static MembershipRole fromString(String value) => switch (value) {
    'admin' => MembershipRole.admin,
    'leader' => MembershipRole.leader,
    _ => MembershipRole.member,
  };

  String get value => name;

  bool get isAdmin => this == MembershipRole.admin;

  String get label => switch (this) {
    MembershipRole.admin => 'Administrador',
    MembershipRole.leader => 'Líder',
    MembershipRole.member => 'Membro',
  };
}
