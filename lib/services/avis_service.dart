import 'package:dio/dio.dart';

import '../brand.dart';

/// Un avis client (tel que renvoyé par `nexoratv.fr/api/avis`).
class Review {
  const Review({
    required this.author,
    required this.rating,
    required this.text,
    this.date,
  });

  final String author;
  final int rating;
  final String text;
  final DateTime? date;
}

/// Ensemble d'avis + moyenne.
class Avis {
  const Avis({required this.count, required this.average, required this.reviews});

  final int count;
  final double average;
  final List<Review> reviews;

  static const empty = Avis(count: 0, average: 0, reviews: []);
}

/// Récupère les avis clients depuis le site. Ne lève jamais : renvoie
/// [Avis.empty] en cas de problème (réseau, JSON invalide…).
class AvisService {
  AvisService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _dio;

  Future<Avis> fetch() async {
    try {
      final res = await _dio.getUri<dynamic>(Uri.parse(Brand.avisEndpoint));
      final data = res.data;
      if (data is! Map) return Avis.empty;

      final rawList = data['reviews'];
      final reviews = <Review>[];
      if (rawList is List) {
        for (final e in rawList) {
          if (e is! Map) continue;
          final text = '${e['text'] ?? ''}'.trim();
          final author = '${e['author'] ?? ''}'.trim();
          if (text.isEmpty || author.isEmpty) continue;
          reviews.add(Review(
            author: author,
            rating: (e['rating'] as num?)?.round().clamp(1, 5) ?? 5,
            text: text,
            date: DateTime.tryParse('${e['date'] ?? ''}'),
          ));
        }
      }

      return Avis(
        count: (data['count'] as num?)?.toInt() ?? reviews.length,
        average: (data['average'] as num?)?.toDouble() ?? 0,
        reviews: reviews,
      );
    } catch (_) {
      return Avis.empty;
    }
  }
}
