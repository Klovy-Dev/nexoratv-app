import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/channel.dart';
import '../../models/series.dart';
import '../../services/playlist_service.dart';
import '../../state/providers.dart';
import '../../widgets/nav.dart';
import '../catalog/poster_card.dart';
import '../channels/channel_tile.dart';
import '../detail/media_detail_screen.dart';
import '../player/player_screen.dart';

enum _Filter { tout, tv, films, series }

/// Recherche transverse TV + Films + Séries dans la playlist courante,
/// avec historique et filtre par type.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({
    super.key,
    required this.sourceId,
    required this.playlist,
  });

  final String sourceId;
  final LoadedPlaylist playlist;

  @override
  ConsumerState<GlobalSearchScreen> createState() =>
      _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _q = '';
  _Filter _filter = _Filter.tout;
  List<String> _history = const [];

  static const _maxPerSection = 60;

  @override
  void initState() {
    super.initState();
    ref.read(searchHistoryRepositoryProvider).load().then((h) {
      if (mounted) setState(() => _history = h);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      final q = v.trim().toLowerCase();
      if (q != _q && mounted) setState(() => _q = q);
    });
  }

  void _commit(String q) {
    _controller.text = q;
    setState(() => _q = q.toLowerCase());
    ref.read(searchHistoryRepositoryProvider).add(q).then((_) => ref
        .read(searchHistoryRepositoryProvider)
        .load()
        .then((h) => mounted ? setState(() => _history = h) : null));
  }

  List<T> _match<T>(List<T> src, String Function(T) name) {
    if (_q.isEmpty) return const [];
    final out = <T>[];
    for (final e in src) {
      if (name(e).toLowerCase().contains(_q)) {
        out.add(e);
        if (out.length >= _maxPerSection) break;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final showTv = _filter == _Filter.tout || _filter == _Filter.tv;
    final showFilms = _filter == _Filter.tout || _filter == _Filter.films;
    final showSeries = _filter == _Filter.tout || _filter == _Filter.series;

    final tv =
        showTv ? _match<Channel>(widget.playlist.live, (c) => c.name) : <Channel>[];
    final films = showFilms
        ? _match<Channel>(widget.playlist.movies, (c) => c.name)
        : <Channel>[];
    final series = showSeries
        ? _match<Series>(widget.playlist.series, (s) => s.name)
        : <Series>[];
    final nothing =
        _q.isNotEmpty && tv.isEmpty && films.isEmpty && series.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Rechercher partout…',
            border: InputBorder.none,
            filled: false,
          ),
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _commit,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: ChoiceChip(
                      label: Text(switch (f) {
                        _Filter.tout => 'Tout',
                        _Filter.tv => 'TV',
                        _Filter.films => 'Films',
                        _Filter.series => 'Séries',
                      }),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _q.isEmpty
          ? _historyView()
          : nothing
              ? const Center(child: Text('Aucun résultat.'))
              : ListView(
                  children: [
                    if (tv.isNotEmpty) ...[
                      const _Header('TV'),
                      for (var i = 0; i < tv.length; i++)
                        ChannelTile(
                          channel: tv[i],
                          isFavorite: false,
                          showFavorite: false,
                          onToggleFavorite: () {},
                          onTap: () => pushFade(
                            context,
                            PlayerScreen(
                                sourceId: widget.sourceId,
                                playlist: tv,
                                startIndex: i),
                          ),
                        ),
                    ],
                    if (films.isNotEmpty) ...[
                      const _Header('Films'),
                      _PosterRow(
                        items: [
                          for (final m in films)
                            PosterCard(
                              title: m.name,
                              imageUrl: m.logo,
                              year: m.year,
                              rating: m.rating,
                              onTap: () => pushFade(
                                context,
                                MediaDetailScreen.movie(
                                    sourceId: widget.sourceId, movie: m),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (series.isNotEmpty) ...[
                      const _Header('Séries'),
                      _PosterRow(
                        items: [
                          for (final s in series)
                            PosterCard(
                              title: s.name,
                              imageUrl: s.cover,
                              year: s.year,
                              rating: s.rating,
                              onTap: () => pushFade(
                                context,
                                MediaDetailScreen.series(
                                    sourceId: widget.sourceId, series: s),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _historyView() {
    if (_history.isEmpty) {
      return const Center(child: Text('Tape pour chercher.'));
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text('Recherches récentes',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () {
                  ref.read(searchHistoryRepositoryProvider).clear();
                  setState(() => _history = const []);
                },
                child: const Text('Effacer'),
              ),
            ],
          ),
        ),
        for (final h in _history)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(h),
            onTap: () => _commit(h),
          ),
      ],
    );
  }
}

class _PosterRow extends StatelessWidget {
  const _PosterRow({required this.items});
  final List<Widget> items;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(width: 116, child: items[i]),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
              color: Theme.of(context).colorScheme.primary,
            )),
      );
}
