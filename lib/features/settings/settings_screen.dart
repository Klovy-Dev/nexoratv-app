import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../brand.dart';
import '../../services/storage/settings_repository.dart';
import '../../services/update_service.dart';
import '../../state/account_provider.dart';
import '../../state/channels_provider.dart';
import '../../state/providers.dart';
import '../../state/settings_provider.dart';
import '../../state/sources_provider.dart';
import '../../state/tmdb_provider.dart';
import '../../state/update_provider.dart';
import '../../state/watch_history_provider.dart';
import '../../theme.dart';
import '../../widgets/account_info_card.dart';
import '../../widgets/nav.dart';
import '../categories/manage_categories_screen.dart';
import '../epg/epg_screen.dart';
import '../parental/parental_screen.dart';
import '../sources/sources_screen.dart';
import '../update/update_dialog.dart';

/// Accueil des Paramètres : un hub qui ouvre des sous-pages (façon Zen Player).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          _NavTile(
            icon: Icons.dns_outlined,
            title: 'Vos sources IPTV',
            subtitle: 'Ajouter, modifier, rafraîchir',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SourcesScreen()),
            ),
          ),
          _NavTile(
            icon: Icons.tune,
            title: 'Réglages IPTV',
            subtitle: 'Cache, EPG, catégories, User-Agent',
            onTap: () => pushFade(context, const _IptvSettingsPage()),
          ),
          _NavTile(
            icon: Icons.palette_outlined,
            title: 'Interface',
            subtitle: 'Thème, rangées de l\'accueil',
            onTap: () => pushFade(context, const _InterfacePage()),
          ),
          _NavTile(
            icon: Icons.play_circle_outline,
            title: 'Lecteur vidéo',
            subtitle: 'Tampon, sous-titres, veille',
            onTap: () => pushFade(context, const _PlayerSettingsPage()),
          ),
          _NavTile(
            icon: Icons.devices_other_outlined,
            title: 'Protection multi-écran',
            subtitle: 'Éviter de saturer les connexions',
            onTap: () => pushFade(context, const _MultiScreenPage()),
          ),
          _NavTile(
            icon: Icons.shield_outlined,
            title: 'Guide & contrôle parental',
            subtitle: 'Guide des programmes, code PIN',
            onTap: () => pushFade(context, const _GuideSecurityPage()),
          ),
          _NavTile(
            icon: Icons.system_update_alt,
            title: 'Mises à jour',
            onTap: () => pushFade(context, const _UpdatesPage()),
          ),

          const _SectionTitle('Abonnement'),
          Consumer(
            builder: (context, ref, _) =>
                AccountInfoCard(async: ref.watch(accountInfoProvider)),
          ),

          const _SectionTitle('Aide'),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('Contacter le support'),
            subtitle: const Text('Bug, question ou suggestion'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(Brand.contact),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('WhatsApp'),
            subtitle: const Text(Brand.whatsappLabel),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(Brand.whatsapp),
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Telegram'),
            subtitle: const Text(Brand.telegramLabel),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(Brand.telegram),
          ),

          const _SectionTitle('Autres'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Confidentialité'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushFade(context, const _PrivacyPage()),
          ),

          const _SectionTitle('À propos'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('NexoraTV'),
            subtitle: Text('Version ${version ?? '…'}'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// ─────────────────────────── Réglages IPTV ───────────────────────────

class _IptvSettingsPage extends ConsumerWidget {
  const _IptvSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsValueProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages IPTV')),
      body: ListView(
        children: [
          const _SectionTitle('Mise à jour du contenu'),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Validité du cache'),
            subtitle:
                Text('${s.cacheHours} h avant re-téléchargement de la playlist'),
            trailing: DropdownButton<int>(
              value: s.cacheHours,
              items: const [1, 3, 6, 12, 24, 48]
                  .map((h) =>
                      DropdownMenuItem(value: h, child: Text('$h h')))
                  .toList(),
              onChanged: (v) =>
                  notifier.patch((o) => o.copyWith(cacheHours: v ?? o.cacheHours)),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.refresh),
            title: const Text('Rafraîchir à chaque démarrage'),
            value: s.autoRefreshOnStart,
            onChanged: (v) =>
                notifier.patch((o) => o.copyWith(autoRefreshOnStart: v)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Vider le cache maintenant'),
            subtitle: const Text('Force le rechargement complet'),
            onTap: () => _clearCache(context, ref),
          ),

          const _SectionTitle('Catégories'),
          SwitchListTile(
            secondary: const Icon(Icons.merge_type),
            title: const Text('Fusionner les catégories similaires'),
            subtitle: const Text(
                'FR TV (SD) | FR TV (HD) | FR TV 4K  →  FR TV\n'
                'Prend effet immédiatement.'),
            isThreeLine: true,
            value: s.mergeSimilarCategories,
            onChanged: (v) =>
                notifier.patch((o) => o.copyWith(mergeSimilarCategories: v)),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Masquer / renommer des catégories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushFade(context, const ManageCategoriesScreen()),
          ),

          const _SectionTitle('EPG'),
          SwitchListTile(
            secondary: const Icon(Icons.calendar_view_day_outlined),
            title: const Text('Activer l\'EPG'),
            subtitle: const Text('Programme en cours sur les chaînes'),
            value: s.epgEnabled,
            onChanged: (v) => notifier.patch((o) => o.copyWith(epgEnabled: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bolt_outlined),
            title: const Text('Précharger l\'EPG'),
            subtitle: const Text(
                'Télécharge le guide complet dès l\'ouverture de l\'app'),
            value: s.preloadEpg,
            onChanged: s.epgEnabled
                ? (v) => notifier.patch((o) => o.copyWith(preloadEpg: v))
                : null,
          ),

          const _SectionTitle('Réseau'),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('User-Agent'),
            subtitle: Text(
              s.userAgent.trim().isEmpty
                  ? 'Par défaut ($kDefaultUserAgent)'
                  : s.userAgent,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _editText(
              context,
              'User-Agent (vide = par défaut)',
              s.userAgent,
              (v) => notifier.patch((o) => o.copyWith(userAgent: v)),
            ),
          ),

          const _SectionTitle('Fiches (TMDB)'),
          ListTile(
            leading: const Icon(Icons.movie_filter_outlined),
            title: const Text('Clé API TMDB'),
            subtitle: Text(s.hasTmdb
                ? 'Configurée · ${s.tmdbApiKey.substring(0, 6)}…'
                : 'Non configurée — affiches, synopsis et notes enrichis'),
            onTap: () => _editText(
              context,
              'Clé API TMDB (v3)',
              s.tmdbApiKey,
              (v) => notifier.patch((o) => o.copyWith(tmdbApiKey: v)),
            ),
          ),
          if (s.hasTmdb)
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Tester la clé'),
              onTap: () => _testTmdb(context, ref, s.tmdbApiKey),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final source = ref.read(selectedSourceProvider);
    for (final src
        in ref.read(sourcesProvider).value?.sources ?? const []) {
      await ref.read(playlistCacheProvider).clear(src.id);
    }
    if (source != null) {
      ref.invalidate(playlistForSourceProvider(source.id));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cache vidé.')));
    }
  }

  Future<void> _testTmdb(
      BuildContext context, WidgetRef ref, String key) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Test en cours…')));
    final meta = await ref.read(tmdbServiceProvider).lookup(
          apiKey: key,
          title: 'The Matrix',
          year: 1999,
          isSeries: false,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(meta?.overview != null
          ? '✓ Clé valide (note TMDB Matrix : '
              '${meta!.rating?.toStringAsFixed(1) ?? '?'})'
          : '✗ Clé invalide ou pas de réseau'),
    ));
  }
}

/// ─────────────────────────── Interface ───────────────────────────

class _InterfacePage extends ConsumerWidget {
  const _InterfacePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsValueProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Interface')),
      body: ListView(
        children: [
          const _SectionTitle('Thème'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _ThemePicker(
              selected: s.themeMode,
              onSelected: (m) =>
                  notifier.patch((o) => o.copyWith(themeMode: m)),
            ),
          ),

          const _SectionTitle('Accueil & listes'),
          SwitchListTile(
            secondary: const Icon(Icons.replay_outlined),
            title: const Text('Rangée « Revoir »'),
            subtitle: const Text('Films et épisodes déjà terminés'),
            value: s.showWatchedRow,
            onChanged: (v) =>
                notifier.patch((o) => o.copyWith(showWatchedRow: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.pin_outlined),
            title: const Text('Numéros de chaîne'),
            value: s.showChannelNumbers,
            onChanged: (v) =>
                notifier.patch((o) => o.copyWith(showChannelNumbers: v)),
          ),

          const _SectionTitle('Historique'),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Effacer l\'historique de lecture'),
            onTap: () async {
              await ref.read(watchHistoryProvider.notifier).clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historique effacé.')),
                );
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// ─────────────────────────── Lecteur vidéo ───────────────────────────

class _PlayerSettingsPage extends ConsumerWidget {
  const _PlayerSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsValueProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Lecteur vidéo')),
      body: ListView(
        children: [
          const _SectionTitle('Tampon'),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('Taille du tampon vidéo'),
            subtitle: Text(
              '${s.playerBufferMb} Mo — plus grand = moins de coupures, '
              'mais plus de RAM et un lancement un peu plus lent.\n'
              'Effet au prochain lancement de lecture.',
            ),
            isThreeLine: true,
          ),
          Slider(
            value: s.playerBufferMb.toDouble().clamp(8, 128),
            min: 8,
            max: 128,
            divisions: 15,
            label: '${s.playerBufferMb} Mo',
            onChanged: (v) =>
                notifier.patch((o) => o.copyWith(playerBufferMb: v.round())),
          ),

          const _SectionTitle('Sous-titres'),
          ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: const Text('Taille des sous-titres'),
            subtitle: Text('${(s.subtitleScale * 100).round()} %'),
          ),
          Slider(
            value: s.subtitleScale,
            min: 0.6,
            max: 1.8,
            divisions: 12,
            label: '${(s.subtitleScale * 100).round()} %',
            onChanged: (v) =>
                notifier.patch((o) => o.copyWith(subtitleScale: v)),
          ),

          const _SectionTitle('Écran'),
          SwitchListTile(
            secondary: const Icon(Icons.brightness_high_outlined),
            title: const Text('Empêcher la mise en veille'),
            subtitle: const Text('Pendant la lecture'),
            value: s.keepScreenAwake,
            onChanged: (v) =>
                notifier.patch((o) => o.copyWith(keepScreenAwake: v)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// ─────────────────────── Guide & contrôle parental ───────────────────────

class _GuideSecurityPage extends StatelessWidget {
  const _GuideSecurityPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guide & contrôle parental')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Guide des programmes (EPG)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushFade(context, const EpgScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Contrôle parental'),
            subtitle: const Text('Code PIN, catégories verrouillées'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushFade(context, const ParentalScreen()),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────── Mises à jour ───────────────────────────

class _UpdatesPage extends ConsumerWidget {
  const _UpdatesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsValueProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Mises à jour')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.system_update_alt),
            title: const Text('Vérifier au démarrage'),
            value: s.checkUpdatesOnStart,
            onChanged: (v) =>
                notifier.patch((o) => o.copyWith(checkUpdatesOnStart: v)),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Vérifier maintenant'),
            onTap: () => _checkNow(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _checkNow(BuildContext context, WidgetRef ref) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    UpdateInfo? info;
    try {
      info = await ref.read(manualUpdateCheckProvider.future);
    } catch (_) {
      info = null;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (info != null) {
      await UpdateDialog.show(context, info);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune mise à jour disponible.')),
      );
    }
  }
}

/// ─────────────────────────── Commun ───────────────────────────

final appVersionProvider = FutureProvider<String>(
    (ref) => ref.read(updateServiceProvider).currentVersion());

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// ─────────────────────── Protection multi-écran ───────────────────────

class _MultiScreenPage extends ConsumerWidget {
  const _MultiScreenPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsValueProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Protection multi-écran')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Beaucoup d\'abonnements n\'autorisent qu\'une seule lecture à la '
              'fois. Ces options évitent que NexoraTV occupe une connexion '
              'pour rien.',
              style: TextStyle(height: 1.4),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.pause_circle_outline),
            title: const Text('Pause en arrière-plan'),
            subtitle: const Text(
                'Met la lecture en pause quand tu quittes l\'app ou éteins '
                'l\'écran, pour libérer la connexion.'),
            isThreeLine: true,
            value: s.pauseOnBackground,
            onChanged: (v) =>
                notifier.patch((o) => o.copyWith(pauseOnBackground: v)),
          ),
          const ListTile(
            leading: Icon(Icons.desktop_windows_outlined),
            title: Text('Fenêtre unique (ordinateur)'),
            subtitle: Text(
                'Sur Windows, une seule fenêtre NexoraTV peut être ouverte : '
                'lancer l\'app une 2ᵉ fois réactive la fenêtre existante. '
                'Toujours actif.'),
            isThreeLine: true,
            trailing: Icon(Icons.check_circle, color: Colors.green),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────── Confidentialité ───────────────────────────

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confidentialité')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text('En résumé', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 8),
          Text(
            'NexoraTV ne collecte rien et n\'envoie aucune donnée à ses '
            'développeurs. Aucun compte, aucun traçage, aucune publicité.',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 20),
          Text('Ce qui reste sur l\'appareil',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 8),
          Text(
            '• Tes sources IPTV et leurs identifiants (le mot de passe Xtream '
            'est chiffré par le système).\n'
            '• Le cache des chaînes/films/séries, tes favoris, ton historique '
            'de lecture et tes préférences.\n'
            'Tout est supprimé si tu désinstalles l\'app ou vides ses données.',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 20),
          Text('Connexions réseau', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 8),
          Text(
            '• Tes serveurs IPTV : pour récupérer les chaînes et lire les flux.\n'
            '• TMDB (themoviedb.org) : uniquement si tu renseignes une clé API, '
            'pour les affiches et synopsis.\n'
            '• GitHub : pour vérifier les mises à jour de l\'app.',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}

Future<void> _editText(
  BuildContext context,
  String title,
  String current,
  void Function(String) onSave,
) async {
  final controller = TextEditingController(text: current);
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  if (result != null) onSave(result);
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

/// Sélecteur de thème : Sombre · Clair · « Bientôt disponible » (verrouillé,
/// réservé au futur thème premium).
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.selected, required this.onSelected});

  final AppThemeMode selected;
  final ValueChanged<AppThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget pill({
      required String label,
      IconData? icon,
      bool active = false,
      bool locked = false,
      VoidCallback? onTap,
    }) {
      return Expanded(
        child: Opacity(
          opacity: locked ? .5 : 1,
          child: Material(
            color: active
                ? scheme.primary.withValues(alpha: .22)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Icon(icon,
                        size: 18,
                        color: active ? scheme.primary : null),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? scheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(
          label: 'Sombre',
          icon: Icons.dark_mode_outlined,
          active: selected == AppThemeMode.dark,
          onTap: () => onSelected(AppThemeMode.dark),
        ),
        const SizedBox(width: 8),
        pill(
          label: 'Clair',
          icon: Icons.light_mode_outlined,
          active: selected == AppThemeMode.light,
          onTap: () => onSelected(AppThemeMode.light),
        ),
        const SizedBox(width: 8),
        pill(
          label: 'Bientôt\ndisponible',
          icon: Icons.lock_outline,
          locked: true,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Un thème premium arrive bientôt.'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}
