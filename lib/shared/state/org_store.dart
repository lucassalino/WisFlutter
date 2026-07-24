import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/onboarding/domain/organization.dart';
import '../../features/onboarding/data/organizations_repository.dart';
import 'refresh_tick.dart';

const _lastOrgIdPrefsKey = 'wis_last_org_id';

/// Equivalente ao `orgStore` (Zustand) da app web: guarda a organização
/// ativa e o cargo do utilizador nela, e lembra a última organização
/// visitada entre sessões.
class OrgStore extends Notifier<OrganizationMembership?> {
  @override
  OrganizationMembership? build() => null;

  Future<void> setActive(OrganizationMembership membership) async {
    state = membership;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOrgIdPrefsKey, membership.organization.id);
  }

  void clear() {
    state = null;
  }

  static Future<String?> readLastOrgId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOrgIdPrefsKey);
  }
}

final orgStoreProvider = NotifierProvider<OrgStore, OrganizationMembership?>(
  OrgStore.new,
);

/// Todas as organizações do utilizador autenticado. Recarrega sempre que
/// [refreshTickProvider] muda (ex.: depois de criar/entrar numa organização).
final myMembershipsProvider = FutureProvider<List<OrganizationMembership>>((
  ref,
) async {
  ref.watch(refreshTickProvider);
  final repo = ref.watch(organizationsRepositoryProvider);
  return repo.fetchMyMemberships();
});
