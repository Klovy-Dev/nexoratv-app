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
///
/// L'activation par adresse MAC n'est plus proposée à l'ajout : elle reste
/// gérée uniquement pour les sources déjà activées ainsi (voir [_isMacEdit]).
enum _AddMode { xtream, m3u }

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
    if (_isMacEdit) {
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

  /// Ajout / édition d'une source « playlist M3U » (URL directe ou lien
  /// `get.php` Xtream, converti automatiquement).
  Future<void> _submitM3u() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final name = _name.text.trim().isEmpty ? 'Playlist' : _name.text.trim();
    final source = PlaylistSource(
      id: widget.existing?.id,
      createdAt: widget.existing?.createdAt,
      name: name,
      kind: SourceKind.m3uUrl,
      m3uUrl: _m3uUrl.text.trim(),
      epgUrl: _epgUrl.text.trim().isEmpty ? null : _epgUrl.text.trim(),
    ).upgradedToXtreamIfPossible();
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
        // Reprend la config résolue (Xtream si le lien assigné en est un,
        // sinon M3U) en gardant l'id existant.
        await notifier.editSource(PlaylistSource(
          id: widget.existing!.id,
          createdAt: widget.existing!.createdAt,
          name: source.name,
          kind: source.kind,
          m3uUrl: source.m3uUrl,
          epgUrl: source.epgUrl,
          host: source.host,
          username: source.username,
          password: source.password,
          xtreamOutput: source.xtreamOutput,
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
                value: _AddMode.m3u,
                label: Text('Playlist M3U'),
                icon: Icon(Icons.link),
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
          child: _mode == _AddMode.xtream ? _xtreamForm() : _m3uForm(),
        ),
      ],
    );
  }

  Widget _xtreamForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TvTextField(
              controller: _name,
              label: 'Nom (facultatif)',
              autofocus: true,
            ),
            const SizedBox(height: 12),
            _TvTextField(
              controller: _host,
              label: 'Adresse du serveur',
              hint: 'http://exemple.com:8080',
              keyboardType: TextInputType.url,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            _TvTextField(
              controller: _username,
              label: 'Identifiant',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            _TvTextField(
              controller: _password,
              label: 'Mot de passe',
              obscureText: true,
              isLast: true,
              onSubmitted: () {
                if (!_busy) _submitXtream();
              },
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            _outputSelector(),
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
      ),
    );
  }

  Widget _m3uForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TvTextField(
              controller: _name,
              label: 'Nom (facultatif)',
              autofocus: true,
            ),
            const SizedBox(height: 12),
            _TvTextField(
              controller: _m3uUrl,
              label: 'URL de la playlist M3U',
              hint: 'https://exemple.com/playlist.m3u',
              keyboardType: TextInputType.url,
              validator: (v) => (v == null || !v.trim().startsWith('http'))
                  ? 'URL invalide'
                  : null,
            ),
            const SizedBox(height: 12),
            _TvTextField(
              controller: _epgUrl,
              label: 'URL EPG XMLTV (facultatif)',
              keyboardType: TextInputType.url,
              isLast: true,
              onSubmitted: () {
                if (!_busy) _submitM3u();
              },
            ),
            ..._errorBanner(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _submitM3u,
              icon: _busy ? _spinner() : const Icon(Icons.check),
              label: Text(_busy
                  ? 'Vérification…'
                  : (_isEdit ? 'Enregistrer' : 'Vérifier et ajouter')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macForm() {
    final mac = _deviceMac;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (!_isMacEdit)
          _TvTextField(
            controller: _name,
            label: 'Nom (facultatif)',
            isLast: true,
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
          autofocus: _isMacEdit,
          onPressed: (_busy || mac == null) ? null : _activateByMac,
          icon: _busy ? _spinner() : const Icon(Icons.link),
          label: Text(_busy
              ? 'Activation…'
              : (_isMacEdit ? 'Réactiver' : 'Activer')),
        ),
        ],
      ),
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

  Widget _outputSelector() => InputDecorator(
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
      );
}

/// Champ texte pensé pour la navigation télécommande (Android TV / Fire TV /
/// box) **et** l'usage tactile.
///
/// Problème résolu : un `TextField` classique ouvre l'IME dès qu'il **reçoit**
/// le focus (le D-pad qui passe dessus suffit), et une fois le clavier fermé
/// la touche OK ne le rouvre pas — l'utilisateur se retrouve bloqué.
///
/// Ici, seul un conteneur est atteint par le D-pad. Il faut appuyer sur OK
/// (ou toucher le champ) pour entrer en édition : `readOnly` passe alors à
/// `false` et une demande de focus à la frame suivante ouvre l'IME de façon
/// fiable. « Suivant » sur le clavier redescend simplement au champ suivant
/// (sans ouvrir l'IME) ; OK le rouvre. Toute sortie du champ (clavier fermé,
/// D-pad, focus déplacé) repasse en mode navigation.
class _TvTextField extends StatefulWidget {
  const _TvTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.isLast = false,
    this.autofocus = false,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;

  /// Dernier champ du formulaire : action « OK » du clavier au lieu de
  /// « Suivant », et [onSubmitted] est appelé à la validation.
  final bool isLast;
  final bool autofocus;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;

  @override
  State<_TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<_TvTextField> {
  // Cible du D-pad. Le champ éditable, lui, est `skipTraversal` : joignable
  // uniquement par une demande de focus explicite (OK / toucher).
  final _wrapperNode = FocusNode(debugLabel: 'tvtf-wrapper');
  final _fieldNode =
      FocusNode(debugLabel: 'tvtf-field', skipTraversal: true);

  bool _wrapperFocused = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _fieldNode.addListener(_onFieldFocusChanged);
  }

  @override
  void dispose() {
    _fieldNode.removeListener(_onFieldFocusChanged);
    _fieldNode.dispose();
    _wrapperNode.dispose();
    super.dispose();
  }

  void _onFieldFocusChanged() {
    // Filet de sécurité : quelle que soit la façon de quitter le champ, on
    // ne reste jamais coincé en mode édition.
    if (!_fieldNode.hasFocus && _editing) {
      setState(() => _editing = false);
    }
  }

  void _startEditing() {
    if (_editing) return;
    setState(() => _editing = true);
    // `readOnly` vient de passer à false : demander le focus à la frame
    // suivante ouvre l'IME de façon fiable, box Android comprises.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldNode.requestFocus();
    });
  }

  void _handleSubmitted(String _) {
    setState(() => _editing = false);
    _wrapperNode.requestFocus();
    if (widget.isLast) {
      widget.onSubmitted?.call();
    } else {
      // Redescend au champ suivant sans ouvrir le clavier : OK le rouvrira.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _wrapperNode.nextFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FocusableActionDetector(
      focusNode: _wrapperNode,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => _wrapperFocused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _startEditing();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: _startEditing,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _wrapperFocused && !_editing
                  ? scheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _fieldNode,
            readOnly: !_editing,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: _editing,
            textInputAction:
                widget.isLast ? TextInputAction.done : TextInputAction.next,
            onTap: _startEditing,
            onTapOutside: (_) {
              if (_editing) _fieldNode.unfocus();
            },
            onFieldSubmitted: _handleSubmitted,
            validator: widget.validator,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
            ),
          ),
        ),
      ),
    );
  }
}
