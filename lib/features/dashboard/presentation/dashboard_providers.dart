import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/refresh_tick.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

final dashboardSummaryProvider =
    FutureProvider.family<DashboardSummary, String>((ref, orgId) {
      ref.watch(refreshTickProvider);
      return ref.watch(dashboardRepositoryProvider).fetchSummary(orgId);
    });
