import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist_source.dart';
import '../../services/device_mac.dart';
import '../../services/mac_portal_service.dart';
import '../../state/channels_provider.dart';
import '../../state/providers.dart';
import '../../state/sources_provider.dart';

/// Mode d'ajout d'une nouvelle source (l'édition, elle, reste dans le mode
/// de la source existante — voir [_isLegacyM3u] / [_isMacEdit]).
enum _AddMode { xtream, mac }

class AddSourceScreen extends ConsumerStatefulWidget {
  const AddSourceScreen({super.key, this.existing});

  /// Si non nul, l'écran est en mode « modifier ».
  final PlaylistSource? existing;

  @override
  ConsumerState<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends ConsumerState<AddSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  late XtreamOutput _output;
  _AddMode _mode = _AddMode.xtream;

  final _name = TextEditingController();
  final _m3uUrl = TextEditingController();
  final _epgUrl = TextEditingController();
  final _host = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _deviceMac;

  bool get _isEdit => widget.existing != null;

  /// Source M3U ajoutée avant l'activation par MAC (compat ascendante) :
  /// on garde l'écran d'édition classique (URL visible) pour ces sources-là.
  bool get _isLegacyM3u =>
      _isEdit &&
      widget.existing!.kind == SourceKind.m3uUrl &&
      widget.existing!.activationMac == null;

