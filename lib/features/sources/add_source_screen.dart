import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist_source.dart';
import '../../state/channels_provider.dart';
import '../../state/providers.dart';
import '../../state/sources_provider.dart';

class AddSourceScreen extends ConsumerStatefulWidget {
  const AddSourceScreen({super.key, this.existing});

  /// Si non nul, l'écran est en mode « modifier ».
  final PlaylistSource? existing;

  @override
  ConsumerState<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends ConsumerState<AddSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  late SourceKind _kind;
  late XtreamOutput _output;

  final _name = TextEditingController();
  final _m3uUrl = TextEditingController();
  final _epgUrl = TextEditingController();
  final _host = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kind = e?.kind ?? SourceKind.m3uUrl;
    _output = e?.xtreamOutput ?? XtreamOutput.ts;
    if (e != null) {
      _name.text = e.name;
      _m3uUrl.text = e.m3uUrl ?? '';
      _epgUrl.text = e.epgUrl ?? '';
      _host.text = e.host ?? '';
      _username.text = e.username ?? '';
      _password.text = e.password ?? '';
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

  PlaylistSource _buildSource() {
    final fallbackName =
        _kind == SourceKind.xtream ? _username.text.trim() : 'Playlist';
    final name =
        _name.text.trim().isEmpty ? fallbackName : _name.text.trim();

    final id = widget.existing?.id;
    final createdAt = widget.existing?.createdAt;
    if (_kind == SourceKind.m3uUrl) {
      return PlaylistSource(
        id: id,
        createdAt: createdAt,
        name: name,
        kind: SourceKind.m3uUrl,
        m3uUrl: _m3uUrl.text.trim(),
        epgUrl: _epgUrl.text.trim().isEmpty ? null : _epgUrl.text.trim(),
      ).upgradedToXtreamIfPossible();
    }
    return PlaylistSource(
      id: id,
      createdAt: createdAt,
      name: name,
      kind: SourceKind.xtream,
      host: _normalizeHost(_host.text),
      username: _username.text.trim(),
      password: _password.text.trim(),
      xtreamOutput: _output,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final source = _buildSource();
    final autoXtream =
        _kind == SourceKind.m3uUrl && source.kind == SourceKind.xtream;
    try {
      await ref.read(playlistServiceProvider).validate(source);
      final notifier = ref.read(sourcesProvider.notifier);
      if (_isEdit) {
        await notifier.editSource(source);
        ref.invalidate(playlistForSourceProvider(source.id));
      } else {
        await notifier.add(source);
      }
      if (mounted) {
        if (autoXtream) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Lien Xtream détecté : chargé en mode Xtream (TV + Films + Séries).'),
          ));
        }
        Navigator.of(context).pop();
      }
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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<SourceKind>(
                  segments: const [
                    ButtonSegment(
                      value: SourceKind.m3uUrl,
                      label: Text('Lien M3U'),
                      icon: Icon(Icons.link),
                    ),
                    ButtonSegment(
                      value: SourceKind.xtream,
                      label: Text('Xtream Codes'),
                      icon: Icon(Icons.vpn_key),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nom (facultatif)',
                  ),
                ),
                const SizedBox(height: 16),
                if (_kind == SourceKind.m3uUrl)
                  ..._m3uFields()
                else
                  ..._xtreamFields(),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style:
                                const TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_busy
                      ? 'Vérification…'
                      : (_isEdit ? 'Enregistrer' : 'Vérifier et ajouter')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _m3uFields() => [
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
          decoration: const InputDecoration(
            labelText: 'URL EPG XMLTV (facultatif)',
          ),
        ),
      ];

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
