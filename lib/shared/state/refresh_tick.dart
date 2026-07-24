import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Replicates the web app's global `MutationCache` behaviour: after *any*
/// successful mutation, every screen's data reloads. Data providers that
/// want this "invalidate all on any write" behaviour should `ref.watch`
/// this provider; call [bumpRefreshTick] after a mutation succeeds.
class RefreshTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final refreshTickProvider = NotifierProvider<RefreshTick, int>(RefreshTick.new);

void bumpRefreshTick(WidgetRef ref) =>
    ref.read(refreshTickProvider.notifier).bump();

void bumpRefreshTickRef(Ref ref) =>
    ref.read(refreshTickProvider.notifier).bump();
