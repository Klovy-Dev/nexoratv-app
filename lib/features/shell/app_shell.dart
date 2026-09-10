import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist_source.dart';
import '../../state/account_provider.dart';
import '../../state/avis_provider.dart';
import '../../state/channels_provider.dart';
import '../../state/sources_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/nav.dart';
import '../catalog/catalog_browser.dart';
import '../dashboard/dashboard_page.dart';
import '../search/global_search_screen.dart';
import '../series/series_browser.dart';
import '../settings/settings_screen.dart';
import '../watchlist/watchlist_page.dart';

/// Coquille de l'app : navigation latérale (desktop / TV) / barre basse
/// (mobile) avec Accueil · TV · Films · Séries · Ma liste, + barre du haut.
///
/// Télécommande (Fire TV / Android TV / box) :
/// - flèche **gauche** en bord de contenu → barre latérale ;
/// - **Retour** depuis le contenu → barre latérale ;
/// - **Retour** deux fois de suite → quitte l'app ;
/// - flèche **droite** sur la barre latérale → revient dans le contenu ;
/// - choisir un onglet à la télécommande ramène le focus dans le contenu.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  final _contentScope = FocusScopeNode(debugLabel: 'shell-content');
  final _railScope = FocusScopeNode(debugLabel: 'shell-rail');
  DateTime? _lastBackAt;

  static const _dests = [
    (icon: Icons.home_outlined, sel: Icons.home, label: 'Accueil'),
    (icon: Icons.live_tv_outlined, sel: Icons.live_tv, label: 'TV'),
    (icon: Icons.movie_outlined, sel: Icons.movie, label: 'Films'),
    (icon: Icons.video_library_outlined, sel: Icons.video_library, label: 'Séries'),
    (icon: Icons.bookmark_border, sel: Icons.bookmark, label: 'Ma liste'),
  ];

  @override
  void dispose() {
    _contentScope.dispose();
    _railScope.dispose();
    super.dispose();
  }

  void _select(int i) {
    setState(() => _index = i);
    // Après un choix à la télécommande, on ramène le focus dans le contenu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentScope.requestFocus();
    });
  }

  void _openSearch() {
    final pl = ref.read(currentPlaylistProvider)?.value;
    final src = ref.read(selectedSourceProvider);
    if (pl == null || src == null) return;
    pushFade(context, GlobalSearchScreen(sourceId: src.id, playlist: pl));
  }

  void _handleBack({required bool railAvailable}) {
    // 1er Retour depuis le contenu → barre latérale.
    if (railAvailable && _contentScope.hasFocus) {
      _railScope.requestFocus();
      return;
    }
    // 2e Retour rapproché → quitter l'app.
    final now = DateTime.now();
    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Appuyez encore sur Retour pour quitter'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  KeyEventResult _contentKeys(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // On bouge dans le contenu si possible, sinon on file à la barre latérale.
      if (!_contentScope.focusInDirection(TraversalDirection.left)) {
        _railScope.requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _railKeys(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _contentScope.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(selectedSourceProvider);
    final wide = MediaQuery.sizeOf(context).width >= 800;

    final pages = [
      DashboardPage(onNavigate: _select, active: _index == 0),
      _TvTab(sourceId: source?.id ?? ''),
      _MoviesTab(sourceId: source?.id ?? ''),
      SeriesBrowser(sourceId: source?.id ?? ''),
      const WatchlistPage(),
    ];

    final loading = ref.watch(currentPlaylistProvider)?.isLoading ?? false;
    final body = Column(
      children: [
        _TopBar(
          current: source,
          // Sur desktop / TV, Recherche/Paramètres sont dans la barre
          // latérale ; sur mobile c'est le seul accès, on les garde ici.
          onSearch: wide ? null : _openSearch,
          onSettings:
              wide ? null : () => pushFade(context, const SettingsScreen()),
        ),
        SizedBox(
          height: 2,
          child: loading ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
        const Divider(height: 1),
        // Le contenu vit dans son propre FocusScope : le D-pad y navigue
        // librement sans sauter par accident sur la barre latérale (on y va
        // explicitement par flèche gauche au bord, ou par Retour).
        Expanded(
          child: FocusScope(
            node: _contentScope,
            autofocus: true,
            child: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < pages.length; i++)
                  ExcludeFocus(excluding: i != _index, child: pages[i]),
              ],
            ),
          ),
        ),
      ],
    );

    if (!wide) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack(railAvailable: false);
        },
        child: Scaffold(
          body: SafeArea(child: body),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final d in _dests)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.sel),
                  label: d.label,
                ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack(railAvailable: true);
      },
      child: Scaffold(
        body: Row(
          children: [
            FocusScope(
              node: _railScope,
              child: Focus(
                onKeyEvent: _railKeys,
                canRequestFocus: false,
                skipTraversal: true,
                child: NavigationRail(
                  minWidth: 64,
                  labelType: NavigationRailLabelType.all,
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Image.asset('assets/icon/nexora_logo.png',
                        width: 30, height: 30, cacheWidth: 60),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Rechercher',
                              icon: const Icon(Icons.search),
                              onPressed: _openSearch,
                            ),
                            IconButton(
                              tooltip: 'Paramètres',
                              icon: const Icon(Icons.settings_outlined),
                              onPressed: () =>
                                  pushFade(context, const SettingsScreen()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  destinations: [
                    for (final d in _dests)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.sel),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Focus(
                onKeyEvent: _contentKeys,
                canRequestFocus: false,
                skipTraversal: true,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.current, this.onSearch, this.onSettings});
  final PlaylistSource? current;

  /// Non nuls uniquement sur mobile (desktop : barre latérale).
  final VoidCallback? onSearch;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider).value?.sources ?? const [];

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (sources.length > 1)
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current?.id,
                isDense: true,
                borderRadius: BorderRadius.circular(10),
                items: [
                  for (final s in sources)
                    DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name,
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (id) {
                  if (id != null) {
                    ref.read(sourcesProvider.notifier).select(id);
                  }
                },
              ),
            )
          else
            Text(current?.name ?? 'NexoraTV',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          const _ExpiryChip(),
          if (onSearch != null)
            IconButton(
              tooltip: 'Rechercher',
              icon: const Icon(Icons.search),
              onPressed: onSearch,
            ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: current == null
                ? null
                : () {
                    refreshPlaylist(ref, current!);
                    ref.invalidate(avisProvider);
                  },
          ),
          if (onSettings != null)
            IconButton(
              tooltip: 'Paramètres',
              icon: const Icon(Icons.settings_outlined),
              onPressed: onSettings,
            ),
        ],
      ),
    );
  }
}

