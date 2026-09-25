import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Format des flux en direct Xtream : MPEG-TS (défaut, le plus compatible)
/// ou HLS (.m3u8, utile quand un serveur coupe les flux TS).
enum LiveFormat { ts, hls }

class Settings {
  const Settings({
    this.liveFormat = LiveFormat.ts,
    this.bufferMb = 64,
    this.hardwareDecoding = true,
    this.startLiveFullscreen = false,
  });

  final LiveFormat liveFormat;

  /// Mémoire tampon du lecteur, en Mo.
  final int bufferMb;
  final bool hardwareDecoding;

  /// Passer en plein écran dès qu'on lance une chaîne.
  final bool startLiveFullscreen;

  Settings copyWith({LiveFormat? liveFormat, int? bufferMb, bool? hardwareDecoding, bool? startLiveFullscreen}) =>
      Settings(
        liveFormat: liveFormat ?? this.liveFormat,
        bufferMb: bufferMb ?? this.bufferMb,
        hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
        startLiveFullscreen: startLiveFullscreen ?? this.startLiveFullscreen,
      );
}

/// Préférences chargées avant le démarrage (voir main.dart).
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('prefsProvider non initialisé'));

class SettingsController extends Notifier<Settings> {
  static const _kFormat = 'live_format';
  static const _kBuffer = 'buffer_mb';
  static const _kHwdec = 'hardware_decoding';
  static const _kLiveFullscreen = 'live_fullscreen';

  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  Settings build() {
    final p = ref.read(prefsProvider);
    return Settings(
      liveFormat: p.getString(_kFormat) == 'hls' ? LiveFormat.hls : LiveFormat.ts,
      bufferMb: p.getInt(_kBuffer) ?? 64,
      hardwareDecoding: p.getBool(_kHwdec) ?? true,
      startLiveFullscreen: p.getBool(_kLiveFullscreen) ?? false,
    );
  }

  void setLiveFormat(LiveFormat v) {
    _prefs.setString(_kFormat, v.name);
    state = state.copyWith(liveFormat: v);
  }

  void setBufferMb(int v) {
    _prefs.setInt(_kBuffer, v);
    state = state.copyWith(bufferMb: v);
  }

  void setHardwareDecoding(bool v) {
    _prefs.setBool(_kHwdec, v);
    state = state.copyWith(hardwareDecoding: v);
  }

  void setStartLiveFullscreen(bool v) {
    _prefs.setBool(_kLiveFullscreen, v);
    state = state.copyWith(startLiveFullscreen: v);
  }

  Future<void> reset() async {
    for (final k in [_kFormat, _kBuffer, _kHwdec, _kLiveFullscreen]) {
      await _prefs.remove(k);
    }
    state = const Settings();
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(SettingsController.new);
