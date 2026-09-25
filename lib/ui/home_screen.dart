import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'onboarding.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

enum Section {
  live(
    'TV en direct',
    'Toutes vos chaînes, par catégorie, avec zapping au clavier.',
    Icons.live_tv_rounded,
  ),
  movies(
    'Films',
    'Le catalogue de films, avec affiches, résumés et notes.',
    Icons.movie_rounded,
  ),
  series(
    'Séries',
    'Saisons et épisodes, lecture enchaînée automatique.',
    Icons.video_library_rounded,
  );

  const Section(this.title, this.description, this.icon);
  final String title;
  final String description;
  final IconData icon;

  Widget get screen => switch (this) {
    Section.live => const LiveScreen(),
    Section.movies => const MoviesScreen(),
    Section.series => const SeriesScreen(),
  };
}

void openSettings(
  BuildContext context, {
  SettingsTab tab = SettingsTab.sources,
}) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => SettingsScreen(initialTab: tab)));

/// Accueil : trois grandes cartes (TV, Films, Séries) + accès aux paramètres.
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

    return Scaffold(
      body: GlassBackdrop(
        child: Column(
          children: [
            TopBar(
              leading: const Brand(),
              actions: [if (active != null) SourceChip(name: active.name)],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(48, 12, 48, 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName == null || firstName.isEmpty
                              ? '${_greeting()} !'
                              : '${_greeting()}, $firstName',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          active == null
                              ? 'Ajoutez une source pour commencer.'
                              : 'Qu’est-ce qu’on regarde ?',
                          style: const TextStyle(color: Nx.muted, fontSize: 16),
                        ),
                        const SizedBox(height: 36),
                        if (active == null)
                          _NoSourceCard(onOpen: () => openSettings(context))
                        else
                          LayoutBuilder(
                            builder: (context, c) {
                              final cards = [
                                for (final s in Section.values)
                                  _SectionCard(
                                    section: s,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SectionPage(section: s),
                                      ),
                                    ),
                                  ),
                              ];
                              // Fenêtre étroite : cartes empilées.
                              if (c.maxWidth < 760) {
                                return Column(
                                  children: [
                                    for (final card in cards)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 18,
                                        ),
                                        child: SizedBox(
                                          height: 220,
                                          child: card,
                                        ),
                                      ),
                                  ],
                                );
                              }
                              return SizedBox(
                                height: 340,
                                child: Row(
                                  children: [
                                    for (var i = 0; i < cards.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 22),
                                      Expanded(child: cards[i]),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  const _SectionCard({required this.section, required this.onTap});

  final Section section;
  final VoidCallback onTap;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: HoverCard(
        onTap: widget.onTap,
        glass: true,
        radius: 22,
        scale: 1.03,
        lift: 8,
        child: Stack(
          children: [
            // Halo corail qui s'intensifie au survol.
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: _hover ? 0.9 : 0.25,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.8, -0.9),
                      radius: 1.3,
                      colors: [Color(0x33FF4B3E), Color(0x00FF4B3E)],
                    ),
                  ),
                ),
              ),
            ),
            // Grande icône en filigrane.
            Positioned(
              right: -24,
              bottom: -30,
              child: AnimatedRotation(
                turns: _hover ? -0.03 : 0,
                duration: const Duration(milliseconds: 450),
                curve: Nx.ease,
                child: Icon(
                  s.icon,
                  size: 200,
                  color: Colors.white.withValues(alpha: _hover ? 0.07 : 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: Nx.fast,
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _hover
                          ? Nx.accent
                          : Nx.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      s.icon,
                      size: 28,
                      color: _hover ? Nx.bg : Nx.accent,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    s.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(s.description, style: const TextStyle(color: Nx.muted)),
                  const SizedBox(height: 18),
                  AnimatedSlide(
                    offset: Offset(_hover ? 0.04 : 0, 0),
                    duration: Nx.fast,
                    child: Row(
                      children: [
                        Text(
                          'Ouvrir',
                          style: TextStyle(
                            color: _hover ? Nx.accent : Nx.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: _hover ? Nx.accent : Nx.text,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSourceCard extends StatelessWidget {
  const _NoSourceCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => HoverCard(
    onTap: onOpen,
    glass: true,
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

/// Page d'une section (TV, Films, Séries) avec barre du haut.
class SectionPage extends ConsumerWidget {
  const SectionPage({super.key, required this.section});

  final Section section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(appProvider.select((s) => s.active));
    return Scaffold(
      body: Column(
        children: [
          TopBar(
            leading: Row(
              children: [
                IconButton(
                  tooltip: 'Accueil',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Icon(section.icon, color: Nx.accent, size: 22),
                const SizedBox(width: 10),
                Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            actions: [if (active != null) SourceChip(name: active.name)],
          ),
          const Divider(),
          // La clé inclut la source : changer de source recharge l'écran.
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(active?.id),
              child: section.screen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre du haut commune : contenu à gauche, actions + bouton Paramètres à droite.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.leading, this.actions = const []});

  final Widget leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
    child: Row(
      children: [
        leading,
        const Spacer(),
        ...actions,
        const SizedBox(width: 10),
        IconButton.outlined(
          tooltip: 'Paramètres',
          onPressed: () => openSettings(context),
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    ),
  );
}

/// Source active ; un clic ouvre « Compte et sources » pour en changer.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => HoverCard(
    onTap: () => openSettings(context),
    glass: true,
    radius: 999,
    scale: 1.03,
    lift: 2,
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
