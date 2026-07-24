import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile> fetchProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromMap(row);
  }

  Future<void> updateProfile({
    required String fullName,
    String? phone,
    DateTime? birthday,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    await _client
        .from('profiles')
        .update({
          'full_name': fullName,
          'phone': phone,
          'birthday': birthday != null
              ? '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}'
              : null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<void> updateAvatarUrl(String avatarUrl) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    await _client
        .from('profiles')
        .update({
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  /// Elimina permanentemente a conta — RPC `delete_own_account`
  /// (SECURITY DEFINER, já existente) apaga `auth.users`, o que cai em
  /// cascata sobre o perfil e as suas memberships.
  Future<void> deleteOwnAccount() async {
    await _client.rpc('delete_own_account');
  }
}
