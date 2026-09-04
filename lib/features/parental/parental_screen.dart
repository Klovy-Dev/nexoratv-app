import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/parental_provider.dart';
import '../../widgets/nav.dart';
import '../../widgets/pin_dialog.dart';
import '../categories/manage_categories_screen.dart';

class ParentalScreen extends ConsumerWidget {
  const ParentalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(parentalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Contrôle parental')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) => ListView(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: const Text('Activer le contrôle parental'),
              subtitle: Text(s.hasPin ? 'Code défini' : 'Aucun code défini'),
              value: s.enabled,
              onChanged: (v) async {
                final n = ref.read(parentalProvider.notifier);
                if (v && !s.hasPin) {
                  final pin = await createPin(context);
                  if (pin == null) return;
                  await n.setPin(pin);
                }
                if (v && context.mounted) {
                  // reconfirmer le code pour activer
                  final ok = await askPin(context,
                      verify: (p) =>
                          ref.read(parentalValueProvider).checkPin(p));
                  if (!ok) return;
                }
                await n.setEnabled(v);
              },
            ),
            ListTile(
              enabled: s.enabled || s.hasPin,
              leading: const Icon(Icons.password),
              title: Text(s.hasPin ? 'Changer le code' : 'Définir un code'),
              onTap: () async {
                if (s.hasPin) {
                  final ok = await askPin(context,
                      verify: (p) =>
                          ref.read(parentalValueProvider).checkPin(p),
                      title: 'Code actuel');
                  if (!ok) return;
                }
                if (!context.mounted) return;
                final pin = await createPin(context);
                if (pin != null) {
                  await ref.read(parentalProvider.notifier).setPin(pin);
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.no_adult_content),
              title: const Text('Masquer les catégories adultes'),
              subtitle: const Text(
                  'XXX, +18, adult… masquées partout, sans code'),
              value: s.hideAdult,
              onChanged: (v) =>
                  ref.read(parentalProvider.notifier).setHideAdult(v),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Verrouiller des catégories'),
              subtitle: const Text('Demande le code pour y accéder'),
              trailing: const Icon(Icons.chevron_right),
              enabled: s.enabled,
              onTap: () => pushFade(
                  context, const ManageCategoriesScreen(lockMode: true)),
            ),
          ],
        ),
      ),
    );
  }
}
