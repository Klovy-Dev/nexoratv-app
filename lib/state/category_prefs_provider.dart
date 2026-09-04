import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage/category_prefs_repository.dart';
import 'providers.dart';

typedef CatPrefsData = Map<String, Map<String, Map<String, CategoryPref>>>;

class CategoryPrefsNotifier extends AsyncNotifier<CatPrefsData> {
  @override
  Future<CatPrefsData> build() =>
      ref.watch(categoryPrefsRepositoryProvider).load();

  CategoryPref prefFor(String sourceId, String section, String category) {
    return state.value?[sourceId]?[section]?[category] ?? const CategoryPref();
  }

  Future<void> setPref(
    String sourceId,
    String section,
    String category,
    CategoryPref pref,
  ) async {
    final data = CatPrefsData.from(state.value ?? {});
    final bySource =
        Map<String, Map<String, CategoryPref>>.from(data[sourceId] ?? {});
    final bySection = Map<String, CategoryPref>.from(bySource[section] ?? {});
    bySection[category] = pref;
    bySource[section] = bySection;
    data[sourceId] = bySource;
    state = AsyncData(data);
    await ref.read(categoryPrefsRepositoryProvider).save(data);
  }

  Future<void> clearForSource(String sourceId) async {
    final data = CatPrefsData.from(state.value ?? {})..remove(sourceId);
    state = AsyncData(data);
    await ref.read(categoryPrefsRepositoryProvider).save(data);
  }
}

final categoryPrefsProvider =
    AsyncNotifierProvider<CategoryPrefsNotifier, CatPrefsData>(
        CategoryPrefsNotifier.new);

/// Nom de section pour les prefs de catégorie.
String sectionKey(int mediaKindIndex) =>
    ['live', 'movie', 'series'][mediaKindIndex.clamp(0, 2)];
