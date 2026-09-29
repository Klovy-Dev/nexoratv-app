import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/models.dart';
import '../state/app_state.dart';
import '../state/library.dart';
import 'catalog.dart';
import 'library_widgets.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'shell.dart';
import 'theme.dart';
import 'toast.dart';
import 'widgets.dart';

/// Nombre d'éléments par rangée de l'accueil.
const _shelfSize = 20;

/// Films les plus récemment ajoutés (vrai si la source donne les dates ;
/// sinon, les premiers de la liste).
final _recentMoviesProvider = FutureProvider<(List<Movie>, bool)>((ref) async {
  final all = await ref.watch(moviesProvider.future);
  final dated = [
    for (final m in all)
      if (m.added != null) m,
  ];
  if (dated.isEmpty) return (all.take(_shelfSize).toList(), false);
  dated.sort((a, b) => b.added!.compareTo(a.added!));
  return (dated.take(_shelfSize).toList(), true);
});

/// Séries les plus récemment mises à jour (même logique que les films).
final _recentSeriesProvider = FutureProvider<(List<Series>, bool)>((ref) async {
  final all = await ref.watch(seriesProvider.future);
  final dated = [
    for (final s in all)
      if (s.updated != null) s,
  ];
  if (dated.isEmpty) return (all.take(_shelfSize).toList(), false);
  dated.sort((a, b) => b.updated!.compareTo(a.updated!));
  return (dated.take(_shelfSize).toList(), true);
});

/// Chaînes favorites, dans l'ordre d'ajout (les dernières d'abord).
final _favoriteChannelsProvider = FutureProvider<List<LiveChannel>>((
  ref,
) async {
  final favorites = ref.watch(libraryProvider.select((l) => l.favorites));
  final ids = Library(favorites: favorites).favoriteIds(MediaKind.live);
  if (ids.isEmpty) return const [];
  final all = await ref.watch(liveChannelsProvider.future);
  final byId = {
    for (final c in all)
      if (ids.contains(c.id)) c.id: c,
  };
  return [
    for (final id in ids.toList().reversed)
      if (byId[id] != null) byId[id]!,
  ];
});

/// « Ma liste » : films et séries favoris (les derniers ajoutés d'abord).
final _myListProvider = FutureProvider<List<Object>>((ref) async {
  final favorites = ref.watch(libraryProvider.select((l) => l.favorites));
  final lib = Library(favorites: favorites);
  final movieIds = lib.favoriteIds(MediaKind.movie);
  final seriesIds = lib.favoriteIds(MediaKind.series);
  if (movieIds.isEmpty && seriesIds.isEmpty) return const [];
  final movies = movieIds.isEmpty
      ? const <String, Movie>{}
      : {
          for (final m in await ref.watch(moviesProvider.future))
            if (movieIds.contains(m.id)) m.id: m,
        };
  final series = seriesIds.isEmpty
      ? const <String, Series>{}
      : {
          for (final s in await ref.watch(seriesProvider.future))
            if (seriesIds.contains(s.id)) s.id: s,
        };
  final items = <Object>[];
  for (final key in favorites.toList().reversed) {
    final i = key.indexOf(':');
    final kind = key.substring(0, i);
    final id = key.substring(i + 1);
    final item = kind == MediaKind.movie.name
        ? movies[id]
        : kind == MediaKind.series.name
        ? series[id]
        : null;
    if (item != null) items.add(item);
  }
  return items;
});

void _openMovie(BuildContext context, Movie movie) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)));

void _openSeries(BuildContext context, Series series) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => SeriesDetailPage(series: series)));

/// Accueil : reprise de lecture, chaînes favorites, « Ma liste » et
/// nouveautés, en rangées qui défilent horizontalement.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    return h >= 18 || h < 5 ? 'Bonsoir' : 'Bonjour';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final active = app.active;
    final firstName = app.user?.name.split(' ').first;

    return ListView(
      padding: const EdgeInsets.only(top: 30, bottom: 40),
      children: [
        _Pad(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName == null || firstName.isEmpty
                    ? '${_greeting()} !'
                    : '${_greeting()}, $firstName',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                active == null
                    ? 'Ajoutez une source pour commencer.'
                    : 'Qu’est-ce qu’on regarde ?',
                style: const TextStyle(color: Nx.muted, fontSize: 15),
              ),
            ],
          ),
        ),
        if (active == null)
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: _Pad(
              child: _NoSourceCard(onOpen: () => openSettings(context)),
            ),
          )
        else ...const [
          _ContinueWatching(),
          _FavoriteChannels(),
          _MyList(),
          _RecentMovies(),
          _RecentSeries(),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: _Pad(child: _SocialLinks()),
        ),
      ],
    );
  }
}

/// Marges latérales de l'accueil.
class _Pad extends StatelessWidget {
  const _Pad({required this.child});
  final Widget child;

  static const inset = 40.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: inset),
    child: child,
  );
}

