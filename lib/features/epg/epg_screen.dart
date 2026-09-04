import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../../models/channel.dart';
import '../../models/epg_entry.dart';
import '../../state/channels_provider.dart';
import '../../state/epg_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/sources_provider.dart';
import '../../widgets/nav.dart';
import '../player/player_screen.dart';

const _pxPerMin = 3.6;
const _rowH = 56.0;
const _labelW = 170.0;

class EpgScreen extends ConsumerWidget {
  const EpgScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epgOn = ref.watch(settingsValueProvider).epgEnabled;
    final playlist = ref.watch(currentPlaylistProvider)?.value;
    final guideAsync = ref.watch(epgGuideProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide des programmes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(epgGuideProvider),
          ),
        ],
      ),
      body: !epgOn
          ? _center('Active l\'EPG dans Paramètres → Lecture.')
          : playlist == null
              ? _center('Charge une source.')
              : guideAsync.when(
                  loading: () => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Téléchargement du guide…'),
                      ],
                    ),
                  ),
                  error: (e, _) => _center('Guide indisponible : $e'),
                  data: (guide) {
                    if (guide.isEmpty) {
                      return _center(
                          'Ce fournisseur ne propose pas de guide XMLTV.');
                    }
                    final channels = playlist.live
                        .where((c) => epgForChannel(guide, c).isNotEmpty)
                        .toList();
                    if (channels.isEmpty) {
                      return _center('Aucune chaîne avec un programme.');
                    }
                    return _Grid(
                        channels: channels,
                        guide: guide,
                        sourceId: ref.read(selectedSourceProvider)!.id);
                  },
                ),
    );
  }

  static Widget _center(String s) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(s)));
}

class _Grid extends StatefulWidget {
  const _Grid(
      {required this.channels, required this.guide, required this.sourceId});
  final List<Channel> channels;
  final Map<String, List<EpgEntry>> guide;
  final String sourceId;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  late final _vGroup = LinkedScrollControllerGroup();
  late final ScrollController _leftV = _vGroup.addAndGet();
  late final ScrollController _rightV = _vGroup.addAndGet();
  late final _hGroup = LinkedScrollControllerGroup();
  late final ScrollController _rulerH = _hGroup.addAndGet();
  late final ScrollController _gridH = _hGroup.addAndGet();

  late final DateTime _windowStart;
  static const _windowHours = 14;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _windowStart =
        DateTime(now.year, now.month, now.day, now.hour).subtract(
      const Duration(minutes: 30),
    );
    // positionne au « maintenant »
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final x = now.difference(_windowStart).inMinutes * _pxPerMin - 80;
      if (_gridH.hasClients) {
        _gridH.jumpTo(x.clamp(0, _gridH.position.maxScrollExtent));
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_leftV, _rightV, _rulerH, _gridH]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _timelineW => _windowHours * 60 * _pxPerMin;

  @override
  Widget build(BuildContext context) {
    final nowX =
        DateTime.now().difference(_windowStart).inMinutes * _pxPerMin;

    return Column(
      children: [
        // règle horaire
        SizedBox(
          height: 30,
          child: Row(
            children: [
              const SizedBox(width: _labelW),
              Expanded(
                child: SingleChildScrollView(
                  controller: _rulerH,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _timelineW,
                    child: Stack(
                      children: [
                        for (var h = 0; h <= _windowHours; h++)
                          Positioned(
                            left: h * 60 * _pxPerMin,
                            top: 6,
                            child: Text(
                              _hLabel(h),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // colonne des chaînes
              SizedBox(
                width: _labelW,
                child: ListView.builder(
                  controller: _leftV,
                  itemCount: widget.channels.length,
                  itemExtent: _rowH,
                  itemBuilder: (_, i) {
                    final c = widget.channels[i];
                    return InkWell(
                      onTap: () => _play(c),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: .5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (c.number != null) ...[
                              Text('${c.number}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor)),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(c.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              // grille des programmes
              Expanded(
                child: SingleChildScrollView(
                  controller: _gridH,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _timelineW,
                    child: Stack(
                      children: [
                        ListView.builder(
                          controller: _rightV,
                          itemCount: widget.channels.length,
                          itemExtent: _rowH,
                          itemBuilder: (_, i) => _ChannelRow(
                            programs:
                                epgForChannel(widget.guide, widget.channels[i]),
                            windowStart: _windowStart,
                            onTap: (p) => _showProgram(widget.channels[i], p),
                          ),
                        ),
                        // ligne "maintenant"
                        Positioned(
                          left: nowX,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 2, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _hLabel(int h) {
    final t = _windowStart.add(Duration(hours: h));
    return '${t.hour.toString().padLeft(2, '0')}h';
  }

  void _play(Channel c) => pushFade(
        context,
        PlayerScreen(
            sourceId: widget.sourceId, playlist: [c], startIndex: 0),
      );

  void _showProgram(Channel c, EpgEntry p) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${c.name}  ·  ${_hm(p.start)} – ${_hm(p.stop)}',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(child: Text(p.description)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _play(c);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Regarder'),
          ),
        ],
      ),
    );
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.programs,
    required this.windowStart,
    required this.onTap,
  });
  final List<EpgEntry> programs;
  final DateTime windowStart;
  final void Function(EpgEntry) onTap;

  @override
  Widget build(BuildContext context) {
    final windowEnd = windowStart.add(const Duration(hours: 14));
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: _rowH,
      child: Stack(
        children: [
          for (final p in programs)
            if (p.stop.isAfter(windowStart) && p.start.isBefore(windowEnd))
              Positioned(
                left: p.start.difference(windowStart).inMinutes * _pxPerMin,
                width: (p.stop.difference(p.start).inMinutes * _pxPerMin - 2)
                    .clamp(20, double.infinity),
                top: 3,
                bottom: 3,
                child: Material(
                  color: p.isNow
                      ? scheme.primary.withValues(alpha: .28)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: () => onTap(p),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            _GridState._hm(p.start),
                            style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
