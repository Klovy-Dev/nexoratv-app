import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import '../state/library.dart';
import 'catalog.dart';
import 'library_widgets.dart';
import 'player.dart';
import 'widgets.dart';

class MoviesScreen extends ConsumerWidget {
  const MoviesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(movieCategoriesProvider).value ?? const <Category>[];
    // `favorites` ne change qu'à l'ajout / retrait d'un favori (pas à chaque
    // enregistrement de la reprise de lecture).
    final favorites = ref.watch(libraryProvider.select((l) => l.favorites));
    return ref
        .watch(moviesProvider)
        .when(
          loading: () => const LoadingView(label: 'Chargement des films…'),
          error: (e, _) => MessageView(
            icon: Icons.wifi_off_rounded,
            title: 'Films indisponibles',
            message: errorText(e),
            action: FilledButton(
              onPressed: () => ref.invalidate(moviesProvider),
              child: const Text('Réessayer'),
            ),
          ),
          data: (movies) {
            if (movies.isEmpty) {
              return const MessageView(
                icon: Icons.movie_outlined,
                title: 'Aucun film',
                message: 'Cette source ne propose pas de films.',
              );
            }
            final byId = {for (final m in movies) m.id: m};
            return PosterCatalog(
              title: 'Films',
              searchHint: 'Rechercher un film',
              categories: categories,
              favoriteIds: Library(favorites: favorites)
                  .favoriteIds(MediaKind.movie),
              items: [
                for (final m in movies)
                  PosterItem(
                    id: m.id,
                    title: m.name,
                    categoryId: m.categoryId,
                    image: m.poster,
                    subtitle: m.year,
                    rating: m.rating,
                  ),
              ],
              onOpen: (item) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MovieDetailPage(movie: byId[item.id]!),
                ),
              ),
            );
          },
        );
  }
}

class MovieDetailPage extends ConsumerWidget {
  const MovieDetailPage({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final progress = ref.watch(
      libraryProvider.select((l) => l.progressFor(MediaKind.movie, movie.id)),
    );
    return Scaffold(
      body: FutureBuilder<MovieDetails?>(
        future: content?.movieDetails(movie),
        builder: (context, snap) {
          final d = snap.data;
          return SingleChildScrollView(
            child: DetailHeader(
              title: movie.name,
              image: movie.poster,
              backdrop: d?.backdrop,
              meta: [
                if (d?.releaseDate != null)
                  d!.releaseDate!.split('-').first
                else if (movie.year != null)
                  movie.year!,
                if (d?.duration != null) d!.duration!,
                if (d?.genre != null) d!.genre!,
                if (movie.rating != null && movie.rating! > 0)
                  '★ ${movie.rating!.toStringAsFixed(1)}',
              ],
              plot:
                  [
                        if (d?.plot != null) d!.plot!,
                        if (d?.director != null) 'Réalisation : ${d!.director}',
                        if (d?.cast != null) 'Avec : ${d!.cast}',
                      ]
                      .join('\n\n')
                      .ifEmpty(
                        snap.connectionState == ConnectionState.waiting
                            ? 'Chargement du résumé…'
                            : null,
                      ),
              actions: [
                FilledButton.icon(
                  onPressed: () => playMovie(context, movie),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    progress == null
                        ? 'Lecture'
                        : 'Reprendre à ${formatPosition(progress.position)}',
                  ),
                ),
                if (progress != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(libraryProvider.notifier)
                          .removeProgress(MediaKind.movie, movie.id);
                      playMovie(context, movie);
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Depuis le début'),
                  ),
                FavoriteButton(kind: MediaKind.movie, id: movie.id),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Lance un film (reprend là où on s'était arrêté, s'il y a lieu).
Future<void> playMovie(BuildContext context, Movie movie) =>
    PlayerPage.open(context, [
      PlayItem(
        movie.name,
        movie.url,
        kind: MediaKind.movie,
        id: movie.id,
        image: movie.poster,
      ),
    ]);

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}