/// Rangée de l'accueil : titre, lien « Tout voir » et liste horizontale.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.title,
    required this.height,
    required this.itemWidth,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
  });

  final String title;
  final double height;
  final double itemWidth;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 34),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Pad(
          child: Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (onSeeAll != null)
                TextButton.icon(
                  onPressed: onSeeAll,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Tout voir'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          // Marge pour le soulèvement et le halo de focus des cartes.
          height: height + 20,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(_Pad.inset, 10, _Pad.inset, 10),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 18),
            itemBuilder: (context, i) =>
                SizedBox(width: itemWidth, child: itemBuilder(context, i)),
          ),
        ),
      ],
    ),
  );
}

/// Rangée en cours de chargement : cases grises aux dimensions finales
/// (la page ne saute pas quand le contenu arrive).
class _ShelfSkeleton extends StatelessWidget {
  const _ShelfSkeleton({required this.height, required this.itemWidth});

  final double height;
  final double itemWidth;

  @override
  Widget build(BuildContext context) => _Shelf(
    title: '',
    height: height,
    itemWidth: itemWidth,
    itemCount: 8,
    itemBuilder: (_, _) => DecoratedBox(
      decoration: BoxDecoration(
        color: Nx.surface,
        borderRadius: BorderRadius.circular(Nx.radius),
      ),
    ),
  );
}

const _posterWidth = 150.0;
const _posterHeight = 290.0;

/// Rangée d'affiches (films et / ou séries).
class _PosterShelf extends StatelessWidget {
  const _PosterShelf({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  final String title;
  final List<PosterItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => _Shelf(
    title: title,
    height: _posterHeight,
    itemWidth: _posterWidth,
    itemCount: items.length,
    onSeeAll: onSeeAll,
    itemBuilder: (_, i) => PosterTile(item: items[i], onTap: () => onOpen(i)),
  );
}

PosterItem _moviePoster(Movie m) => PosterItem(
  id: m.id,
  title: m.name,
  categoryId: m.categoryId,
  image: m.poster,
  subtitle: m.year,
  rating: m.rating,
);

PosterItem _seriesPoster(Series s) => PosterItem(
  id: s.id,
  title: s.name,
  categoryId: s.categoryId,
  image: s.cover,
  subtitle: s.year,
  rating: s.rating,
);

class _RecentMovies extends ConsumerWidget {
  const _RecentMovies();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(_recentMoviesProvider)) {
        AsyncData(value: (final movies, final dated)) when movies.isNotEmpty =>
          _PosterShelf(
            title: dated ? 'Films ajoutés récemment' : 'Films',
            items: [for (final m in movies) _moviePoster(m)],
            onOpen: (i) => _openMovie(context, movies[i]),
            onSeeAll: () => ref.read(navProvider.notifier).go(Section.movies),
          ),
        AsyncLoading() => const _ShelfSkeleton(
          height: _posterHeight,
          itemWidth: _posterWidth,
        ),
        _ => const SizedBox.shrink(),
      };
}

class _RecentSeries extends ConsumerWidget {
  const _RecentSeries();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(_recentSeriesProvider)) {
        AsyncData(value: (final series, final dated)) when series.isNotEmpty =>
          _PosterShelf(
            title: dated ? 'Séries mises à jour' : 'Séries',
            items: [for (final s in series) _seriesPoster(s)],
            onOpen: (i) => _openSeries(context, series[i]),
            onSeeAll: () => ref.read(navProvider.notifier).go(Section.series),
          ),
        AsyncLoading() => const _ShelfSkeleton(
          height: _posterHeight,
          itemWidth: _posterWidth,
        ),
        _ => const SizedBox.shrink(),
      };
}

class _MyList extends ConsumerWidget {
  const _MyList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_myListProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return _PosterShelf(
      title: 'Ma liste',
      items: [
        for (final item in items)
          switch (item) {
            Movie m => _moviePoster(m),
            Series s => _seriesPoster(s),
            _ => throw StateError('type inattendu'),
          },
      ],
      onOpen: (i) => switch (items[i]) {
        Movie m => _openMovie(context, m),
        Series s => _openSeries(context, s),
        _ => null,
      },
    );
  }
}

class _FavoriteChannels extends ConsumerWidget {
  const _FavoriteChannels();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(_favoriteChannelsProvider).value ?? const [];
    if (channels.isEmpty) return const SizedBox.shrink();
    final nav = ref.read(navProvider.notifier);
    return _Shelf(
      title: 'Vos chaînes',
      height: 136,
      itemWidth: 172,
      itemCount: channels.length,
      onSeeAll: () => nav.go(Section.live),
      itemBuilder: (_, i) => _ChannelTile(
        channel: channels[i],
        onTap: () => nav.watchChannel(channels[i].id),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, required this.onTap});

