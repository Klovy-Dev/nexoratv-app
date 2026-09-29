import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import 'home_screen.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'onboarding.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

enum Section {
  home('Accueil', Icons.home_rounded),
  live('TV en direct', Icons.live_tv_rounded),
  movies('Films', Icons.movie_rounded),
  series('Séries', Icons.video_library_rounded);

  const Section(this.title, this.icon);
  final String title;
  final IconData icon;

  Widget get screen => switch (this) {
    Section.home => const HomeScreen(),
    Section.live => const LiveScreen(),
    Section.movies => const MoviesScreen(),
    Section.series => const SeriesScreen(),
  };
}

class NavState {
  const NavState(this.section, {this.channelId});

  final Section section;

  /// Chaîne à lancer en arrivant sur la TV en direct (depuis l'accueil).
  final String? channelId;
}

/// Section affichée dans la barre du haut.
class NavController extends Notifier<NavState> {
  @override
  NavState build() => const NavState(Section.home);

  void go(Section section) => state = NavState(section);

  /// Ouvre la TV en direct sur une chaîne.
  void watchChannel(String id) => state = NavState(Section.live, channelId: id);

  /// La TV en direct a lancé la chaîne demandée.
  void channelStarted() => state = NavState(state.section);
}

final navProvider = NotifierProvider<NavController, NavState>(
  NavController.new,
);

void openSettings(
  BuildContext context, {
  SettingsTab tab = SettingsTab.sources,
}) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => SettingsScreen(initialTab: tab)));

/// Écran principal : barre de navigation fixe + section en cours.
///
/// Accueil, Films et Séries restent montés une fois visités (on retrouve
/// sa recherche et sa position) ; la TV en direct est fermée dès qu'on la
/// quitte, pour couper le flux.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _visited = <Section>{};

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(navProvider.select((n) => n.section));
    final active = ref.watch(appProvider.select((s) => s.active));
    _visited.add(section);

    // Touche Retour (télécommande) : revient à l'accueil avant de quitter.
    return PopScope(
      canPop: section == Section.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(navProvider.notifier).go(Section.home);
      },
      child: _body(section, active?.id),
    );
  }

  Widget _body(Section section, String? activeId) {
    return Scaffold(
      body: Column(
        children: [
          _NavBar(current: section),
          const Divider(),
          Expanded(
            // Changer de source recharge toutes les sections.
            child: KeyedSubtree(
              key: ValueKey(activeId),
              child: IndexedStack(
                index: section.index,
                sizing: StackFit.expand,
                children: [
                  for (final s in Section.values)
                    TickerMode(
                      enabled: s == section,
                      child:
                          s == section ||
                              (s != Section.live && _visited.contains(s))
                          ? FocusTraversalGroup(child: s.screen)
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends ConsumerWidget {
  const _NavBar({required this.current});

  final Section current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(appProvider.select((s) => s.active));
    return FocusTraversalGroup(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 20, 12),
        child: Row(
          children: [
            const Brand(size: 21),
            const SizedBox(width: 36),
            for (final s in Section.values)
              _NavTab(
                section: s,
                selected: s == current,
                onTap: () => ref.read(navProvider.notifier).go(s),
              ),
            const Spacer(),
            if (active != null) SourceChip(name: active.name),
            const SizedBox(width: 10),
            IconButton.outlined(
              tooltip: 'Paramètres',
              onPressed: () => openSettings(context),
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onglet de la barre du haut : texte, souligné corail quand il est actif.
class _NavTab extends StatefulWidget {
  const _NavTab({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final Section section;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final color = sel || _hover || _focus ? Nx.text : Nx.muted;
    return FocusableActionDetector(
      // À la télécommande, rien ne répond aux flèches tant qu'aucun élément
      // n'a le focus : on le place sur l'onglet actif.
      autofocus: Platform.isAndroid && sel,
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Nx.fast,
          curve: Nx.ease,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: _hover || _focus ? Nx.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(Nx.radiusSm),
            border: Border.all(
              color: _focus ? Nx.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.section.title,
                style: TextStyle(
                  color: color,
                  fontSize: 14.5,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: Nx.fast,
                curve: Nx.ease,
                height: 2.5,
                width: sel ? 18 : 0,
                decoration: BoxDecoration(
                  color: Nx.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Source active ; un clic ouvre « Compte et sources » pour en changer.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => HoverCard(
    onTap: () => openSettings(context),
    radius: 999,
    scale: 1,
    lift: 0,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.dns_rounded, size: 16, color: Nx.accent),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.expand_more_rounded, size: 18, color: Nx.muted),
      ],
    ),
  );
}