class _ExpiryChip extends ConsumerWidget {
  const _ExpiryChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(accountInfoProvider).value;
    final exp = info?.expiresAt;
    if (exp == null) return const SizedBox.shrink();

    final rem = exp.difference(DateTime.now());
    final expired = rem.isNegative;
    final soon = !expired && rem.inDays <= 10;
    if (!expired && !soon) {
      // affichage discret quand tout va bien
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message:
              'Abonnement jusqu\'au ${exp.day}/${exp.month}/${exp.year}',
          child: Text(
            'exp. ${exp.day}/${exp.month}/${exp.year}',
            style: TextStyle(
                fontSize: 11, color: Theme.of(context).hintColor),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(expired ? Icons.error : Icons.warning_amber,
            size: 16, color: Colors.white),
        backgroundColor: expired ? Colors.red : Colors.orange,
        label: Text(
          expired
              ? 'Abonnement expiré'
              : 'Expire dans ${rem.inDays} j',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}

class _TvTab extends ConsumerWidget {
  const _TvTab({required this.sourceId});
  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pl = ref.watch(currentPlaylistProvider);
    return switch (pl) {
      AsyncData(:final value) => CatalogBrowser(
          items: value.live,
          sourceId: sourceId,
          section: CatalogSection.live,
          enableFavorites: true,
          emptyLabel: 'Aucune chaîne.',
        ),
      AsyncError(:final error) => _err('$error'),
      _ => const LoadingView(label: 'Chargement des chaînes TV…'),
    };
  }
}

class _MoviesTab extends ConsumerWidget {
  const _MoviesTab({required this.sourceId});
  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pl = ref.watch(currentPlaylistProvider);
    return switch (pl) {
      AsyncData(:final value) => value.movies.isEmpty
          ? const Center(child: Text('Aucun film sur ce compte.'))
          : CatalogBrowser(
              items: value.movies,
              sourceId: sourceId,
              section: CatalogSection.movie,
              enableFavorites: true,
              allowGrid: true,
              startInGrid: true,
              emptyLabel: 'Aucun film.',
            ),
      AsyncError(:final error) => _err('$error'),
      _ => const LoadingView(label: 'Chargement des films…'),
    };
  }
}

Widget _err(String m) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(m, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
