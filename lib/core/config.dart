/// Adresse du site NexoraTV (connexion au compte, abonnements).
///
/// En développement, pointer sur le site local :
///   flutter run -d windows --dart-define=API_BASE=http://localhost:3000
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://nexoratv.fr',
);

const String kUserAgent = 'NexoraTV/2.0';
