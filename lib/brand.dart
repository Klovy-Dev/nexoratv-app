/// Liens officiels NexoraTV (site, réseaux, support).
class Brand {
  static const site = 'https://nexoratv.fr';
  static const contact = 'https://nexoratv.fr/contact';
  static const avis = 'https://nexoratv.fr/avis';

  /// WhatsApp support : +33 6 51 44 68 69.
  static const whatsapp = 'https://wa.me/33651446869';
  static const whatsappLabel = '+33 6 51 44 68 69';

  /// Canal Telegram.
  static const telegram = 'https://t.me/tvnexora';
  static const telegramLabel = '@tvnexora';

  /// Endpoint JSON des avis clients (route Next.js du site).
  /// `{ "count": 12, "average": 4.9, "reviews": [ { "author", "rating",
  ///    "date", "text" } ] }`
  static const avisEndpoint = 'https://nexoratv.fr/api/avis';

  /// Portail MAC : `GET playlistApi?mac=AA:BB:CC:DD:EE:FF` renvoie
  /// `{ "name", "m3uUrl", "epgUrl" }` si le MAC est activé (404 sinon).
  static const playlistApi = 'https://nexoratv.fr/api/playlist';
}
