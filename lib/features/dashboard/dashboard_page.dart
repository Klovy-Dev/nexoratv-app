import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/channel.dart';
import '../../models/series.dart';
import '../../services/playlist_service.dart';
import '../../state/channels_provider.dart';
import '../../state/favorites_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/sources_provider.dart';
import '../../state/watch_history_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/nav.dart';
import '../catalog/poster_card.dart';
import '../detail/media_detail_screen.dart';
import '../player/player_screen.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, required this.onNavigate});
  final void Function(int tabIndex) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pl = ref.watch(currentPlaylistProvider);
    final source = ref.watch(selectedSourceProvider);

    return switch (pl) {
      null => const _NoSource(),
      AsyncError(:final error) => _Error(message: '$error'),
      AsyncLoading() => const LoadingView(label: 'Chargement du catalogue…'),
      AsyncData(:final value) =>
        _Dashboard(playlist: value, sourceId: source!.id, onNavigate: onNavigate),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({
    required this.playlist,
    required this.sourceId,
    required this.onNavigate,
  });
  final LoadedPlaylist playlist;
  final String sourceId;
  final void Function(int) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resume = ref
        .watch(continueWatchingProvider)
        .where((e) => e.sourceId == sourceId)
        .take(16)
        .toList();
    final watched = ref.watch(
            settingsValueProvider.select((s) => s.showWatchedRow))
        ? ref
            .watch(watchedProvider)
            .where((e) => e.sourceId == sourceId)
            .take(16)
            .toList()
        : const [];
    final favKeys = ref.watch(favoritesProvider);
    final favChannels = playlist.live
        .where((c) => favKeys.contains(FavoriteKey.of(sourceId, c.id)))
        .take(18)
        .toList();

    final recentMovies = playlist.recentMovies(20);
    final recentSeries = playlist.recentSeries(12);
    final hero = _pickHero(recentMovies, playlist.movies);

    return ListView(
      children: [
        if (hero != null)
          _Hero(
            movie: hero,
            sourceId: sourceId,
          ),
        if (resume.isNotEmpty)
          _Rail(
            title: 'Reprendre',
            children: [
              for (final e in resume)
                _MiniPoster(
                  title: e.name,
                  image: e.logo,
                  progress: e.progress,
                  onTap: () => pushFade(
                    context,
                    PlayerScreen(
                      sourceId: sourceId,
                      playlist: [e.toChannel()],
                      startIndex: 0,
                    ),
                  ),
                ),
            ],
          ),
        if (watched.isNotEmpty)
          _Rail(
            title: 'Revoir',
            children: [
              for (final e in watched)
                _MiniPoster(
                  title: e.name,
                  image: e.logo,
                  onTap: () => pushFade(
                    context,
                    PlayerScreen(
                      sourceId: sourceId,
                      playlist: [e.toChannel()],
                      startIndex: 0,
                    ),
                  ),
                ),
            ],
          ),
        if (recentMovies.isNotEmpty)
          _Rail(
            title: 'Films ajoutés récemment',
            onSeeAll: () => onNavigate(2),
            children: [
              for (final m in recentMovies)
                _MoviePoster(sourceId: sourceId, movie: m),
            ],
          ),
        if (recentSeries.isNotEmpty)
          _Rail(
            title: 'Nouvelles séries',
            onSeeAll: () => onNavigate(3),
            children: [
              for (final s in recentSeries)
                _SeriesPoster(sourceId: sourceId, series: s),
            ],
          ),
        if (favChannels.isNotEmpty)
          _Rail(
            title: 'Chaînes favorites',
            onSeeAll: () => onNavigate(1),
            children: [
              for (final c in favChannels)
                _ChannelPoster(
                  channel: c,
                  onTap: () => pushFade(
                    context,
                    PlayerScreen(
                      sourceId: sourceId,
                      playlist: favChannels,
                      startIndex: favChannels.indexOf(c),
                    ),
                  ),
                ),
            ],
          ),
        for (final g in playlist.topMovieGroups(6))
          Builder(builder: (context) {
            final items = playlist.moviesInGroup(g).take(20).toList();
            if (items.isEmpty) return const SizedBox.shrink();
            return _Rail(
              title: prettyCategory(g),
              children: [
                for (final m in items)
                  _MoviePoster(sourceId: sourceId, movie: m),
              ],
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }

  Channel? _pickHero(List<Channel> recent, List<Channel> all) {
    final pool = recent.isNotEmpty ? recent : all;
    final rated = pool.where((m) => (m.rating ?? 0) >= 6 && m.logo != null).toList();
    final source = rated.isNotEmpty ? rated : pool.where((m) => m.logo != null).toList();
    if (source.isEmpty) return null;
    return source[Random(DateTime.now().day).nextInt(source.length)];
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.movie, required this.sourceId});
  final Channel movie;
  final String sourceId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (movie.logo != null)
            CachedNetworkImage(imageUrl: movie.logo!, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xEE0D0E13), Color(0x330D0E13)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF0D0E13)],
                stops: [0.4, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    movie.name,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (movie.year != null)
                      Text('${movie.year}',
                          style: TextStyle(color: Theme.of(context).hintColor)),
                    if (movie.rating != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(movie.rating!.toStringAsFixed(1)),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => pushFade(
                        context,
                        PlayerScreen(
                          sourceId: sourceId,
                          playlist: [movie],
                          startIndex: 0,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Lecture'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => pushFade(
                        context,
                        MediaDetailScreen.movie(
                            sourceId: sourceId, movie: movie),
                      ),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Infos'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.title,
    required this.children,
    this.onSeeAll,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                if (onSeeAll != null)
                  TextButton(
                      onPressed: onSeeAll, child: const Text('Voir tout')),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) =>
                  SizedBox(width: 120, child: children[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoviePoster extends ConsumerWidget {
  const _MoviePoster({required this.sourceId, required this.movie});
  final String sourceId;
  final Channel movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = () {
      for (final e in ref.watch(watchHistoryProvider).value ?? const []) {
        if (e.key == '$sourceId::${movie.id}') return e.progress;
      }
      return 0.0;
    }();
    return PosterCard(
      title: movie.name,
      imageUrl: movie.logo,
      year: movie.year,
      rating: movie.rating,
      progress: progress,
      heroTag: 'poster_${sourceId}_${movie.id}',
      onTap: () => pushFade(context,
          MediaDetailScreen.movie(sourceId: sourceId, movie: movie)),
      onPlay: () => pushFade(
        context,
        PlayerScreen(sourceId: sourceId, playlist: [movie], startIndex: 0),
      ),
    );
  }
}

class _SeriesPoster extends StatelessWidget {
  const _SeriesPoster({required this.sourceId, required this.series});
  final String sourceId;
  final Series series;

  @override
  Widget build(BuildContext context) => PosterCard(
        title: series.name,
        imageUrl: series.cover,
        year: series.year,
        rating: series.rating,
        heroTag: 'poster_${sourceId}_${series.id}',
        onTap: () => pushFade(context,
            MediaDetailScreen.series(sourceId: sourceId, series: series)),
      );
}

class _ChannelPoster extends StatelessWidget {
  const _ChannelPoster({required this.channel, required this.onTap});
  final Channel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
              child: channel.logo == null
                  ? const Icon(Icons.live_tv)
                  : CachedNetworkImage(
                      imageUrl: channel.logo!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 6),
          Text(channel.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _MiniPoster extends StatelessWidget {
  const _MiniPoster({
    required this.title,
    required this.onTap,
    this.image,
    this.progress = 0,
  });
  final String title;
  final String? image;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PosterCard(
        title: title,
        imageUrl: image,
        progress: progress,
        onTap: onTap,
        onPlay: onTap,
      );
}

class _NoSource extends StatelessWidget {
  const _NoSource();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Aucune source sélectionnée.'));
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 44, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
