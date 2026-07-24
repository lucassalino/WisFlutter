import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/refresh_tick.dart';
import '../data/songs_repository.dart';
import '../domain/song.dart';

final songsListProvider = FutureProvider.family<List<Song>, String>((
  ref,
  orgId,
) {
  ref.watch(refreshTickProvider);
  return ref.watch(songsRepositoryProvider).fetchSongs(orgId);
});

final songsRankingProvider =
    FutureProvider.family<List<SongRankingEntry>, String>((ref, orgId) {
      ref.watch(refreshTickProvider);
      return ref.watch(songsRepositoryProvider).fetchSongsRanking(orgId);
    });
