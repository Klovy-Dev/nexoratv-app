import 'package:flutter_test/flutter_test.dart';
import 'package:nexoratv/content/m3u.dart';
import 'package:nexoratv/content/xtream.dart';

void main() {
  test('classe chaînes, films et épisodes', () {
    const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="tf1.fr" tvg-logo="http://logo/tf1.png" group-title="France",TF1 HD
http://srv:8080/live/u/p/1.ts
#EXTINF:-1 tvg-logo="http://img/a.jpg" group-title="Films Action",Film, avec virgule (2024)
http://srv:8080/movie/u/p/10.mkv
#EXTINF:-1 group-title="Séries FR",Ma Série S01 E02
http://srv:8080/series/u/p/20.mp4
#EXTINF:-1 group-title="Séries FR",Ma Série S01E01
http://srv:8080/series/u/p/19.mp4
''';
    final c = parseM3u(playlist);

    expect(c.channels.single.name, 'TF1 HD');
    expect(c.channels.single.logo, 'http://logo/tf1.png');
    expect(c.liveCategories.single.name, 'France');

    expect(c.movies.single.name, 'Film, avec virgule (2024)');
    expect(c.movies.single.categoryId, 'Films Action');

    final series = c.series.single;
    expect(series.name, 'Ma Série');
    expect(series.episodes!.map((e) => (e.season, e.number)), containsAll([(1, 1), (1, 2)]));
  });

  test('normalise l’adresse d’un serveur Xtream', () {
    expect(XtreamContent.normalizeBase('srv.com:8080/'), 'http://srv.com:8080');
    expect(XtreamContent.normalizeBase('https://srv.com/player_api.php?username=a'), 'https://srv.com');
  });
}
