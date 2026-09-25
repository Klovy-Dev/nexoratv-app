import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'onboarding.dart';
import 'series_screen.dart';
import 'sources_screen.dart';
import 'theme.dart';

enum Section { live, movies, series, sources }

/// Structure principale : menu latéral + contenu.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  late Section _section = ref.read(appProvider).sources.isEmpty ? Section.sources : Section.live;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final active = app.active;

    final Widget body = switch (_section) {
      Section.sources => const SourcesScreen(),
      _ when active == null => _NoSource(onOpen: () => setState(() => _section = Section.sources)),
      Section.live => const LiveScreen(),
      Section.movies => const MoviesScreen(),
      Section.series => const SeriesScreen(),
    };

    return Scaffold(
      body: Row(children: [
        Container(
          width: 232,
          decoration: const BoxDecoration(color: Nx.bgSoft, border: Border(right: BorderSide(color: Nx.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.fromLTRB(24, 28, 24, 30), child: Brand()),
            _NavItem(icon: Icons.live_tv_rounded, label: 'TV en direct', selected: _section == Section.live, onTap: () => setState(() => _section = Section.live)),
            _NavItem(icon: Icons.movie_rounded, label: 'Films', selected: _section == Section.movies, onTap: () => setState(() => _section = Section.movies)),
            _NavItem(icon: Icons.video_library_rounded, label: 'Séries', selected: _section == Section.series, onTap: () => setState(() => _section = Section.series)),
            const Spacer(),
            if (active != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SOURCE', style: TextStyle(color: Nx.muted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(active.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            _NavItem(
              icon: Icons.manage_accounts_rounded,
              label: 'Compte et sources',
              selected: _section == Section.sources,
              onTap: () => setState(() => _section = Section.sources),
            ),
            const SizedBox(height: 18),
          ]),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Nx.ease,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            // La clé inclut la source : changer de source recharge l'écran.
            child: KeyedSubtree(key: ValueKey('${_section.name}|${active?.id}'), child: body),
          ),
        ),
      ]),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final color = sel ? Nx.accent : (_hover ? Nx.text : Nx.muted);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Nx.fast,
          curve: Nx.ease,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          transform: Matrix4.translationValues(_hover && !sel ? 4 : 0, 0, 0),
          decoration: BoxDecoration(
            color: sel ? Nx.accent.withValues(alpha: 0.1) : (_hover ? Nx.surface : Colors.transparent),
            borderRadius: BorderRadius.circular(Nx.radiusSm),
          ),
          child: Row(children: [
            Icon(widget.icon, size: 21, color: color),
            const SizedBox(width: 14),
            Text(widget.label, style: TextStyle(color: sel ? Nx.text : color, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _NoSource extends StatelessWidget {
  const _NoSource({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.dns_rounded, color: Nx.accent, size: 36),
          const SizedBox(height: 14),
          Text('Aucune source', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Connectez votre compte ou ajoutez une source pour commencer.', style: TextStyle(color: Nx.muted)),
          const SizedBox(height: 18),
          FilledButton(onPressed: onOpen, child: const Text('Compte et sources')),
        ]),
      );
}
