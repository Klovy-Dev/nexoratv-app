import 'dart:async';

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
import '../../widgets/tv_focusable.dart';
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

    final recentMovies = playlist.recentMovies(14);
    final recentSeries = playlist.recentSeries(10);
    final featured = _featuredItems(
      recentMovies,
      playlist.movies,
      recentSeries,
      playlist.series,
    );

    return ListView(
      children: [
        if (featured.isNotEmpty)
          _FeaturedHero(items: featured, sourceId: sourceId),
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
        for (final g in playlist.topMovieGroups(4))
          Builder(builder: (context) {
            final items = playlist.moviesInGroup(g).take(14).toList();
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

  /// Films **et** séries mis en avant dans le bandeau qui défile : ceux qui
  /// ont une affiche et une note correcte, en priorité les récents,
  /// interclassés film/série. Limité à 8 (une seule image en mémoire à la
  /// fois côté bandeau — léger pour Fire TV Stick).
  List<_Featured> _featuredItems(
    List<Channel> recentMovies,
    List<Channel> allMovies,
    List<Series> recentSeries,
    List<Series> allSeries,
  ) {
    List<T> pick<T>(
      List<T> recent,
      List<T> all,
      bool Function(T) good,
      String Function(T) id,
    ) {
      final seen = <String>{};
      final out = <T>[];
      for (final e in [...recent, ...all]) {
        if (good(e) && seen.add(id(e))) out.add(e);
        if (out.length >= 5) break;
      }
      if (out.isEmpty) {
        for (final e in [...recent, ...all]) {
          if (seen.add(id(e))) out.add(e);
          if (out.length >= 5) break;
        }
      }
      return out;
    }

    final movies = pick<Channel>(
      recentMovies,
      allMovies,
      (m) => (m.logo?.isNotEmpty ?? false) && (m.rating ?? 0) >= 6,
      (m) => m.id,
    );
    final series = pick<Series>(
      recentSeries,
      allSeries,
      (s) => (s.cover?.isNotEmpty ?? false) && (s.rating ?? 0) >= 6,
      (s) => s.id,
    );

    final out = <_Featured>[];
    for (var i = 0; out.length < 8 && (i < movies.length || i < series.length); i++) {
      if (i < movies.length) out.add(_Featured.movie(movies[i]));
      if (out.length < 8 && i < series.length) out.add(_Featured.series(series[i]));
    }
    return out;
  }
}

/// Un élément du bandeau d'accueil : un film ou une série.
class _Featured {
  const _Featured.movie(Channel this.movie) : series = null;
  const _Featured.series(Series this.series) : movie = null;

  final Channel? movie;
  final Series? series;

  bool get isSeries => series != null;
  String get name => movie?.name ?? series!.name;
  String? get image => movie?.logo ?? series!.cover;
  int? get year => movie?.year ?? series!.year;
  double? get rating => movie?.rating ?? series!.rating;
  String get id => movie?.id ?? series!.id;
}

/// Bandeau d'accueil : les films et séries mis en avant défilent (fondu
/// enchaîné toutes les 20 s). Une seule affiche est décodée à la fois —
/// pensé pour les appareils pauvres en RAM (Fire TV Stick).
class _FeaturedHero extends StatefulWidget {
  const _FeaturedHero({required this.items, required this.sourceId});
  final List<_Featured> items;
  final String sourceId;

  @override
  State<_FeaturedHero> createState() => _FeaturedHeroState();
}

class _FeaturedHeroState extends State<_FeaturedHero> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) setState(() => _i = (_i + 1) % widget.items.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _open(_Featured item) => pushFade(
        context,
        item.isSeries
            ? MediaDetailScreen.series(
                sourceId: widget.sourceId, series: item.series!)
            : MediaDetailScreen.movie(
                sourceId: widget.sourceId, movie: item.movie!),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final height = wide ? 340.0 : 260.0;
    final item = widget.items[_i.clamp(0, widget.items.length - 1)];

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            key: ValueKey(item.id),
            imageUrl: item.image ?? '',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            memCacheWidth: 480,
            fadeInDuration: const Duration(milliseconds: 250),
            placeholder: (_, _) =>
                Container(color: scheme.surfaceContainerHighest),
            errorWidget: (_, _, _) =>
                Container(color: scheme.surfaceContainerHighest),
          ),
          // Voiles pour la lisibilité du texte.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xE6000000), Color(0x22000000)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, scheme.surface],
                stops: const [0.45, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 0, 20, wide ? 26 : 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.isSeries ? 'SÉRIE' : 'FILM',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                        ),
                      ),
                    ),
                    if (item.year != null) ...[
                      const SizedBox(width: 10),
                      Text('${item.year}',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                    if (item.rating != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(item.rating!.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: wide ? 30 : 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton.icon(
                      autofocus: true,
                      onPressed: () {
                        if (item.isSeries) {
                          _open(item);
                        } else {
                          pushFade(
                            context,
                            PlayerScreen(
                              sourceId: widget.sourceId,
                              playlist: [item.movie!],
                              startIndex: 0,
                            ),
                          );
                        }
                      },
                      icon: Icon(
                          item.isSeries ? Icons.visibility : Icons.play_arrow),
                      label: Text(item.isSeries ? 'Voir' : 'Lecture'),
                    ),
                    if (!item.isSeries) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _open(item),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Infos'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var j = 0; j < widget.items.length; j++)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: j == _i ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: j == _i
                              ? Colors.white
                              : Colors.white.withValues(alpha: .4),
                          borderRadius: BorderRadius.circular(3),
                        ),
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
    // `.select` : ce poster ne se reconstruit que si SA progression change,
    // pas à chaque écriture dans l'historique (sinon toute la grille repeint).
    final progress = ref.watch(watchHistoryProvider.select((async) {
      for (final e in async.value ?? const []) {
        if (e.key == '$sourceId::${movie.id}') return e.progress;
      }
      return 0.0;
    }));
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
    return TvFocusable(
      onTap: onTap,
      builder: (context, focused, hovered) => Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: tvFocusBorder(context, focused),
              ),
              padding: const EdgeInsets.all(14),
              child: channel.logo == null
                  ? const Icon(Icons.live_tv)
                  : CachedNetworkImage(
                      imageUrl: channel.logo!,
                      fit: BoxFit.contain,
                      memCacheWidth: 200,
                    ),
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
