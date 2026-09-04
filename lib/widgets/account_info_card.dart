import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_info.dart';

/// Carte « infos abonnement » : statut, expiration (date + heure), connexions.
class AccountInfoCard extends StatelessWidget {
  const AccountInfoCard({super.key, required this.async});
  final AsyncValue<XtreamAccountInfo?> async;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const ListTile(
        leading: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Lecture des infos du compte…'),
      ),
      error: (_, _) => const ListTile(
        leading: Icon(Icons.help_outline),
        title: Text('Infos abonnement indisponibles'),
      ),
      data: (info) {
        if (info == null) {
          return const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Aucune info (source M3U simple)'),
          );
        }
        final exp = info.expiresAt;
        final rem = info.remaining;
        final scheme = Theme.of(context).colorScheme;

        Color color;
        String expLabel;
        if (exp == null) {
          color = scheme.onSurface;
          expLabel = 'Illimité';
        } else if (info.isExpired) {
          color = Colors.redAccent;
          expLabel = 'Expiré le ${_fmt(exp)}';
        } else {
          final days = rem!.inDays;
          color = days <= 7 ? Colors.orangeAccent : const Color(0xFF3FB98A);
          expLabel = '${_fmt(exp)}  (${_human(rem)})';
        }

        return Column(
          children: [
            ListTile(
              leading: Icon(Icons.event_available, color: color),
              title: const Text('Expiration'),
              subtitle: Text(expLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Statut'),
              subtitle: Text(
                '${info.status ?? '—'}'
                '${info.isTrial ? '  ·  essai' : ''}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.devices_other),
              title: const Text('Connexions'),
              subtitle: Text(
                '${info.activeConnections ?? '?'} / '
                '${info.maxConnections ?? '?'} en cours',
              ),
            ),
            if (info.createdAt != null)
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Compte créé le'),
                subtitle: Text(_fmt(info.createdAt!)),
              ),
          ],
        );
      },
    );
  }

  static String _fmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mn = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} à ${hh}h$mn';
  }

  static String _human(Duration d) {
    if (d.inDays >= 30) return 'dans ${(d.inDays / 30).floor()} mois';
    if (d.inDays >= 1) return 'dans ${d.inDays} j';
    if (d.inHours >= 1) return 'dans ${d.inHours} h';
    return 'bientôt';
  }
}
