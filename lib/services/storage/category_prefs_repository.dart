import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Personnalisation d'une catégorie : masquée, renommée, ordre.
class CategoryPref {
  const CategoryPref({this.hidden = false, this.renamedTo, this.order = 0});
  final bool hidden;
  final String? renamedTo;
  final int order;

  CategoryPref copyWith({bool? hidden, String? renamedTo, int? order}) =>
      CategoryPref(
        hidden: hidden ?? this.hidden,
        renamedTo: renamedTo ?? this.renamedTo,
        order: order ?? this.order,
      );

  Map<String, dynamic> toJson() =>
      {'hidden': hidden, 'renamedTo': renamedTo, 'order': order};
  factory CategoryPref.fromJson(Map<String, dynamic> j) => CategoryPref(
        hidden: j['hidden'] == true,
        renamedTo: j['renamedTo'] as String?,
        order: (j['order'] as num?)?.toInt() ?? 0,
      );
}

/// `{sourceId: {section: {catégorie: CategoryPref}}}`, section ∈ live/movie/series.
class CategoryPrefsRepository {
  static const _key = 'category_prefs_v1';

  Future<Map<String, Map<String, Map<String, CategoryPref>>>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return {};
    try {
      final root = jsonDecode(raw) as Map<String, dynamic>;
      return root.map((src, sections) => MapEntry(
            src,
            (sections as Map<String, dynamic>).map((sec, cats) => MapEntry(
                  sec,
                  (cats as Map<String, dynamic>).map((c, v) => MapEntry(
                      c, CategoryPref.fromJson(v as Map<String, dynamic>))),
                )),
          ));
    } catch (_) {
      return {};
    }
  }

  Future<void> save(
      Map<String, Map<String, Map<String, CategoryPref>>> data) async {
    final p = await SharedPreferences.getInstance();
    final root = data.map((src, sections) => MapEntry(
          src,
          sections.map((sec, cats) => MapEntry(
              sec, cats.map((c, v) => MapEntry(c, v.toJson())))),
        ));
    await p.setString(_key, jsonEncode(root));
  }
}
