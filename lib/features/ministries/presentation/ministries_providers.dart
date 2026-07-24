import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/refresh_tick.dart';
import '../data/ministries_repository.dart';
import '../domain/ministry.dart';
import '../domain/ministry_member.dart';

final ministriesListProvider = FutureProvider.family<List<Ministry>, String>((
  ref,
  orgId,
) {
  ref.watch(refreshTickProvider);
  return ref.watch(ministriesRepositoryProvider).fetchMinistries(orgId);
});

final ministryMembersProvider =
    FutureProvider.family<List<MinistryMember>, String>((ref, ministryId) {
      ref.watch(refreshTickProvider);
      return ref
          .watch(ministriesRepositoryProvider)
          .fetchMinistryMembers(ministryId);
    });
