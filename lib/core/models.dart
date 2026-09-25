enum SourceKind { xtream, m3u }

/// Une source de contenu : abonnement du compte NexoraTV (Xtream) ou source
/// ajoutée à la main (Xtream ou URL M3U).
class Source {
  const Source({
    required this.id,
    required this.name,
    required this.kind,
    this.serverUrl,
    this.username,
    this.password,
    this.m3uUrl,
    this.fromAccount = false,
    this.expiresAt,
    this.active = true,
  });

  final String id;
  final String name;
  final SourceKind kind;
  final String? serverUrl;
  final String? username;
  final String? password;
  final String? m3uUrl;

  /// Abonnement récupéré depuis le compte NexoraTV (géré automatiquement).
  final bool fromAccount;
  final String? expiresAt;

  /// Faux si l'abonnement est expiré ou suspendu.
  final bool active;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'm3uUrl': m3uUrl,
    'fromAccount': fromAccount,
    'expiresAt': expiresAt,
    'active': active,
  };

  factory Source.fromJson(Map<String, Object?> j) => Source(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Source',
    kind: j['kind'] == 'm3u' ? SourceKind.m3u : SourceKind.xtream,
    serverUrl: j['serverUrl'] as String?,
    username: j['username'] as String?,
    password: j['password'] as String?,
    m3uUrl: j['m3uUrl'] as String?,
    fromAccount: j['fromAccount'] as bool? ?? false,
    expiresAt: j['expiresAt'] as String?,
    active: j['active'] as bool? ?? true,
  );

  /// Deux sources identiques pointent vers le même contenu.
  @override
  bool operator ==(Object other) =>
      other is Source &&
      other.id == id &&
      other.kind == kind &&
      other.serverUrl == serverUrl &&
      other.username == username &&
      other.password == password &&
      other.m3uUrl == m3uUrl;

  @override
  int get hashCode =>
      Object.hash(id, kind, serverUrl, username, password, m3uUrl);
}

class Category {
  const Category(this.id, this.name);
  final String id;
  final String name;
}

class LiveChannel {
  const LiveChannel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.url,
    this.logo,
    this.number,
  });

  final String id;
  final String name;
  final String categoryId;
  final String url;
  final String? logo;
  final int? number;
}

class Movie {
  const Movie({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.url,
    this.poster,
    this.rating,
    this.year,
  });

  final String id;
  final String name;
  final String categoryId;
  final String url;
  final String? poster;
  final double? rating;
  final String? year;
}

class MovieDetails {
  const MovieDetails({
    this.plot,
    this.genre,
    this.cast,
    this.director,
    this.duration,
    this.releaseDate,
    this.backdrop,
  });

  final String? plot;
  final String? genre;
  final String? cast;
  final String? director;
  final String? duration;
  final String? releaseDate;
  final String? backdrop;
}

class Series {
  const Series({
    required this.id,
    required this.name,
    required this.categoryId,
    this.cover,
    this.plot,
    this.rating,
    this.year,
    this.episodes,
  });

  final String id;
  final String name;
  final String categoryId;
  final String? cover;
  final String? plot;
  final double? rating;
  final String? year;

  /// Sources M3U : épisodes déjà connus (Xtream : chargés à la demande).
  final List<Episode>? episodes;
}

class Season {
  const Season(this.number, this.episodes);
  final int number;
  final List<Episode> episodes;
}

class Episode {
  const Episode({
    required this.id,
    required this.title,
    required this.season,
    required this.number,
    required this.url,
    this.plot,
    this.image,
    this.duration,
  });

  final String id;
  final String title;
  final int season;
  final int number;
  final String url;
  final String? plot;
  final String? image;
  final String? duration;
}

/* ---------- Compte NexoraTV ---------- */

class AccountUser {
  const AccountUser(this.name, this.email);
  final String name;
  final String email;
}

class AccountSubscription {
  const AccountSubscription({
    required this.id,
    required this.label,
    required this.playable,
    required this.active,
    this.serverUrl,
    this.username,
    this.password,
    this.expiresAt,
  });

  factory AccountSubscription.fromJson(Map<String, Object?> j) =>
      AccountSubscription(
        id: (j['id'] as num).toInt(),
        label: j['label'] as String? ?? 'Abonnement',
        playable: j['playable'] == true,
        active: j['active'] == true,
        serverUrl: j['serverUrl'] as String?,
        username: j['username'] as String?,
        password: j['password'] as String?,
        expiresAt: j['expiresAt'] as String?,
      );

  final int id;
  final String label;
  final bool playable;
  final bool active;
  final String? serverUrl;
  final String? username;
  final String? password;
  final String? expiresAt;

  Source toSource() => Source(
    id: 'account-$id',
    name: label,
    kind: SourceKind.xtream,
    serverUrl: serverUrl,
    username: username,
    password: password,
    fromAccount: true,
    expiresAt: expiresAt,
    active: active,
  );
}
