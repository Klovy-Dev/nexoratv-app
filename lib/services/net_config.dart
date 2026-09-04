import 'storage/settings_repository.dart';

/// User-Agent courant envoyé à tous les serveurs IPTV (playlist, Xtream, EPG).
///
/// Mis à jour par `SettingsNotifier` au chargement des réglages et à chaque
/// changement. Les clients HTTP le lisent à la **construction** ; ils sont
/// recréés au besoin (nouveau chargement de playlist), donc un changement
/// prend effet au prochain rafraîchissement.
String runtimeUserAgent = kDefaultUserAgent;
