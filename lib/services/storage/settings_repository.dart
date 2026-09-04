import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';

/// URL par défaut du manifeste de mise à jour (à héberger, ex. GitHub Releases).
const String kDefaultUpdateManifestUrl =
    'https://raw.githubusercontent.com/klovy/nexoratv-app/main/update.json';

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
}

class SettingsRepository {
  static const _themeMode = 'set_theme_mode';
  static const _cacheHours = 'set_cache_hours';
  static const _autoRefresh = 'set_auto_refresh';
  static const _showNumbers = 'set_show_numbers';
  static const _keepAwake = 'set_keep_awake';
  static const _checkUpdates = 'set_check_updates';
  static const _updateUrl = 'set_update_url';
  static const _tmdbKey = 'set_tmdb_key';
  static const _subScale = 'set_sub_scale';
  static const _epg = 'set_epg';
  static const _preloadEpg = 'set_preload_epg';
  static const _mergeCats = 'set_merge_cats';
  static const _userAgent = 'set_user_agent';
  static const _bufferMb = 'set_buffer_mb';
  static const _watchedRow = 'set_watched_row';
  static const _pauseBg = 'set_pause_bg';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (m) => m.name == p.getString(_themeMode),
        orElse: () => AppThemeMode.dark,
      ),
      cacheHours: p.getInt(_cacheHours) ?? 12,
      autoRefreshOnStart: p.getBool(_autoRefresh) ?? false,
      showChannelNumbers: p.getBool(_showNumbers) ?? true,
      keepScreenAwake: p.getBool(_keepAwake) ?? true,
      checkUpdatesOnStart: p.getBool(_checkUpdates) ?? true,
      updateManifestUrl: p.getString(_updateUrl) ?? kDefaultUpdateManifestUrl,
      tmdbApiKey: p.getString(_tmdbKey) ?? '',
      subtitleScale: p.getDouble(_subScale) ?? 1.0,
      epgEnabled: p.getBool(_epg) ?? true,
      preloadEpg: p.getBool(_preloadEpg) ?? false,
      mergeSimilarCategories: p.getBool(_mergeCats) ?? false,
      userAgent: p.getString(_userAgent) ?? '',
      playerBufferMb: (p.getInt(_bufferMb) ?? 32).clamp(8, 128),
      showWatchedRow: p.getBool(_watchedRow) ?? true,
      pauseOnBackground: p.getBool(_pauseBg) ?? true,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_themeMode, s.themeMode.name);
    await p.setInt(_cacheHours, s.cacheHours);
    await p.setBool(_autoRefresh, s.autoRefreshOnStart);
    await p.setBool(_showNumbers, s.showChannelNumbers);
    await p.setBool(_keepAwake, s.keepScreenAwake);
    await p.setBool(_checkUpdates, s.checkUpdatesOnStart);
    await p.setString(_updateUrl, s.updateManifestUrl);
    await p.setString(_tmdbKey, s.tmdbApiKey);
    await p.setDouble(_subScale, s.subtitleScale);
    await p.setBool(_epg, s.epgEnabled);
    await p.setBool(_preloadEpg, s.preloadEpg);
    await p.setBool(_mergeCats, s.mergeSimilarCategories);
    await p.setString(_userAgent, s.userAgent);
    await p.setInt(_bufferMb, s.playerBufferMb);
    await p.setBool(_watchedRow, s.showWatchedRow);
    await p.setBool(_pauseBg, s.pauseOnBackground);
  }
}
