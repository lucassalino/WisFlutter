class Ministry {
  const Ministry({
    required this.id,
    required this.orgId,
    required this.name,
    required this.icon,
    required this.color,
    required this.functions,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String orgId;
  final String name;
  final String icon;
  final String color;
  final List<String> functions;
  final bool isActive;
  final DateTime createdAt;

  factory Ministry.fromMap(Map<String, dynamic> map) => Ministry(
    id: map['id'] as String,
    orgId: map['org_id'] as String,
    name: map['name'] as String,
    icon: map['icon'] as String? ?? '🎵',
    color: map['color'] as String? ?? '#888887',
    functions: (map['functions'] as List? ?? const [])
        .map((f) => f as String)
        .toList(),
    isActive: map['is_active'] as bool? ?? true,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ??
        DateTime.now(),
  );
}
