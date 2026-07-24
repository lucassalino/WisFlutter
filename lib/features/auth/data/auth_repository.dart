import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Deep link para onde o Supabase reenvia depois de confirmar o email ou
/// pedir recuperação de password — registado como esquema `wis://` no
/// AndroidManifest/Info.plist. O `supabase_flutter` já escuta estes links
/// automaticamente (`SupabaseAuth`/`detectSessionInUri`) e estabelece a
/// sessão sozinho a partir do token na URL; não é preciso código extra
/// aqui além de indicar este redirect nas chamadas de auth.
const authCallbackRedirectUrl = 'wis://auth-callback';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Registo: nome, email, password. O trigger `handle_new_user` cria a
  /// linha em `profiles` automaticamente ao inserir em `auth.users`.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: authCallbackRedirectUrl,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: authCallbackRedirectUrl,
    );
  }

  /// Usado depois de um convite/recuperação, quando já existe uma sessão
  /// de recuperação ativa (deep link) e só falta definir a password nova.
  Future<void> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;
}
