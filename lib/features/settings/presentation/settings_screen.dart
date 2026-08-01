import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/data/storage_repository.dart';
import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/image_picker_helper.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../auth/data/auth_repository.dart';
import '../../members/data/members_repository.dart';
import '../../members/domain/org_member.dart';
import '../../members/presentation/members_providers.dart';
import '../../ministries/data/ministries_repository.dart';
import '../../ministries/presentation/ministries_providers.dart';
import '../../onboarding/data/organizations_repository.dart';
import '../../onboarding/domain/membership_role.dart';
import '../../onboarding/domain/organization.dart';
import '../../profile/data/profile_repository.dart';

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

final _ghostButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: Colors.white.withValues(alpha: 0.06),
  foregroundColor: Colors.white.withValues(alpha: 0.75),
  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

final _dangerButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: const Color(0xFFF87171).withValues(alpha: 0.08),
  foregroundColor: const Color(0xFFF87171),
  side: BorderSide(color: const Color(0xFFF87171).withValues(alpha: 0.2)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

final _dangerFilledButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: const Color(0xFFF87171).withValues(alpha: 0.15),
  foregroundColor: const Color(0xFFFCA5A5),
  side: BorderSide(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

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
  bool _transferringAdmin = false;
  bool _deletingOrg = false;

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
          bumpRefreshTick(ref);
          _popToRoot();
        }
      case LeaveOrgResult.left:
        ref.read(orgStoreProvider.notifier).clear();
        bumpRefreshTick(ref);
        _popToRoot();
    }
  }

  /// O ecrã de Definições é normalmente alcançado com `Navigator.push`
  /// (não é uma rota do go_router), por isso fica por cima da própria
  /// árvore do go_router. Quando uma ação sai da organização/conta atual,
  /// o go_router já redireciona a rota de baixo (ex.: para
  /// `/org-selection`), mas essa rota fica escondida atrás deste ecrã até
  /// ser explicitamente fechado.
  void _popToRoot() {
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _transferAdmin(OrganizationMembership membership) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final members = await ref
        .read(membersRepositoryProvider)
        .fetchMembers(membership.organization.id);
    final candidates = members
        .where((m) => m.isActive && m.userId != currentUserId)
        .toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não há mais ninguém nesta organização para transferir a administração.',
          ),
        ),
      );
      return;
    }

    final target = await showDialog<OrgMember>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Transferir administração'),
        children: [
          for (final member in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(member),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: member.avatarUrl != null
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                    child: member.avatarUrl == null
                        ? const Icon(Icons.person_outline, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(member.fullName)),
                ],
              ),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transferir administração'),
        content: Text(
          'Vais transferir a administração para ${target.fullName}. '
          'Tu passas a líder e ${target.fullName} passa a administrador(a). Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _transferringAdmin = true);
    try {
      final repo = ref.read(membersRepositoryProvider);
      await repo.updateMemberRole(target.membershipId, MembershipRole.admin);
      await repo.updateMemberRole(
        membership.membershipId,
        MembershipRole.leader,
      );
      ref
          .read(orgStoreProvider.notifier)
          .setActive(
            OrganizationMembership(
              organization: membership.organization,
              membershipId: membership.membershipId,
              role: MembershipRole.leader,
              isActive: membership.isActive,
            ),
          );
      bumpRefreshTick(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Administração transferida para ${target.fullName}.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível transferir a administração.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _transferringAdmin = false);
    }
  }

  Future<void> _deleteOrganizationDirect(
    OrganizationMembership membership,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar organização'),
        content: Text(
          'Vais eliminar permanentemente "${membership.organization.name}" e todos os '
          'seus dados — eventos, escalas, ministérios, músicas e convites. As pessoas '
          'são removidas da organização, mas as contas delas mantêm-se. Esta ação não '
          'pode ser desfeita. Tens a certeza?',
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

    setState(() => _deletingOrg = true);
    try {
      await ref
          .read(organizationsRepositoryProvider)
          .deleteOrganization(membership.organization.id);
      ref.read(orgStoreProvider.notifier).clear();
      bumpRefreshTick(ref);
      _popToRoot();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível eliminar a organização.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingOrg = false);
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
      bumpRefreshTick(ref);
      await ref.read(authRepositoryProvider).signOut();
      _popToRoot();
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SpotlightBackground(
        child: SafeArea(
          child: _profileLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Text(
                      'CONTA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Definições',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Perfil e preferências da conta',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    _SettingsSection(
                      title: 'Perfil',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _uploadingAvatar ? null : _changeAvatar,
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundImage: _avatarUrl != null
                                          ? NetworkImage(_avatarUrl!)
                                          : null,
                                      child: _avatarUrl == null
                                          ? const Icon(Icons.person_outline, size: 28)
                                          : null,
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E24),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                                        ),
                                        child: _uploadingAvatar
                                            ? const SizedBox(
                                                height: 12,
                                                width: 12,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : Icon(Icons.camera_alt_outlined,
                                                size: 12, color: Colors.white.withValues(alpha: 0.7)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _uploadingAvatar
                                      ? 'A enviar foto…'
                                      : 'Clica na foto para a alterar. JPEG, PNG ou WebP, até 2MB.',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.38), height: 1.5),
                                ),
                              ),
                            ],
                          ),
                          const _SectionDivider(),
                          TextField(
                            enabled: false,
                            controller: TextEditingController(
                              text: Supabase.instance.client.auth.currentUser?.email ?? '',
                            ),
                            decoration: const InputDecoration(labelText: 'Email'),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Nome completo'),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Telemóvel',
                              hintText: '+351 900 000 000',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _birthday ?? DateTime(2000),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _birthday = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Data de aniversário'),
                              child: Text(
                                _birthday != null
                                    ? '${_birthday!.day.toString().padLeft(2, '0')}/${_birthday!.month.toString().padLeft(2, '0')}/${_birthday!.year}'
                                    : 'Selecionar',
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aparece nos aniversariantes do mês no painel da organização.',
                            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: _primaryButtonStyle,
                            onPressed: _savingProfile ? null : _saveProfile,
                            child: _savingProfile
                                ? const SizedBox(
                                    height: 12,
                                    width: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Text('Guardar perfil'),
                          ),
                        ],
                      ),
                    ),
                    if (membership != null) ...[
                      const SizedBox(height: 16),
                      _MinistriesAndFunctionsCard(
                        orgId: membership.organization.id,
                        userId: Supabase.instance.client.auth.currentUser!.id,
                      ),
                    ],
                    if (membership != null && isAdmin) ...[
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'Organização',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _orgNameController,
                              decoration: const InputDecoration(labelText: 'Nome da organização'),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Logótipo',
                              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: membership.organization.logoUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(11),
                                          child: Image.network(
                                            membership.organization.logoUrl!,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Text(
                                          membership.organization.name.isNotEmpty
                                              ? membership.organization.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  style: _ghostButtonStyle,
                                  onPressed: _uploadingLogo ? null : () => _changeOrgLogo(membership),
                                  icon: _uploadingLogo
                                      ? const SizedBox(
                                          height: 12,
                                          width: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.add_photo_alternate_outlined, size: 14),
                                  label: Text(_uploadingLogo ? 'A enviar…' : 'Carregar imagem'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'JPEG, PNG ou WebP, até 2MB.',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            const _SectionDivider(),
                            Text(
                              'Código de convite',
                              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                membership.organization.inviteCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: _ghostButtonStyle,
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: membership.organization.inviteCode),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Código copiado.')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.copy_outlined, size: 14),
                                    label: const Text('Copiar'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: _ghostButtonStyle,
                                    onPressed: () => SharePlus.instance.share(
                                      ShareParams(
                                        text:
                                            'Entra na organização "${membership.organization.name}" no WIS!\n\n'
                                            'Usa o código: ${membership.organization.inviteCode}',
                                      ),
                                    ),
                                    icon: const Icon(Icons.ios_share, size: 14),
                                    label: const Text('Partilhar'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Partilha este código para convidar pessoas',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: _primaryButtonStyle,
                              onPressed: _savingOrg
                                  ? null
                                  : () => _saveOrgName(membership.organization.id),
                              child: _savingOrg
                                  ? const SizedBox(
                                      height: 12,
                                      width: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Text('Guardar organização'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'Sessão',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Termina a sessão neste dispositivo. Podes voltar a entrar com o teu email e password.',
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            style: _ghostButtonStyle,
                            onPressed: () async {
                              await ref.read(authRepositoryProvider).signOut();
                              ref.read(orgStoreProvider.notifier).clear();
                              bumpRefreshTick(ref);
                              _popToRoot();
                            },
                            icon: const Icon(Icons.logout, size: 14),
                            label: const Text('Terminar sessão'),
                          ),
                        ],
                      ),
                    ),
                    if (membership != null) ...[
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'Esta organização',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isAdmin) ...[
                              Text(
                                'Só pode existir um administrador por organização. Passa o cargo a outra pessoa — '
                                'tu passas a líder e ela passa a administradora.',
                                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), height: 1.5),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                style: _ghostButtonStyle,
                                onPressed: _transferringAdmin
                                    ? null
                                    : () => _transferAdmin(membership),
                                icon: _transferringAdmin
                                    ? const SizedBox(
                                        height: 12,
                                        width: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.swap_horiz, size: 14),
                                label: Text(
                                  _transferringAdmin
                                      ? 'A transferir…'
                                      : 'Transferir administração',
                                ),
                              ),
                              const _SectionDivider(),
                            ],
                            Text(
                              'Deixa de pertencer a ${membership.organization.name}. Podes voltar a entrar mais tarde com o código de convite.',
                              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), height: 1.5),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              style: _dangerButtonStyle,
                              onPressed: () => _leaveOrg(membership.organization.id),
                              icon: const Icon(Icons.logout, size: 14),
                              label: const Text('Sair da organização'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'Zona de perigo',
                      danger: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (membership != null && isAdmin) ...[
                            Text(
                              'Elimina permanentemente esta organização e todos os seus dados — eventos, '
                              'escalas, ministérios, músicas e convites. As pessoas são removidas da '
                              'organização, mas as contas delas mantêm-se. Esta ação não pode ser desfeita.',
                              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), height: 1.5),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              style: _dangerFilledButtonStyle,
                              onPressed: _deletingOrg
                                  ? null
                                  : () => _deleteOrganizationDirect(membership),
                              icon: _deletingOrg
                                  ? const SizedBox(
                                      height: 12,
                                      width: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.delete_forever_outlined, size: 14),
                              label: Text(
                                _deletingOrg
                                    ? 'A eliminar…'
                                    : 'Eliminar organização',
                              ),
                            ),
                            const _SectionDivider(),
                          ],
                          Text(
                            'Elimina permanentemente a tua conta e todos os dados associados — perfil, '
                            'participação em organizações, escalas e notificações. Esta ação não pode ser desfeita.',
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            style: _dangerFilledButtonStyle,
                            onPressed: _deleteAccount,
                            icon: const Icon(Icons.delete_outline, size: 14),
                            label: const Text('Eliminar conta'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.danger = false,
  });

  final String title;
  final Widget child;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final borderColor = danger ? const Color(0x38F87171) : const Color(0x14FFFFFF);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD9161619),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: danger ? const Color(0x1FF87171) : Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: danger ? const Color(0xFFF87171) : Colors.white,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white.withValues(alpha: 0.07),
    );
  }
}

