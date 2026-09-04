import 'package:dio/dio.dart';

/// Métadonnées enrichies d'un titre (via TMDB).
class TmdbMeta {
  const TmdbMeta({
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.rating,
    this.year,
    this.genres,
  });

  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
  final double? rating;
  final int? year;
  final String? genres;
}

/// Client TMDB (API v3) minimal : recherche par titre puis récupération des
/// détails. Ne lève jamais : renvoie `null` en cas de problème.
class TmdbService {
  TmdbService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.themoviedb.org/3',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 12),
            ));

  final Dio _dio;
  static const _img = 'https://image.tmdb.org/t/p';

  Future<TmdbMeta?> lookup({
    required String apiKey,
    required String title,
    int? year,
    required bool isSeries,
  }) async {
    if (apiKey.trim().isEmpty || title.trim().isEmpty) return null;
    try {
      final path = isSeries ? '/search/tv' : '/search/movie';
      final res = await _dio.get<Map<String, dynamic>>(path, queryParameters: {
        'api_key': apiKey.trim(),
        'query': _clean(title),
        'language': 'fr-FR',
        (isSeries ? 'first_air_date_year' : 'year'): ?year,
      });
      final results = (res.data?['results'] as List?) ?? const [];
      if (results.isEmpty) return null;
      final m = results.first as Map<String, dynamic>;
      final date = '${m['release_date'] ?? m['first_air_date'] ?? ''}';
      return TmdbMeta(
        overview: _nn('${m['overview'] ?? ''}'),
        posterUrl: m['poster_path'] == null
            ? null
            : '$_img/w500${m['poster_path']}',
        backdropUrl: m['backdrop_path'] == null
            ? null
            : '$_img/w1280${m['backdrop_path']}',
        rating: (m['vote_average'] as num?)?.toDouble(),
        year: date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Retire les tags de nom de fichier IPTV : « FR - », « [VOSTFR] », années…
  static String _clean(String t) {
    var s = t
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'^\s*(FR|VF|VOSTFR|EN|MULTI)\s*[-|:]\s*',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s.isEmpty ? t : s;
  }

  static String? _nn(String s) => s.trim().isEmpty ? null : s.trim();
}
