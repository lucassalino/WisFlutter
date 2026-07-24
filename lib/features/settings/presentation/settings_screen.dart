import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/data/storage_repository.dart';
import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/image_picker_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../onboarding/data/organizations_repository.dart';
import '../../onboarding/domain/membership_role.dart';
import '../../onboarding/domain/organization.dart';
import '../../profile/data/profile_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _orgNameController = TextEditingController();
  DateTime? _birthday;
  String? _avatarUrl;
  bool _profileLoading = true;
  bool _savingProfile = false;
  bool _savingOrg = false;
  bool _uploadingAvatar = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    final membership = ref.read(orgStoreProvider);
    _orgNameController.text = membership?.organization.name ?? '';
  }

  Future<void> _loadProfile() async {
    final profile = await ref.read(profileRepositoryProvider).fetchProfile();
    if (!mounted) return;
    setState(() {
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone ?? '';
      _birthday = profile.birthday;
      _avatarUrl = profile.avatarUrl;
      _profileLoading = false;
    });
  }

  Future<void> _changeAvatar() async {
    final file = await pickAndCropImage(
      context,
      preset: CropAspectRatioPreset.square,
    );
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await ref
          .read(storageRepositoryProvider)
          .uploadAvatarPhoto(file);
      await ref.read(profileRepositoryProvider).updateAvatarUrl(url);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atualizar a foto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _changeOrgLogo(OrganizationMembership membership) async {
    final file = await pickAndCropImage(
      context,
      preset: CropAspectRatioPreset.square,
    );
    if (file == null) return;
    setState(() => _uploadingLogo = true);
    try {
      final url = await ref
          .read(storageRepositoryProvider)
          .uploadOrgLogo(membership.organization.id, file);
      await ref
          .read(organizationsRepositoryProvider)
          .updateOrganizationLogo(membership.organization.id, url);
      ref
          .read(orgStoreProvider.notifier)
          .setActive(
            OrganizationMembership(
              organization: Organization(
                id: membership.organization.id,
                name: membership.organization.name,
                logoUrl: url,
                inviteCode: membership.organization.inviteCode,
              ),
              membershipId: membership.membershipId,
              role: membership.role,
              isActive: membership.isActive,
            ),
          );
      bumpRefreshTick(ref);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar o logótipo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _orgNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            birthday: _birthday,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar o perfil.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveOrgName(String orgId) async {
    setState(() => _savingOrg = true);
    try {
      await ref
          .read(organizationsRepositoryProvider)
          .updateOrganizationName(orgId, _orgNameController.text.trim());
      bumpRefreshTick(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organização atualizada.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingOrg = false);
    }
  }

  Future<void> _leaveOrg(String orgId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da organização'),
        content: const Text('Tens a certeza que queres sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref
        .read(organizationsRepositoryProvider)
        .leaveOrganization(orgId);
    if (!mounted) return;

    switch (result) {
      case LeaveOrgResult.onlyAdminBlocked:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'És o único administrador. Atribui outro admin ou elimina a organização primeiro.',
            ),
          ),
        );
      case LeaveOrgResult.needsDelete:
        final confirmDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar organização'),
            content: const Text(
              'És a última pessoa. Sair significa eliminar a organização e todos os seus dados. Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        if (confirmDelete == true) {
          await ref
              .read(organizationsRepositoryProvider)
              .deleteOrganization(orgId);
          ref.read(orgStoreProvider.notifier).clear();
        }
      case LeaveOrgResult.left:
        ref.read(orgStoreProvider.notifier).clear();
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar conta'),
        content: const Text(
          'Isto elimina permanentemente a tua conta e não pode ser desfeito. Tens a certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(profileRepositoryProvider).deleteOwnAccount();
      ref.read(orgStoreProvider.notifier).clear();
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível eliminar a conta.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(orgStoreProvider);
    final isAdmin = membership?.role == MembershipRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: _profileLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Perfil', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _changeAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: _avatarUrl == null
                              ? const Icon(Icons.person_outline, size: 32)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: _uploadingAvatar
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 14,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _birthday ?? DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _birthday = picked);
                  },
                  icon: const Icon(Icons.cake_outlined),
                  label: Text(
                    _birthday != null
                        ? '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}'
                        : 'Aniversário',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _savingProfile ? null : _saveProfile,
                  child: _savingProfile
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar perfil'),
                ),
                const Divider(height: 48),
                if (membership != null) ...[
                  Text(
                    'Organização',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (isAdmin)
                    Center(
                      child: GestureDetector(
                        onTap: _uploadingLogo
                            ? null
                            : () => _changeOrgLogo(membership),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage:
                                  membership.organization.logoUrl != null
                                  ? NetworkImage(
                                      membership.organization.logoUrl!,
                                    )
                                  : null,
                              child: membership.organization.logoUrl == null
                                  ? const Icon(Icons.groups_outlined)
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: _uploadingLogo
                                    ? const SizedBox(
                                        height: 12,
                                        width: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_outlined,
                                        size: 12,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isAdmin) const SizedBox(height: 16),
                  TextField(
                    controller: _orgNameController,
                    enabled: isAdmin,
                    decoration: const InputDecoration(
                      labelText: 'Nome da organização',
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _savingOrg
                          ? null
                          : () => _saveOrgName(membership.organization.id),
                      child: _savingOrg
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar organização'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      title: Text(membership.organization.inviteCode),
                      subtitle: const Text('Código de convite'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_outlined),
                            tooltip: 'Copiar',
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: membership.organization.inviteCode,
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Código copiado.'),
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            tooltip: 'Partilhar',
                            onPressed: () => SharePlus.instance.share(
                              ShareParams(
                                text:
                                    'Entra na organização "${membership.organization.name}" no WIS!\n\n'
                                    'Usa o código: ${membership.organization.inviteCode}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 48),
                  Text(
                    'Esta organização',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _leaveOrg(membership.organization.id),
                    child: const Text('Sair da organização'),
                  ),
                  const Divider(height: 48),
                ],
                Text('Sessão', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    ref.read(orgStoreProvider.notifier).clear();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Terminar sessão'),
                ),
                const Divider(height: 48),
                Text(
                  'Zona de perigo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _deleteAccount,
                  child: const Text('Eliminar conta'),
                ),
              ],
            ),
    );
  }
}
