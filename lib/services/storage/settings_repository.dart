import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';

/// URL par défaut du manifeste de mise à jour (à héberger, ex. GitHub Releases).
const String kDefaultUpdateManifestUrl =
    'https://raw.githubusercontent.com/Klovy-Dev/nexoratv-app/main/update.json';

/// User-Agent par défaut envoyé aux serveurs IPTV.
const String kDefaultUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.cacheHours = 12,
    this.autoRefreshOnStart = false,
    this.showChannelNumbers = true,
    this.keepScreenAwake = true,
    this.checkUpdatesOnStart = true,
    this.updateManifestUrl = kDefaultUpdateManifestUrl,
    this.tmdbApiKey = '',
    this.subtitleScale = 1.0,
    this.epgEnabled = true,
    this.preloadEpg = false,
    this.mergeSimilarCategories = false,
    this.userAgent = '',
    this.playerBufferMb = 32,
    this.showWatchedRow = true,
    this.pauseOnBackground = true,
  });

  final AppThemeMode themeMode;
  final int cacheHours;
  final bool autoRefreshOnStart;
  final bool showChannelNumbers;
  final bool keepScreenAwake;
  final bool checkUpdatesOnStart;
  final String updateManifestUrl;

  /// Clé API TMDB (v3) — enrichit fiches films/séries avec affiches et notes.
  final String tmdbApiKey;

  /// Taille des sous-titres (0.6 → 1.8).
  final double subtitleScale;

  /// Récupérer le "en cours / à suivre" (EPG court Xtream).
  final bool epgEnabled;

  /// Télécharger le guide EPG complet dès l'ouverture de l'app.
  final bool preloadEpg;

  /// Fusionner « FR TV (SD) | FR TV (HD) | FR TV (4K) » → « FR TV ».
  final bool mergeSimilarCategories;

  /// User-Agent personnalisé (vide = [kDefaultUserAgent]).
  final String userAgent;

  /// Taille du tampon vidéo, en Mo (8 → 128). Plus grand = moins de coupures,
  /// plus de RAM et de latence au lancement.
  final int playerBufferMb;

  /// Afficher la rangée « Revoir » (films terminés) sur l'accueil.
  final bool showWatchedRow;

  /// Mettre la lecture en pause quand l'app passe en arrière-plan (protège les
  /// abonnements limités à une connexion simultanée).
  final bool pauseOnBackground;

  bool get hasTmdb => tmdbApiKey.trim().isNotEmpty;

  /// User-Agent effectif à envoyer aux serveurs.
  String get effectiveUserAgent =>
      userAgent.trim().isEmpty ? kDefaultUserAgent : userAgent.trim();

  AppSettings copyWith({
    AppThemeMode? themeMode,
    int? cacheHours,
    bool? autoRefreshOnStart,
    bool? showChannelNumbers,
    bool? keepScreenAwake,
    bool? checkUpdatesOnStart,
    String? updateManifestUrl,
    String? tmdbApiKey,
    double? subtitleScale,
    bool? epgEnabled,
    bool? preloadEpg,
    bool? mergeSimilarCategories,
    String? userAgent,
    int? playerBufferMb,
    bool? showWatchedRow,
    bool? pauseOnBackground,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        cacheHours: cacheHours ?? this.cacheHours,
        autoRefreshOnStart: autoRefreshOnStart ?? this.autoRefreshOnStart,
        showChannelNumbers: showChannelNumbers ?? this.showChannelNumbers,
        keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
        checkUpdatesOnStart: checkUpdatesOnStart ?? this.checkUpdatesOnStart,
        updateManifestUrl: updateManifestUrl ?? this.updateManifestUrl,
        tmdbApiKey: tmdbApiKey ?? this.tmdbApiKey,
        subtitleScale: subtitleScale ?? this.subtitleScale,
        epgEnabled: epgEnabled ?? this.epgEnabled,
        preloadEpg: preloadEpg ?? this.preloadEpg,
        mergeSimilarCategories:
            mergeSimilarCategories ?? this.mergeSimilarCategories,
        userAgent: userAgent ?? this.userAgent,
        playerBufferMb: playerBufferMb ?? this.playerBufferMb,
        showWatchedRow: showWatchedRow ?? this.showWatchedRow,
        pauseOnBackground: pauseOnBackground ?? this.pauseOnBackground,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'cacheHours': cacheHours,
        'autoRefreshOnStart': autoRefreshOnStart,
        'showChannelNumbers': showChannelNumbers,
        'keepScreenAwake': keepScreenAwake,
        'checkUpdatesOnStart': checkUpdatesOnStart,
        'updateManifestUrl': updateManifestUrl,
        'tmdbApiKey': tmdbApiKey,
        'subtitleScale': subtitleScale,
        'epgEnabled': epgEnabled,
        'preloadEpg': preloadEpg,
        'mergeSimilarCategories': mergeSimilarCategories,
        'userAgent': userAgent,
        'playerBufferMb': playerBufferMb,
        'showWatchedRow': showWatchedRow,
        'pauseOnBackground': pauseOnBackground,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    return AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (m) => m.name == j['themeMode'],
        orElse: () => d.themeMode,
      ),
      cacheHours: j['cacheHours'] as int? ?? d.cacheHours,
      autoRefreshOnStart:
          j['autoRefreshOnStart'] as bool? ?? d.autoRefreshOnStart,
      showChannelNumbers:
          j['showChannelNumbers'] as bool? ?? d.showChannelNumbers,
      keepScreenAwake: j['keepScreenAwake'] as bool? ?? d.keepScreenAwake,
      checkUpdatesOnStart:
          j['checkUpdatesOnStart'] as bool? ?? d.checkUpdatesOnStart,
      updateManifestUrl:
          j['updateManifestUrl'] as String? ?? d.updateManifestUrl,
      tmdbApiKey: j['tmdbApiKey'] as String? ?? d.tmdbApiKey,
      subtitleScale: (j['subtitleScale'] as num?)?.toDouble() ?? d.subtitleScale,
      epgEnabled: j['epgEnabled'] as bool? ?? d.epgEnabled,
      preloadEpg: j['preloadEpg'] as bool? ?? d.preloadEpg,
      mergeSimilarCategories:
          j['mergeSimilarCategories'] as bool? ?? d.mergeSimilarCategories,
      userAgent: j['userAgent'] as String? ?? d.userAgent,
      playerBufferMb:
          (j['playerBufferMb'] as int? ?? d.playerBufferMb).clamp(8, 128),
      showWatchedRow: j['showWatchedRow'] as bool? ?? d.showWatchedRow,
      pauseOnBackground:
          j['pauseOnBackground'] as bool? ?? d.pauseOnBackground,
    );
  }
}

