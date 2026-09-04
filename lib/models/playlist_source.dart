import 'package:uuid/uuid.dart';

/// Type de source IPTV gérée par l'application.
enum SourceKind { m3uUrl, xtream }

/// Format de sortie demandé au serveur Xtream pour les flux en direct.
/// `ts` est le plus compatible, `m3u8` (HLS) permet un meilleur buffering.
enum XtreamOutput { ts, m3u8 }

/// Une source enregistrée : soit une playlist M3U (via URL), soit un compte
/// Xtream Codes (host + identifiant + mot de passe).
class PlaylistSource {
  PlaylistSource({
    String? id,
    required this.name,
    required this.kind,
    this.m3uUrl,
    this.epgUrl,
    this.host,
    this.username,
    this.password,
    this.xtreamOutput = XtreamOutput.ts,
    this.activationMac,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final SourceKind kind;

  /// Renseigné quand [kind] == [SourceKind.m3uUrl].
  final String? m3uUrl;
  final String? epgUrl;

  /// Renseignés quand [kind] == [SourceKind.xtream].
  /// [host] inclut le schéma et le port, ex. `http://exemple.com:8080`.
  final String? host;
  final String? username;
  final String? password;
  final XtreamOutput xtreamOutput;

  /// Non nul si cette source (M3U) a été ajoutée via activation par adresse
  /// MAC (`AddSourceScreen`, onglet MAC) : `m3uUrl`/`epgUrl` sont alors
  /// re-résolus auprès du portail à chaque chargement, cf.
  /// `PlaylistService.load`.
  final String? activationMac;

  final DateTime createdAt;

  bool get isXtream => kind == SourceKind.xtream;
  bool get isMacActivated => activationMac != null;

  PlaylistSource copyWith({
    String? name,
    String? m3uUrl,
    String? epgUrl,
    String? host,
    String? username,
    String? password,
    XtreamOutput? xtreamOutput,
    String? activationMac,
  }) {
    return PlaylistSource(
      id: id,
      name: name ?? this.name,
      kind: kind,
      m3uUrl: m3uUrl ?? this.m3uUrl,
      epgUrl: epgUrl ?? this.epgUrl,
      host: host ?? this.host,
      username: username ?? this.username,
      password: password ?? this.password,
      xtreamOutput: xtreamOutput ?? this.xtreamOutput,
      activationMac: activationMac ?? this.activationMac,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'm3uUrl': m3uUrl,
        'epgUrl': epgUrl,
        'host': host,
        'username': username,
        'password': password,
        'xtreamOutput': xtreamOutput.name,
        'activationMac': activationMac,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Si [url] est un lien Xtream `.../get.php?username=..&password=..`,
  /// extrait `host`, `username`, `password` ; sinon `null`.
  static ({String host, String username, String password})? parseXtreamGetUrl(
      String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return null;
    if (!uri.path.toLowerCase().contains('get.php')) return null;
    final user = uri.queryParameters['username'];
    final pass = uri.queryParameters['password'];
    if (user == null || user.isEmpty || pass == null || pass.isEmpty) {
      return null;
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    return (
      host: '${uri.scheme}://${uri.host}$port',
      username: user,
      password: pass,
    );
  }

  /// Convertit une source « lien M3U » en source Xtream si l'URL est en fait
  /// un lien `get.php` Xtream. Sinon renvoie la source inchangée.
  PlaylistSource upgradedToXtreamIfPossible() {
    if (kind != SourceKind.m3uUrl || m3uUrl == null) return this;
    final x = parseXtreamGetUrl(m3uUrl!);
    if (x == null) return this;
    final lower = m3uUrl!.toLowerCase();
    final out = (lower.contains('output=hls') || lower.contains('m3u8'))
        ? XtreamOutput.m3u8
        : XtreamOutput.ts;
    return PlaylistSource(
      id: id,
      name: name,
      kind: SourceKind.xtream,
      host: x.host,
      username: x.username,
      password: x.password,
      xtreamOutput: out,
      epgUrl: epgUrl,
      activationMac: activationMac,
      createdAt: createdAt,
    );
  }

  factory PlaylistSource.fromJson(Map<String, dynamic> json) {
    return PlaylistSource(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Sans nom',
      kind: SourceKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => SourceKind.m3uUrl,
      ),
      m3uUrl: json['m3uUrl'] as String?,
      epgUrl: json['epgUrl'] as String?,
      host: json['host'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      xtreamOutput: XtreamOutput.values.firstWhere(
        (o) => o.name == json['xtreamOutput'],
        orElse: () => XtreamOutput.ts,
      ),
      activationMac: json['activationMac'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}
