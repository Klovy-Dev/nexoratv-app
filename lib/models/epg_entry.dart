/// Un programme EPG (guide TV).
class EpgEntry {
  const EpgEntry({
    required this.title,
    required this.description,
    required this.start,
    required this.stop,
  });

  final String title;
  final String description;
  final DateTime start;
  final DateTime stop;

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(stop);
  }

  /// Progression 0..1 si en cours.
  double get progress {
    if (!isNow) return 0;
    final total = stop.difference(start).inSeconds;
    if (total <= 0) return 0;
    return DateTime.now().difference(start).inSeconds / total;
  }
}