class SettingsRepository {
  /// Tous les réglages dans **une seule** clé JSON. Sur Windows,
  /// `shared_preferences` réécrit l'intégralité du fichier de prefs à chaque
  /// `set*` : avec l'ancien schéma (16 clés séparées), une seule bascule
  /// déclenchait 16 écritures disque successives et figeait l'UI une ou
  /// deux secondes (« Non répondant »). Une seule clé = une seule écriture.
  static const _blob = 'settings_json';

  // Anciennes clés (schéma < 2026-09-04), lues une fois pour migrer.
  static const _legacyKeys = <String>[
    'set_theme_mode', 'set_cache_hours', 'set_auto_refresh',
    'set_show_numbers', 'set_keep_awake', 'set_check_updates',
    'set_update_url', 'set_tmdb_key', 'set_sub_scale', 'set_epg',
    'set_preload_epg', 'set_merge_cats', 'set_user_agent', 'set_buffer_mb',
    'set_watched_row', 'set_pause_bg',
  ];

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_blob);
    if (raw != null) {
      try {
        return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Blob corrompu : repli sur les valeurs par défaut.
      }
    }

    // Migration depuis l'ancien schéma « une clé par réglage ».
    final migrated = AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (m) => m.name == p.getString('set_theme_mode'),
        orElse: () => AppThemeMode.dark,
      ),
      cacheHours: p.getInt('set_cache_hours') ?? 12,
      autoRefreshOnStart: p.getBool('set_auto_refresh') ?? false,
      showChannelNumbers: p.getBool('set_show_numbers') ?? true,
      keepScreenAwake: p.getBool('set_keep_awake') ?? true,
      checkUpdatesOnStart: p.getBool('set_check_updates') ?? true,
      updateManifestUrl:
          p.getString('set_update_url') ?? kDefaultUpdateManifestUrl,
      tmdbApiKey: p.getString('set_tmdb_key') ?? '',
      subtitleScale: p.getDouble('set_sub_scale') ?? 1.0,
      epgEnabled: p.getBool('set_epg') ?? true,
      preloadEpg: p.getBool('set_preload_epg') ?? false,
      mergeSimilarCategories: p.getBool('set_merge_cats') ?? false,
      userAgent: p.getString('set_user_agent') ?? '',
      playerBufferMb: (p.getInt('set_buffer_mb') ?? 32).clamp(8, 128),
      showWatchedRow: p.getBool('set_watched_row') ?? true,
      pauseOnBackground: p.getBool('set_pause_bg') ?? true,
    );
    await save(migrated);
    for (final k in _legacyKeys) {
      unawaited(p.remove(k));
    }
    return migrated;
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_blob, jsonEncode(s.toJson()));
  }
}
