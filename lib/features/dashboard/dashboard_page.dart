import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../brand.dart';
import '../../models/channel.dart';
import '../../models/series.dart';
import '../../services/avis_service.dart';
import '../../services/playlist_service.dart';
import '../../state/avis_provider.dart';
import '../../state/channels_provider.dart';
import '../../state/favorites_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/sources_provider.dart';
import '../../state/watch_history_provider.dart';
import '../../theme.dart';
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

    return ListView(
      children: [
        const _InfoPanel(),
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

}

/// Bandeau d'accueil : identité NexoraTV + accès rapides (site, réseaux,
/// support + avis clients). Remplace l'ancien « film en avant ».
class _InfoPanel extends ConsumerWidget {
  const _InfoPanel();

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avis = ref.watch(avisProvider).valueOrNull ?? Avis.empty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: nexoraGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icon/nexora_logo.png', width: 44, height: 44),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NexoraTV',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text('Votre univers TV, films et séries',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              if (avis.count > 0) _RatingBadge(avis: avis),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _LinkButton(
                icon: Icons.language,
                label: 'Site officiel',
                onTap: () => _open(Brand.site),
              ),
              _LinkButton(
                icon: Icons.chat_bubble_outline,
                label: 'WhatsApp',
                onTap: () => _open(Brand.whatsapp),
              ),
              _LinkButton(
                icon: Icons.send,
                label: 'Telegram',
                onTap: () => _open(Brand.telegram),
              ),
              _LinkButton(
                icon: Icons.support_agent,
                label: 'Support',
                onTap: () => _open(Brand.contact),
              ),
            ],
          ),
          if (avis.reviews.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Avis clients',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const Spacer(),
                _LinkButton(
                  icon: Icons.reviews_outlined,
                  label: 'Tous les avis',
                  onTap: () => _open(Brand.avis),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: avis.reviews.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _ReviewCard(review: avis.reviews[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.avis});
  final Avis avis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 3),
              Text(
                avis.average.toStringAsFixed(1).replaceAll('.', ','),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
            ],
          ),
          Text('${avis.count} avis',
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('★' * review.rating + '☆' * (5 - review.rating),
                  style: const TextStyle(color: Colors.amber, fontSize: 11)),
              const Spacer(),
              Text(review.author,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              review.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5,
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
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
