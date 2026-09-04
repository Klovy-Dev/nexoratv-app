import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/channel.dart';
import '../../models/series.dart';
import '../../state/channels_provider.dart';
import '../../state/favorites_provider.dart';
import '../../state/tmdb_provider.dart';
import '../../state/watchlist_provider.dart';
import '../../theme.dart';
import '../../widgets/nav.dart';
import '../player/player_screen.dart';

class MediaDetailScreen extends ConsumerWidget {
  const MediaDetailScreen._({
    required this.sourceId,
    this.movie,
    this.series,
  });

  factory MediaDetailScreen.movie(
          {required String sourceId, required Channel movie}) =>
      MediaDetailScreen._(sourceId: sourceId, movie: movie);

  factory MediaDetailScreen.series(
          {required String sourceId, required Series series}) =>
      MediaDetailScreen._(sourceId: sourceId, series: series);

  final String sourceId;
  final Channel? movie;
  final Series? series;

  bool get isSeries => series != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = movie?.name ?? series!.name;
    var year = movie?.year ?? series?.year;

    final tmdb = ref
        .watch(tmdbMetaProvider((
          title: title,
          year: year,
          isSeries: isSeries,
        )))
        .value;

    final poster = tmdb?.posterUrl ?? movie?.logo ?? series?.cover;
    final backdrop =
        tmdb?.backdropUrl ?? series?.backdrop ?? movie?.logo ?? series?.cover;
    year = year ?? tmdb?.year;
    final rating = movie?.rating ?? series?.rating ?? tmdb?.rating;
    final plot = (series?.plot?.trim().isNotEmpty ?? false)
        ? series!.plot!.trim()
        : tmdb?.overview;
    final heroTag = 'poster_${sourceId}_${movie?.id ?? series!.id}';

    final favorites = ref.watch(favoritesProvider);
    final favKey = FavoriteKey.of(sourceId, movie?.id ?? series!.id);
    final isFav = favorites.contains(favKey);
    final inList = ref.watch(watchlistProvider.notifier).contains(
          sourceId,
          movie?.id ?? series!.id,
        );

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E13),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdrop != null)
                    CachedNetworkImage(imageUrl: backdrop, fit: BoxFit.cover)
                  else
                    Container(color: Theme.of(context).colorScheme.surface),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0D0E13)],
                        stops: [0.35, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -44),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 108,
                            height: 162,
                            child: poster == null
                                ? Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child:
                                        const Icon(Icons.movie_outlined))
                                : Hero(
                                    tag: heroTag,
                                    child: CachedNetworkImage(
                                        imageUrl: poster, fit: BoxFit.cover),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (year != null) _meta('$year'),
                                if (rating != null)
                                  _meta('★ ${rating.toStringAsFixed(1)}'),
                                if (series?.genre != null)
                                  _meta(series!.genre!),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w700, height: 1.2),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _play(context, ref),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(isSeries ? 'Regarder' : 'Lecture'),
                        ),
                        _iconBtn(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          isFav ? 'Retirer des favoris' : 'Favori',
                          () => ref.read(favoritesProvider.notifier).toggle(
                              sourceId, movie?.id ?? series!.id),
                          color: isFav ? nexoraPink : null,
                        ),
                        _iconBtn(
                          inList ? Icons.bookmark : Icons.bookmark_border,
                          inList ? 'Dans Ma liste' : 'Ajouter à Ma liste',
                          () async {
                            final n = ref.read(watchlistProvider.notifier);
                            if (isSeries) {
                              await n.toggleSeries(sourceId, series!);
                            } else {
                              await n.toggleMovie(sourceId, movie!);
                            }
                          },
                          color: inList ? nexoraPurple : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      (plot ?? '').trim().isNotEmpty
                          ? plot!.trim()
                          : 'Synopsis indisponible pour ce titre.',
                      style: TextStyle(
                          color: Theme.of(context).hintColor,
                          height: 1.4,
                          fontStyle: (plot ?? '').trim().isNotEmpty
                              ? FontStyle.normal
                              : FontStyle.italic),
                    ),
                    if (series?.cast != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text('Avec ${series!.cast}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor)),
                      ),
                    if (isSeries) ...[
                      const SizedBox(height: 16),
                      _EpisodesSection(sourceId: sourceId, series: series!),
                    ],
                    const SizedBox(height: 68),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _play(BuildContext context, WidgetRef ref) {
    if (!isSeries) {
      pushFade(
          context,
          PlayerScreen(
              sourceId: sourceId, playlist: [movie!], startIndex: 0));
      return;
    }
    // série : joue le 1er épisode disponible
    final eps = ref.read(episodesProvider(
        (sourceId: sourceId, seriesId: series!.seriesId)));
    final list = eps.value;
    if (list != null && list.isNotEmpty) {
      pushFade(
          context,
          PlayerScreen(
              sourceId: sourceId, playlist: list, startIndex: 0));
    }
  }

  static Widget _meta(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x24FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(s,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );

  static Widget _iconBtn(IconData icon, String tip, VoidCallback onTap,
          {Color? color}) =>
      Tooltip(
        message: tip,
        child: IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon, color: color),
        ),
      );
}

class _EpisodesSection extends ConsumerStatefulWidget {
  const _EpisodesSection({required this.sourceId, required this.series});
  final String sourceId;
  final Series series;

  @override
  ConsumerState<_EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends ConsumerState<_EpisodesSection> {
  String? _season;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(episodesProvider(
        (sourceId: widget.sourceId, seriesId: widget.series.seriesId)));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Épisodes indisponibles : $e'),
      ),
      data: (episodes) {
        if (episodes.isEmpty) return const Text('Aucun épisode.');
        final seasons = <String>{for (final e in episodes) e.groupOrDefault}
            .toList()
          ..sort();
        _season ??= seasons.first;
        final eps =
            episodes.where((e) => e.groupOrDefault == _season).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in seasons)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _season == s,
                        onSelected: (_) => setState(() => _season = s),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < eps.length; i++)
              ListTile(
                dense: true,
                leading: const Icon(Icons.play_circle_outline),
                title: Text(eps[i].name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => pushFade(
                  context,
                  PlayerScreen(
                    sourceId: widget.sourceId,
                    playlist: eps,
                    startIndex: i,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
