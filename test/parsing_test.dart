import 'package:flutter_test/flutter_test.dart';
import 'package:nexoratv/models/channel.dart';
import 'package:nexoratv/models/playlist_source.dart';
import 'package:nexoratv/services/m3u_parser.dart';
import 'package:nexoratv/services/playlist_service.dart';

void main() {
  group('M3uParser', () {
    test('parse une entrée standard', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="c1" tvg-logo="http://logo/1.png" group-title="Sport" tvg-chno="12",Chaîne 1
http://host/stream/1
''';
      final r = M3uParser().parse(m3u);
      expect(r, hasLength(1));
      expect(r.first.name, 'Chaîne 1');
      expect(r.first.group, 'Sport');
      expect(r.first.logo, 'http://logo/1.png');
      expect(r.first.number, 12);
      expect(r.first.epgChannelId, 'c1');
      expect(r.first.url, 'http://host/stream/1');
    });

    test('sans group-title -> Non classé', () {
      const m3u = '#EXTM3U\n#EXTINF:-1,Sans cat\nhttp://h/2';
      expect(M3uParser().parse(m3u).first.group, 'Non classé');
    });

    test('#EXTGRP remplace la catégorie', () {
      const m3u =
          '#EXTM3U\n#EXTINF:-1,X\n#EXTGRP:Docs\nhttp://h/3';
      expect(M3uParser().parse(m3u).first.group, 'Docs');
    });

    test('ids stables pour la même url', () {
      final a = M3uParser().parse('#EXTINF:-1,A\nhttp://same');
      final b = M3uParser().parse('#EXTINF:-1,B\nhttp://same');
      expect(a.first.id, b.first.id);
    });
  });

  group('PlaylistSource.upgradedToXtreamIfPossible', () {
    test('convertit un lien get.php', () {
      final s = PlaylistSource(
        name: 'x',
        kind: SourceKind.m3uUrl,
        m3uUrl:
            'http://exemple.com:8080/get.php?username=abc&password=def&type=m3u_plus',
      ).upgradedToXtreamIfPossible();
      expect(s.kind, SourceKind.xtream);
      expect(s.host, 'http://exemple.com:8080');
      expect(s.username, 'abc');
      expect(s.password, 'def');
    });

    test('laisse un vrai fichier .m3u tranquille', () {
      final s = PlaylistSource(
        name: 'x',
        kind: SourceKind.m3uUrl,
        m3uUrl: 'http://exemple.com/playlist.m3u',
      ).upgradedToXtreamIfPossible();
      expect(s.kind, SourceKind.m3uUrl);
    });

    test('détecte le format hls dans l\'url', () {
      final s = PlaylistSource(
        name: 'x',
        kind: SourceKind.m3uUrl,
        m3uUrl: 'http://e.com/get.php?username=a&password=b&output=hls',
      ).upgradedToXtreamIfPossible();
      expect(s.xtreamOutput, XtreamOutput.m3u8);
    });
  });

  group('groupCountsOf', () {
    test('garde l\'ordre d\'apparition, Non classé toujours en dernier', () {
      final r = groupCountsOf(['Zoo', 'Non classé', 'Alpha', 'Non classé']);
      expect(r.map((e) => e.name).toList(), ['Zoo', 'Alpha', 'Non classé']);
      expect(r.firstWhere((e) => e.name == 'Non classé').count, 2);
    });
  });

  group('mergedQualityCategory', () {
    test('retire le suffixe de qualité', () {
      expect(mergedQualityCategory('FR TV (HD)'), 'FR TV');
      expect(mergedQualityCategory('FR TV (SD)'), 'FR TV');
      expect(mergedQualityCategory('FR TV 4K'), 'FR TV');
      expect(mergedQualityCategory('FR - Films FHD'), 'FR - Films');
      expect(mergedQualityCategory('FR | Sport [UHD]'), 'FR | Sport');
    });
    test('retire jusqu\'à deux suffixes', () {
      expect(mergedQualityCategory('FR Films HD MULTI'), 'FR Films');
    });
    test('laisse une catégorie sans suffixe intacte', () {
      expect(mergedQualityCategory('Documentaires'), 'Documentaires');
      expect(mergedQualityCategory('Cinéma Français'), 'Cinéma Français');
    });
    test('regroupe les variantes ensemble', () {
      final variants = ['FR TV (SD)', 'FR TV (HD)', 'FR TV 4K']
          .map(mergedQualityCategory)
          .toSet();
      expect(variants, {'FR TV'});
    });
  });

  group('mostRecent', () {
    Channel c(String id, {DateTime? added, String? sid}) =>
        Channel(id: id, name: id, url: id, addedAt: added, streamId: sid);

    test('trie par date quand assez d\'items en ont une', () {
      final list = [
        c('a', added: DateTime(2020)),
        c('b', added: DateTime(2024)),
        c('c', added: DateTime(2022)),
        c('d'),
      ];
      final r = mostRecent<Channel>(
          list, (x) => x.addedAt, (x) => int.tryParse(x.streamId ?? ''), 10);
      expect(r.map((e) => e.id).toList(), ['b', 'c', 'a']);
    });

    test('repli sur id décroissant sans dates', () {
      final list = [c('a', sid: '10'), c('b', sid: '99'), c('c', sid: '50')];
      final r = mostRecent<Channel>(
          list, (x) => x.addedAt, (x) => int.tryParse(x.streamId ?? ''), 10);
      expect(r.map((e) => e.id).toList(), ['b', 'c', 'a']);
    });
  });
}
