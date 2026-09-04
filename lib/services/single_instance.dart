import 'dart:io';

import 'package:window_manager/window_manager.dart';

/// Empêche plusieurs fenêtres NexoraTV en même temps (important : beaucoup
/// d'abonnements Xtream n'autorisent qu'**une** connexion simultanée).
///
/// Mécanisme : un port local sert de verrou. La 2ᵉ instance s'y connecte pour
/// réveiller la 1ʳᵉ, puis quitte.
class SingleInstance {
  static const int _port = 47821;
  static ServerSocket? _server;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// `true` si on est la seule instance (on peut continuer le démarrage).
  static Future<bool> acquire() async {
    if (!_isDesktop) return true;
    try {
      _server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _port,
        shared: false,
      );
      _server!.listen((socket) async {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
        socket.destroy();
      });
      return true;
    } on SocketException {
      try {
        final s = await Socket.connect(
          InternetAddress.loopbackIPv4,
          _port,
          timeout: const Duration(seconds: 2),
        );
        s.destroy();
      } catch (_) {}
      return false;
    }
  }
}
