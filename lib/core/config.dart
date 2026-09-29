/// Adresse du site NexoraTV (connexion au compte, abonnements).
///
/// En développement, pointer sur le site local :
///   flutter run -d windows --dart-define=API_BASE=http://localhost:3000
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://nexoratv.fr',
);

const String kUserAgent = 'NexoraTV/2.0';

/// Manifeste des mises à jour (même format que celui que lit le site :
/// un bloc `windows` / `android` avec version, url, notes, mandatory).
/// Même dépôt que la 1.x (la 2.0 y vit sur la branche v2) : les appareils
/// déjà installés et la nouvelle appli lisent le même manifeste.
const String kUpdateManifestUrl =
    'https://raw.githubusercontent.com/Klovy-Dev/nexoratv-app/main/update.json';

/// Liens communauté (les mêmes que lib/community-links.ts sur le site).
const String kSiteUrl = 'https://nexoratv.fr';
const String kDiscordUrl = 'https://discord.gg/nexoratv';
const String kTelegramUrl = 'https://t.me/m/G9y58nUFZTE0';