  final LiveChannel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: HoverCard(
          onTap: onTap,
          color: Nx.surface2,
          scale: 1.04,
          padding: const EdgeInsets.all(18),
          child: Center(
            child: NetImage(
              channel.logo,
              label: channel.name,
              fit: BoxFit.contain,
              cacheWidth: 280,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        channel.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    ],
  );
}

/// Liens communauté en pied de l'accueil (ouverts dans le navigateur).
class _SocialLinks extends StatelessWidget {
  const _SocialLinks();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text(
        'La communauté NexoraTV',
        style: TextStyle(color: Nx.muted, fontSize: 13),
      ),
      const SizedBox(width: 14),
      _SocialButton(tooltip: 'Discord', icon: Icons.discord, url: kDiscordUrl),
      const SizedBox(width: 8),
      _SocialButton(
        tooltip: 'Telegram',
        icon: Icons.telegram,
        url: kTelegramUrl,
      ),
      const SizedBox(width: 8),
      _SocialButton(
        tooltip: 'Site NexoraTV',
        icon: Icons.language_rounded,
        url: kSiteUrl,
      ),
    ],
  );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.tooltip,
    required this.icon,
    required this.url,
  });

  final String tooltip;
  final IconData icon;
  final String url;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: HoverCard(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      radius: 999,
      scale: 1.06,
      lift: 0,
      padding: const EdgeInsets.all(9),
      child: Icon(icon, size: 19, color: Nx.text),
    ),
  );
}

class _NoSourceCard extends StatelessWidget {
  const _NoSourceCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => HoverCard(
    onTap: onOpen,
    scale: 1,
    lift: 0,
    padding: const EdgeInsets.all(30),
    child: Row(
      children: [
        const Icon(Icons.dns_rounded, color: Nx.accent, size: 32),
        const SizedBox(width: 20),
        const Expanded(
          child: Text(
            'Connectez votre compte NexoraTV ou ajoutez un serveur Xtream / une playlist M3U.',
            style: TextStyle(color: Nx.muted),
          ),
        ),
        FilledButton(onPressed: onOpen, child: const Text('Compte et sources')),
      ],
    ),
  );
}

/// « Continuer à regarder » : films et épisodes commencés, les plus
/// récents d'abord. Un clic reprend la lecture là où elle s'était arrêtée.
class _ContinueWatching extends ConsumerWidget {
  const _ContinueWatching();

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    WatchProgress p,
  ) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    try {
      if (p.kind == MediaKind.movie) {
        final movies = await ref.read(moviesProvider.future);
        final movie = movies.where((m) => m.id == p.id).firstOrNull;
        if (movie == null) throw _NotInCatalog();
        if (context.mounted) await playMovie(context, movie);
        return;
      }
      final all = await ref.read(seriesProvider.future);
      final series = all.where((s) => s.id == p.seriesId).firstOrNull;
      final content = ref.read(contentProvider);
      if (series == null || content == null) throw _NotInCatalog();
      final seasons = await content.seasons(series);
      for (final season in seasons) {
        final i = season.episodes.indexWhere((e) => e.id == p.id);
        if (i >= 0) {
          if (context.mounted) {
            await playEpisodes(context, series, season.episodes, i);
          }
          return;
        }
      }
      throw _NotInCatalog();
    } on _NotInCatalog {
      ref.read(libraryProvider.notifier).removeProgress(p.kind, p.id);
      showToastIn(
        overlay,
        'Ce titre n’est plus proposé par cette source.',
        kind: ToastKind.info,
      );
    } catch (e) {
      showToastIn(overlay, errorText(e), kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(libraryProvider.select((l) => l.progress));
    if (progress.isEmpty) return const SizedBox.shrink();
    final items = progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _Shelf(
      title: 'Continuer à regarder',
      height: 196,
      itemWidth: 256,
      itemCount: items.length,
      itemBuilder: (_, i) => _ResumeCard(
        progress: items[i],
        onTap: () => _resume(context, ref, items[i]),
        onRemove: () => ref
            .read(libraryProvider.notifier)
            .removeProgress(items[i].kind, items[i].id),
      ),
    );
  }
}

/// Titre introuvable dans le catalogue actuel de la source.
class _NotInCatalog implements Exception {}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.progress,
    required this.onTap,
    required this.onRemove,
  });

  final WatchProgress progress;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final left = progress.duration - progress.position;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HoverCard(
          onTap: onTap,
          scale: 1.04,
          lift: 4,
          child: SizedBox(
            height: 144,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetImage(
                  progress.image,
                  label: progress.title,
                  cacheWidth: 512,
                ),
                const Center(
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xCC0B0C0F),
                    child: Icon(Icons.play_arrow_rounded, color: Nx.accent),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: const Color(0xAA0B0C0F),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Retirer de la liste',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      onPressed: onRemove,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: WatchBar(fraction: progress.fraction),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          progress.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'Encore ${formatPosition(left)}',
          style: const TextStyle(color: Nx.muted, fontSize: 12.5),
        ),
      ],
    );
  }
}
