import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/m3u.dart';
import '../content/xtream.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Logo texte « NexoraTV » (TV en corail, comme sur le site).
class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'Nexora'),
        TextSpan(
          text: 'TV',
          style: TextStyle(color: Nx.accent, fontSize: size),
        ),
      ],
    ),
    style: TextStyle(
      fontFamily: Nx.display,
      fontWeight: FontWeight.w800,
      fontSize: size,
      letterSpacing: -0.5,
    ),
  );
}

/// Premier lancement : se connecter au compte ou ajouter une source.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GlassBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                const Brand(size: 34),
                const SizedBox(height: 18),
                Text(
                  'La TV en direct, les films et les séries,\nau même endroit.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Choice(
                        icon: Icons.person_rounded,
                        title: 'Mon compte NexoraTV',
                        text: 'Connectez-vous avec l’e-mail et le mot de passe du site : vos abonnements sont ajoutés automatiquement.',
                        cta: 'Se connecter',
                        primary: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _Choice(
                        icon: Icons.dns_rounded,
                        title: 'Une autre source',
                        text: 'Ajoutez un serveur Xtream (adresse, utilisateur, mot de passe) ou une playlist M3U.',
                        cta: 'Ajouter une source',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddSourceScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.text,
    required this.cta,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final String cta;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => HoverCard(
    onTap: onTap,
    glass: true,
    radius: 22,
    selected: primary,
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Nx.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Nx.accent),
        ),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: Nx.muted)),
        const SizedBox(height: 24),
        primary
            ? FilledButton(onPressed: onTap, child: Text(cta))
            : OutlinedButton(onPressed: onTap, child: Text(cta)),
      ],
    ),
  );
}

/// Formulaire centré commun (connexion, ajout de source).
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: const Brand(size: 18),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Nx.surface,
              borderRadius: BorderRadius.circular(Nx.radius),
              border: Border.all(color: Nx.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: const TextStyle(color: Nx.muted)),
                ],
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Nx.danger.withValues(alpha: 0.1),
      border: Border.all(color: Nx.danger.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(Nx.radiusSm),
    ),
    child: Text(message, style: const TextStyle(color: Nx.danger)),
  );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(appProvider.notifier).login(_email.text, _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Connexion',
    subtitle: 'Avec votre compte $kApiBase'.replaceFirst('https://', ''),
    children: [
      if (_error != null) ErrorBanner(_error!),
      TextField(
        controller: _email,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Adresse e-mail'),
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _password,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        decoration: const InputDecoration(labelText: 'Mot de passe'),
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Nx.bg,
                ),
              )
            : const Text('Se connecter'),
      ),
    ],
  );
}

class AddSourceScreen extends ConsumerStatefulWidget {
  const AddSourceScreen({super.key});

  @override
  ConsumerState<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends ConsumerState<AddSourceScreen> {
  SourceKind _kind = SourceKind.xtream;
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _m3u = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _server, _user, _pass, _m3u]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final xtream = _kind == SourceKind.xtream;
    if (xtream &&
        (_server.text.trim().isEmpty ||
            _user.text.trim().isEmpty ||
            _pass.text.isEmpty)) {
      setState(
        () => _error = 'Renseignez l’adresse du serveur, l’utilisateur et le mot de passe.',
      );
      return;
    }
    if (!xtream && _m3u.text.trim().isEmpty) {
      setState(() => _error = 'Renseignez l’URL de la playlist.');
      return;
    }
    final source = Source(
      id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim().isNotEmpty
          ? _name.text.trim()
          : (xtream ? _user.text.trim() : 'Playlist M3U'),
      kind: _kind,
      serverUrl: xtream ? XtreamContent.normalizeBase(_server.text) : null,
      username: xtream ? _user.text.trim() : null,
      password: xtream ? _pass.text : null,
      m3uUrl: xtream ? null : _m3u.text.trim(),
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      xtream
          ? await XtreamContent.verify(source)
          : await M3uContent.verify(source);
      await ref.read(appProvider.notifier).addSource(source);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final xtream = _kind == SourceKind.xtream;
    return FormPage(
      title: 'Ajouter une source',
      subtitle:
          'Les identifiants sont vérifiés auprès du serveur avant l’ajout.',
      children: [
        SegmentedButton<SourceKind>(
          segments: const [
            ButtonSegment(
              value: SourceKind.xtream,
              label: Text('Xtream'),
              icon: Icon(Icons.dns_rounded),
            ),
            ButtonSegment(
              value: SourceKind.m3u,
              label: Text('Playlist M3U'),
              icon: Icon(Icons.link_rounded),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() {
            _kind = s.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 20),
        if (_error != null) ErrorBanner(_error!),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nom (facultatif)'),
        ),
        const SizedBox(height: 14),
        if (xtream) ...[
          TextField(
            controller: _server,
            decoration: const InputDecoration(
              labelText: 'Adresse du serveur',
              hintText: 'http://exemple.com:8080',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'Utilisateur'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
            onSubmitted: (_) => _submit(),
          ),
        ] else
          TextField(
            controller: _m3u,
            decoration: const InputDecoration(
              labelText: 'URL de la playlist',
              hintText: 'http://…/get.php?username=…',
            ),
            onSubmitted: (_) => _submit(),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Nx.bg,
                  ),
                )
              : const Text('Vérifier et ajouter'),
        ),
      ],
    );
  }
}