  bool get _isMacEdit =>
      _isEdit && widget.existing!.activationMac != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _output = e?.xtreamOutput ?? XtreamOutput.ts;
    if (e != null) {
      _name.text = e.name;
      _m3uUrl.text = e.m3uUrl ?? '';
      _epgUrl.text = e.epgUrl ?? '';
      _host.text = e.host ?? '';
      _username.text = e.username ?? '';
      _password.text = e.password ?? '';
    }
    if (!_isEdit || _isMacEdit) {
      DeviceMac.getOrCreate().then((mac) {
        if (mounted) setState(() => _deviceMac = mac);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _m3uUrl, _epgUrl, _host, _username, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _normalizeHost(String raw) {
    var h = raw.trim();
    if (!h.startsWith('http://') && !h.startsWith('https://')) h = 'http://$h';
    return h.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> _submitXtream() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final name = _name.text.trim().isEmpty
        ? _username.text.trim()
        : _name.text.trim();
    final source = PlaylistSource(
      id: widget.existing?.id,
      createdAt: widget.existing?.createdAt,
      name: name,
      kind: SourceKind.xtream,
      host: _normalizeHost(_host.text),
      username: _username.text.trim(),
      password: _password.text.trim(),
      xtreamOutput: _output,
    );
    try {
      await ref.read(playlistServiceProvider).validate(source);
      final notifier = ref.read(sourcesProvider.notifier);
      if (_isEdit) {
        await notifier.editSource(source);
        ref.invalidate(playlistForSourceProvider(source.id));
      } else {
        await notifier.add(source);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Édition d'une source M3U historique (URL/EPG visibles) — compat.
  Future<void> _submitLegacyM3u() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final name = _name.text.trim().isEmpty ? 'Playlist' : _name.text.trim();
    final source = PlaylistSource(
      id: widget.existing!.id,
      createdAt: widget.existing!.createdAt,
      name: name,
      kind: SourceKind.m3uUrl,
      m3uUrl: _m3uUrl.text.trim(),
      epgUrl: _epgUrl.text.trim().isEmpty ? null : _epgUrl.text.trim(),
    ).upgradedToXtreamIfPossible();
    try {
      await ref.read(playlistServiceProvider).validate(source);
      await ref.read(sourcesProvider.notifier).editSource(source);
      ref.invalidate(playlistForSourceProvider(source.id));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activateByMac() async {
    final mac = _deviceMac;
    if (mac == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(playlistServiceProvider);
      final source = (await service.activateByMac(mac)).copyWith(
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      final notifier = ref.read(sourcesProvider.notifier);
      if (_isMacEdit) {
        await notifier.editSource(PlaylistSource(
          id: widget.existing!.id,
          createdAt: widget.existing!.createdAt,
          name: source.name,
          kind: SourceKind.m3uUrl,
          m3uUrl: source.m3uUrl,
          epgUrl: source.epgUrl,
          activationMac: mac,
        ));
        ref.invalidate(playlistForSourceProvider(widget.existing!.id));
      } else {
        await notifier.add(source);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isMacEdit
              ? 'Playlist réactivée.'
              : 'Activation réussie : playlist ajoutée.'),
        ));
        Navigator.of(context).pop();
      }
    } on MacPortalException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Modifier la source' : 'Ajouter une source')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _isEdit ? _editBody() : _addBody(),
        ),
      ),
    );
  }

  Widget _editBody() {
    if (_isMacEdit) return _macForm();
    if (_isLegacyM3u) return _m3uForm();
    return _xtreamForm();
  }

  Widget _addBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SegmentedButton<_AddMode>(
            segments: const [
              ButtonSegment(
                value: _AddMode.xtream,
                label: Text('Xtream Codes'),
                icon: Icon(Icons.vpn_key),
              ),
              ButtonSegment(
                value: _AddMode.mac,
                label: Text('Adresse MAC'),
                icon: Icon(Icons.router_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _error = null;
            }),
          ),
        ),
        Expanded(
          child: _mode == _AddMode.xtream ? _xtreamForm() : _macForm(),
        ),
      ],
    );
  }

  Widget _xtreamForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom (facultatif)'),
          ),
          const SizedBox(height: 16),
          ..._xtreamFields(),
          ..._errorBanner(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submitXtream,
            icon: _busy ? _spinner() : const Icon(Icons.check),
            label: Text(_busy
                ? 'Vérification…'
                : (_isEdit ? 'Enregistrer' : 'Vérifier et ajouter')),
          ),
        ],
      ),
    );
  }

  Widget _m3uForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom (facultatif)'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _m3uUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'URL de la playlist M3U',
              hintText: 'http://exemple.com/get.php?username=…',
            ),
            validator: (v) => (v == null || !v.trim().startsWith('http'))
                ? 'URL invalide'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _epgUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration:
                const InputDecoration(labelText: 'URL EPG XMLTV (facultatif)'),
          ),
          ..._errorBanner(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submitLegacyM3u,
            icon: _busy ? _spinner() : const Icon(Icons.check),
            label: Text(_busy ? 'Vérification…' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }

  Widget _macForm() {
    final mac = _deviceMac;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_isMacEdit)
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom (facultatif)'),
          ),
        if (!_isMacEdit) const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adresse MAC de cet appareil',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        mac ?? '…',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (mac != null)
                      IconButton(
                        tooltip: 'Copier',
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: mac));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Adresse MAC copiée.')),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Communiquez cette adresse au support NexoraTV pour '
                  'activer votre playlist, puis appuyez sur '
                  '« ${_isMacEdit ? 'Réactiver' : 'Activer'} ».',
                  style: TextStyle(
                      fontSize: 12.5, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ),
        ..._errorBanner(),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: (_busy || mac == null) ? null : _activateByMac,
          icon: _busy ? _spinner() : const Icon(Icons.link),
          label: Text(_busy
              ? 'Activation…'
              : (_isMacEdit ? 'Réactiver' : 'Activer')),
        ),
      ],
    );
  }

  List<Widget> _errorBanner() {
    if (_error == null) return const [];
    return [
      const SizedBox(height: 16),
      Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ];
  }

  Widget _spinner() => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );

  List<Widget> _xtreamFields() => [
        TextFormField(
          controller: _host,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Adresse du serveur',
            hintText: 'http://exemple.com:8080',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _username,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Identifiant'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mot de passe'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration:
              const InputDecoration(labelText: 'Format des flux en direct'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<XtreamOutput>(
              value: _output,
              isDense: true,
              onChanged: (v) => setState(() => _output = v ?? XtreamOutput.ts),
              items: const [
                DropdownMenuItem(
                  value: XtreamOutput.ts,
                  child: Text('MPEG-TS (.ts) — compatible'),
                ),
                DropdownMenuItem(
                  value: XtreamOutput.m3u8,
                  child: Text('HLS (.m3u8) — meilleur buffering'),
                ),
              ],
            ),
          ),
        ),
      ];
}
