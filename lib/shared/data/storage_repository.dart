import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/supabase/supabase_providers.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(ref.watch(supabaseClientProvider));
});

const _uuid = Uuid();

/// Upload de imagens (avatar, logótipo, capa de evento) — espelha
/// uploadOrgLogoAction/uploadEventImageAction, mas com os caminhos que o
/// RLS de storage.objects permite a um cliente sem service role:
/// - bucket `avatars`: só pode escrever dentro de `{auth.uid()}/...`
/// - bucket `events`: qualquer autenticado pode escrever em qualquer caminho
class StorageRepository {
  StorageRepository(this._client);

  final SupabaseClient _client;

  String _extensionOf(File file) {
    final dot = file.path.lastIndexOf('.');
    return dot == -1 ? 'jpg' : file.path.substring(dot + 1).toLowerCase();
  }

  Future<String> _uploadAndGetUrl(String bucket, String path, File file) async {
    await _client.storage
        .from(bucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));
    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
    // cache-busting, como a app web faz após upload
    return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Foto de perfil — guardada em `avatars/{userId}/avatar-{uuid}.ext`.
  Future<String> uploadAvatarPhoto(File file) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    final path = '$userId/avatar-${_uuid.v4()}.${_extensionOf(file)}';
    return _uploadAndGetUrl('avatars', path, file);
  }

  /// Logótipo da organização — guardado sob a pasta do próprio admin
  /// (`avatars/{userId}/org-logo-{orgId}-{uuid}.ext`) porque o RLS do
  /// bucket `avatars` só permite escrever dentro do próprio uid; o bucket
  /// é público, por isso o URL funciona na mesma para todos os membros.
  Future<String> uploadOrgLogo(String orgId, File file) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    final path = '$userId/org-logo-$orgId-${_uuid.v4()}.${_extensionOf(file)}';
    return _uploadAndGetUrl('avatars', path, file);
  }

  /// Imagem de capa de um evento — `events/{orgId}/{uuid}.ext`.
  Future<String> uploadEventCover(String orgId, File file) async {
    final path = '$orgId/${_uuid.v4()}.${_extensionOf(file)}';
    return _uploadAndGetUrl('events', path, file);
  }
}
