import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../onboarding/domain/membership_role.dart';
import '../data/availability_repository.dart';
import '../domain/unavailability_entry.dart';

final myUnavailabilityProvider =
    FutureProvider.family<List<UnavailabilityEntry>, String>((ref, orgId) {
      ref.watch(refreshTickProvider);
      return ref
          .watch(availabilityRepositoryProvider)
          .fetchMyUnavailability(orgId);
    });

final orgUnavailabilityProvider =
    FutureProvider.family<Map<String, List<UnavailabilityEntry>>, String>((
      ref,
      orgId,
    ) {
      ref.watch(refreshTickProvider);
      final membership = ref.watch(orgStoreProvider);
      final canSeeReasons =
          membership?.role == MembershipRole.admin ||
          membership?.role == MembershipRole.leader;
      return ref
          .watch(availabilityRepositoryProvider)
          .fetchOrgUnavailability(orgId, canSeeReasons: canSeeReasons);
    });
