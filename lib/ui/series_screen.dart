import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'catalog.dart';
import 'player.dart';
import 'theme.dart';
import 'widgets.dart';

class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(seriesCategoriesProvider).value ?? const <Category>[];
    return ref
        .watch(seriesProvider)
        .when(
          loading: () => const LoadingView(label: 'Chargement des séries…'),
          error: (e, _) => MessageView(
            icon: Icons.wifi_off_rounded,
            title: 'Séries indisponibles',
            message: errorText(e),
            action: FilledButton(
              onPressed: () => ref.invalidate(seriesProvider),
              child: const Text('Réessayer'),
            ),
          ),
          data: (series) {
            if (series.isEmpty) {
              return const MessageView(
                icon: Icons.video_library_outlined,
                title: 'Aucune série',
                message: 'Cette source ne propose pas de séries.',
              );
            }
            final byId = {for (final s in series) s.id: s};
            return PosterCatalog(
              title: 'Séries',
              searchHint: 'Rechercher une série',
              categories: categories,
              items: [
                for (final s in series)
                  PosterItem(
                    id: s.id,
                    title: s.name,
                    categoryId: s.categoryId,
                    image: s.cover,
                    subtitle: s.year,
                    rating: s.rating,
                  ),
              ],
              onOpen: (item) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SeriesDetailPage(series: byId[item.id]!),
                ),
              ),
            );
          },
        );
  }
}

class SeriesDetailPage extends ConsumerStatefulWidget {
  const SeriesDetailPage({super.key, required this.series});

  final Series series;

  @override
  ConsumerState<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends ConsumerState<SeriesDetailPage> {
  late Future<List<Season>> _seasons = _load();
  int _seasonIndex = 0;

  Future<List<Season>> _load() async {
    final content = ref.read(contentProvider);
    if (content == null) return const [];
    return content.seasons(widget.series);
  }

  void _play(List<Episode> episodes, int index) => PlayerPage.open(context, [
    for (final e in episodes)
      PlayItem(
        '${widget.series.name} — S${e.season} E${e.number} · ${e.title}',
        e.url,
      ),
  ], index: index);

  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    return Scaffold(
      body: FutureBuilder<List<Season>>(
        future: _seasons,
        builder: (context, snap) {
          final seasons = snap.data ?? const <Season>[];
          final season = seasons.isEmpty
              ? null
              : seasons[_seasonIndex.clamp(0, seasons.length - 1)];
          final firstEpisodes = seasons.isEmpty ? null : seasons.first.episodes;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: DetailHeader(
                  title: s.name,
                  image: s.cover,
                  meta: [
                    if (s.year != null) s.year!,
                    if (seasons.isNotEmpty)
                      '${seasons.length} saison${seasons.length > 1 ? 's' : ''}',
                    if (s.rating != null && s.rating! > 0)
                      '★ ${s.rating!.toStringAsFixed(1)}',
                  ],
                  plot: s.plot,
                  actions: [
                    if (firstEpisodes != null && firstEpisodes.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => _play(firstEpisodes, 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Regarder le premier épisode'),
                      ),
                  ],
                ),
              ),
              if (snap.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: LoadingView(label: 'Chargement des épisodes…'),
                  ),
                )
              else if (snap.hasError)
                SliverToBoxAdapter(
                  child: MessageView(
                    icon: Icons.wifi_off_rounded,
                    title: 'Épisodes indisponibles',
                    message: errorText(snap.error!),
                    action: FilledButton(
                      onPressed: () => setState(() => _seasons = _load()),
                      child: const Text('Réessayer'),
                    ),
                  ),
                )
              else if (season == null)
                const SliverToBoxAdapter(
                  child: MessageView(
                    icon: Icons.video_library_outlined,
                    title: 'Aucun épisode disponible',
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 8,
                      ),
                      children: [
                        for (var i = 0; i < seasons.length; i++)
                          CategoryChip(
                            label: 'Saison ${seasons[i].number}',
                            selected: i == _seasonIndex,
                            onTap: () => setState(() => _seasonIndex = i),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(40, 12, 40, 40),
                  sliver: SliverList.builder(
                    itemCount: season.episodes.length,
                    itemBuilder: (_, i) => _EpisodeTile(
                      episode: season.episodes[i],
                      fallbackImage: s.cover,
                      onTap: () => _play(season.episodes, i),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.onTap,
    this.fallbackImage,
  });

  final Episode episode;
  final VoidCallback onTap;
  final String? fallbackImage;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: HoverCard(
      onTap: onTap,
      scale: 1.01,
      lift: 3,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Nx.radiusSm),
            child: SizedBox(
              width: 176,
              height: 99,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(
                    episode.image ?? fallbackImage,
                    label: episode.title,
                    cacheWidth: 360,
                  ),
                  const Center(
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xCC0B0C0F),
                      child: Icon(Icons.play_arrow_rounded, color: Nx.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Épisode ${episode.number}',
                  style: const TextStyle(
                    color: Nx.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  episode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (episode.plot != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    episode.plot!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Nx.muted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (episode.duration != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                episode.duration!,
                style: const TextStyle(color: Nx.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    ),
  );
}
