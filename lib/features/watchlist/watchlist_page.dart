import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/channel.dart';
import '../../models/series.dart';
import '../../state/channels_provider.dart';
import '../../state/sources_provider.dart';
import '../../state/watchlist_provider.dart';
import '../../widgets/nav.dart';
import '../catalog/poster_card.dart';
import '../detail/media_detail_screen.dart';
import '../player/player_screen.dart';

class WatchlistPage extends ConsumerWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(watchlistProvider).value ?? const [];
    final sourceId = ref.watch(selectedSourceProvider)?.id;
    final mine = items.where((e) => e.sourceId == sourceId).toList();

    if (mine.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border, size: 56),
              SizedBox(height: 12),
              Text('Ta liste est vide.'),
              SizedBox(height: 4),
              Text('Ajoute des films et séries depuis leur fiche.',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final series = ref.watch(currentPlaylistProvider)?.value?.series ?? const [];

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: PosterCard.gridDelegate,
      itemCount: mine.length,
      itemBuilder: (context, i) {
        final it = mine[i];
        return PosterCard(
          title: it.name,
          imageUrl: it.logo,
          heroTag: 'poster_${it.sourceId}_${it.id}',
          badge: it.kind == MediaKind.series ? 'Série' : null,
          onSecondary: () =>
              ref.read(watchlistProvider.notifier).removeKey(it.sourceId, it.id),
          secondaryIcon: Icons.close,
          onPlay: it.kind == MediaKind.movie
              ? () => pushFade(
                    context,
                    PlayerScreen(
                      sourceId: it.sourceId,
                      playlist: [it.toChannel()],
                      startIndex: 0,
                    ),
                  )
              : null,
          onTap: () {
            if (it.kind == MediaKind.series) {
              final s = series.firstWhere(
                (x) => x.id == it.id,
                orElse: () => Series(
                    id: it.id,
                    seriesId: it.seriesId ?? '',
                    name: it.name,
                    cover: it.logo),
              );
              pushFade(context,
                  MediaDetailScreen.series(sourceId: it.sourceId, series: s));
            } else {
              pushFade(
                context,
                MediaDetailScreen.movie(
                    sourceId: it.sourceId, movie: it.toChannel()),
              );
            }
          },
        );
      },
    );
  }
}