/// Card de autoatribuição: cada pessoa escolhe em que ministérios serve e
/// as suas funções em cada um — perspectiva "por pessoa", tal como
/// [MemberMinistriesScreen], mas embutida nas Definições e a atuar sobre a
/// própria conta em vez de um `userId` escolhido por um admin.
class _MinistriesAndFunctionsCard extends ConsumerStatefulWidget {
  const _MinistriesAndFunctionsCard({
    required this.orgId,
    required this.userId,
  });

  final String orgId;
  final String userId;

  @override
  ConsumerState<_MinistriesAndFunctionsCard> createState() =>
      _MinistriesAndFunctionsCardState();
}

class _MinistriesAndFunctionsCardState
    extends ConsumerState<_MinistriesAndFunctionsCard> {
  Map<String, Set<String>>? _selection;
  Set<String>? _initialIds;
  bool _saving = false;

  void _ensureInitialized(
    List<({String ministryId, List<String> functions})> assignments,
  ) {
    if (_selection != null) return;
    _selection = {
      for (final a in assignments) a.ministryId: {...a.functions},
    };
    _initialIds = _selection!.keys.toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(ministriesRepositoryProvider);
    try {
      final finalIds = _selection!.keys.toSet();
      final removed = _initialIds!.difference(finalIds);
      for (final ministryId in removed) {
        await repo.removeMemberFromMinistry(ministryId, widget.userId);
      }
      for (final entry in _selection!.entries) {
        await repo.setMemberFunctions(
          entry.key,
          widget.userId,
          entry.value.toList(),
        );
      }
      _initialIds = finalIds;
      bumpRefreshTick(ref);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ministérios atualizados.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));
    final assignmentsAsync = ref.watch(memberMinistriesProvider(widget.userId));

    return _SettingsSection(
      title: 'Os meus ministérios e funções',
      child: ministriesAsync.when(
        data: (ministries) => assignmentsAsync.when(
          data: (assignments) {
            _ensureInitialized(assignments);
            final active = ministries.where((m) => m.isActive).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escolhe os ministérios em que serves e as tuas funções em cada um.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ministry in active)
                      _TogglePill(
                        label: '${ministry.icon} ${ministry.name}',
                        selected: _selection!.containsKey(ministry.id),
                        onTap: () => setState(() {
                          if (_selection!.containsKey(ministry.id)) {
                            _selection!.remove(ministry.id);
                          } else {
                            _selection![ministry.id] = {};
                          }
                        }),
                      ),
                  ],
                ),
                for (final ministry in active)
                  if (_selection!.containsKey(ministry.id) &&
                      ministry.functions.isNotEmpty) ...[
                    const _SectionDivider(),
                    Text(
                      '${ministry.name} — funções',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final key in ministry.functions)
                          _TogglePill(
                            label: '${functionEmoji(key)} ${functionLabel(key)}',
                            selected: _selection![ministry.id]!.contains(key),
                            selectedColor: const Color(0xFF6EE7B7),
                            onTap: () => setState(() {
                              if (_selection![ministry.id]!.contains(key)) {
                                _selection![ministry.id]!.remove(key);
                              } else {
                                _selection![ministry.id]!.add(key);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                const SizedBox(height: 16),
                ElevatedButton(
                  style: _primaryButtonStyle,
                  onPressed: _saving || _selection == null ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              Text('Erro: $error', style: const TextStyle(color: Colors.white70)),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) =>
            Text('Erro: $error', style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = const Color(0xFFA5B4FC),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 13, color: selectedColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? selectedColor : Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
