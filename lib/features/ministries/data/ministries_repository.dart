import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/ministry.dart';
import '../domain/ministry_member.dart';

final ministriesRepositoryProvider = Provider<MinistriesRepository>((ref) {
  return MinistriesRepository(ref.watch(supabaseClientProvider));
});

class MinistryPayload {
  const MinistryPayload({
    required this.name,
    required this.icon,
    required this.color,
    required this.functions,
  });

  final String name;
  final String icon;
  final String color;
  final List<String> functions;

  Map<String, dynamic> toMap() => {
    'name': name,
    'icon': icon,
    'color': color,
    'functions': functions,
  };
}

class MinistriesRepository {
  MinistriesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Ministry>> fetchMinistries(String orgId) async {
    final rows = await _client
        .from('ministries')
        .select()
        .eq('org_id', orgId)
        .order('is_active', ascending: false)
        .order('name');
    return (rows as List)
        .map((row) => Ministry.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Ministry> createMinistry(String orgId, MinistryPayload payload) async {
    final row = await _client
        .from('ministries')
        .insert({...payload.toMap(), 'org_id': orgId})
        .select()
        .single();
    return Ministry.fromMap(row);
  }

  Future<void> updateMinistry(String id, MinistryPayload payload) async {
    await _client
        .from('ministries')
        .update({
          ...payload.toMap(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await _client
        .from('ministries')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteMinistry(String id) async {
    await _client.from('ministries').delete().eq('id', id);
  }

  Future<List<MinistryMember>> fetchMinistryMembers(String ministryId) async {
    final rows = await _client
        .from('ministry_members')
        .select('user_id, functions, profile:profiles(full_name, avatar_url)')
        .eq('ministry_id', ministryId)
        .eq('is_active', true);
    return (rows as List)
        .map((row) => MinistryMember.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Substitui por completo os membros do ministério (o mesmo padrão
  /// "apaga tudo e reinsere" usado pela app web).
  Future<void> replaceMinistryMembers(
    String ministryId,
    List<MinistryMember> members,
  ) async {
    await _client
        .from('ministry_members')
        .delete()
        .eq('ministry_id', ministryId);
    if (members.isEmpty) return;
    await _client.from('ministry_members').insert([
      for (final member in members)
        {
          'ministry_id': ministryId,
          'user_id': member.userId,
          'functions': member.functions,
          'is_active': true,
        },
    ]);
  }
}
