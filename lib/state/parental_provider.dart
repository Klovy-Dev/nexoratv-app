import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage/parental_repository.dart';

final parentalRepositoryProvider = Provider((ref) => ParentalRepository());

class ParentalNotifier extends AsyncNotifier<ParentalSettings> {
  @override
  Future<ParentalSettings> build() =>
      ref.watch(parentalRepositoryProvider).load();

  ParentalSettings get _s => state.value ?? const ParentalSettings();

  Future<void> _persist(ParentalSettings next) async {
    state = AsyncData(next);
    await ref.read(parentalRepositoryProvider).save(next);
  }

  Future<void> setEnabled(bool v) => _persist(_s.copyWith(enabled: v));
  Future<void> setHideAdult(bool v) => _persist(_s.copyWith(hideAdult: v));

  Future<void> setPin(String pin) => _persist(_s.copyWith(
        pinHash: ref.read(parentalRepositoryProvider).hashPin(pin),
      ));

  Future<void> toggleLock(String sourceId, String section, String cat) {
    final key = '$sourceId::$section::$cat';
    final next = {..._s.locked};
    if (!next.remove(key)) next.add(key);
    return _persist(_s.copyWith(locked: next));
  }
}

final parentalProvider =
    AsyncNotifierProvider<ParentalNotifier, ParentalSettings>(
        ParentalNotifier.new);

final parentalValueProvider = Provider<ParentalSettings>(
    (ref) => ref.watch(parentalProvider).value ?? const ParentalSettings());
