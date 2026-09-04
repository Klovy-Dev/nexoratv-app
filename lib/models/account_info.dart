/// Infos du compte Xtream (`player_api.php` → `user_info`).
class XtreamAccountInfo {
  const XtreamAccountInfo({
    this.status,
    this.expiresAt,
    this.isTrial = false,
    this.maxConnections,
    this.activeConnections,
    this.createdAt,
  });

  final String? status; // "Active", "Expired", "Banned"...
  final DateTime? expiresAt;
  final bool isTrial;
  final int? maxConnections;
  final int? activeConnections;
  final DateTime? createdAt;

  bool get isExpired => expiresAt?.isBefore(DateTime.now()) ?? false;

  Duration? get remaining => expiresAt?.difference(DateTime.now());

  Map<String, dynamic> toJson() => {
        'status': status,
        'expiresAt': expiresAt?.millisecondsSinceEpoch,
        'isTrial': isTrial,
        'maxConnections': maxConnections,
        'activeConnections': activeConnections,
        'createdAt': createdAt?.millisecondsSinceEpoch,
      };

  factory XtreamAccountInfo.fromJson(Map<String, dynamic> j) =>
      XtreamAccountInfo(
        status: j['status'] as String?,
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['expiresAt'] as int),
        isTrial: j['isTrial'] == true,
        maxConnections: (j['maxConnections'] as num?)?.toInt(),
        activeConnections: (j['activeConnections'] as num?)?.toInt(),
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
      );
}
