import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_info.dart';
import '../models/playlist_source.dart';
import '../services/xtream_client.dart';
import 'providers.dart';
import 'sources_provider.dart';

/// Infos du compte de la source courante : réseau si possible, sinon dernière
/// valeur connue en cache.
final accountInfoProvider =
    FutureProvider.autoDispose<XtreamAccountInfo?>((ref) async {
  final source = ref.watch(selectedSourceProvider);
  if (source == null || source.kind != SourceKind.xtream) return null;

  final repo = ref.watch(accountInfoRepositoryProvider);
  final cached = await repo.load(source.id);
  try {
    final info = await XtreamClient(source).authenticate();
    await repo.save(source.id, info);
    return info;
  } catch (_) {
    return cached;
  }
});
