import 'package:xml/xml_events.dart';

import '../models/epg_entry.dart';

/// Parse un flux XMLTV en `{channelId: [programmes triés]}`.
///
/// Utilise le parseur événementiel (streaming) pour tenir des fichiers de
/// plusieurs dizaines de Mo sans exploser la mémoire.
Map<String, List<EpgEntry>> parseXmltv(String xml) {
  final out = <String, List<EpgEntry>>{};

  String? channel;
  DateTime? start;
  DateTime? stop;
  String? title;
  final desc = StringBuffer();
  String? currentText; // 'title' | 'desc' | null

  for (final e in parseEvents(xml)) {
    if (e is XmlStartElementEvent) {
      if (e.name == 'programme') {
        channel = _attr(e, 'channel');
        start = _xmltvDate(_attr(e, 'start'));
        stop = _xmltvDate(_attr(e, 'stop'));
        title = null;
        desc.clear();
      } else if (e.name == 'title') {
        currentText = 'title';
      } else if (e.name == 'desc') {
        currentText = 'desc';
      }
    } else if (e is XmlTextEvent || e is XmlCDATAEvent) {
      final t = e is XmlTextEvent
          ? e.value
          : (e as XmlCDATAEvent).value;
      if (currentText == 'title') {
        title = (title ?? '') + t;
      } else if (currentText == 'desc') {
        desc.write(t);
      }
    } else if (e is XmlEndElementEvent) {
      if (e.name == 'title' || e.name == 'desc') {
        currentText = null;
      } else if (e.name == 'programme') {
        if (channel != null && start != null) {
          out.putIfAbsent(channel, () => []).add(EpgEntry(
                title: title?.trim() ?? '',
                description: desc.toString().trim(),
                start: start,
                stop: stop ?? start.add(const Duration(minutes: 30)),
              ));
        }
        channel = null;
      }
    }
  }

  for (final list in out.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }
  return out;
}

String? _attr(XmlStartElementEvent e, String name) {
  for (final a in e.attributes) {
    if (a.name == name) return a.value;
  }
  return null;
}

/// `20260903180000 +0200` ou `20260903180000` -> DateTime local.
DateTime? _xmltvDate(String? s) {
  if (s == null || s.length < 14) return null;
  try {
    final y = int.parse(s.substring(0, 4));
    final mo = int.parse(s.substring(4, 6));
    final d = int.parse(s.substring(6, 8));
    final h = int.parse(s.substring(8, 10));
    final mi = int.parse(s.substring(10, 12));
    final se = int.parse(s.substring(12, 14));
    var dt = DateTime.utc(y, mo, d, h, mi, se);
    final tz = s.length >= 20 ? s.substring(15).trim() : '';
    if (tz.length == 5 && (tz[0] == '+' || tz[0] == '-')) {
      final off = Duration(
        hours: int.parse(tz.substring(1, 3)),
        minutes: int.parse(tz.substring(3, 5)),
      );
      dt = tz[0] == '+' ? dt.subtract(off) : dt.add(off);
    }
    return dt.toLocal();
  } catch (_) {
    return null;
  }
}
