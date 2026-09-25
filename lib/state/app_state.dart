import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_source.dart';
import '../core/account_api.dart';
import '../core/http.dart';
import '../core/models.dart';
import '../core/storage.dart';

class AppState {
  const AppState({
    this.ready = false,
    this.token,
    this.user,
    this.sources = const [],
    this.activeId,
    this.accountError,
  });

  /// Faux tant que le stockage local n'est pas lu (écran de démarrage).
  final bool ready;
  final String? token;
  final AccountUser? user;
  final List<Source> sources;
  final String? activeId;

  /// Dernière erreur de synchronisation du compte (affichée dans « Sources »).
  final String? accountError;

  bool get loggedIn => token != null;

  Source? get active {
    for (final s in sources) {
      if (s.id == activeId) return s;
    }
    return sources.isEmpty ? null : sources.first;
  }

  AppState copyWith({
    bool? ready,
    String? Function()? token,
    AccountUser? Function()? user,
    List<Source>? sources,
    String? Function()? activeId,
    String? Function()? accountError,
  }) =>
      AppState(
        ready: ready ?? this.ready,
        token: token != null ? token() : this.token,
        user: user != null ? user() : this.user,
        sources: sources ?? this.sources,
        activeId: activeId != null ? activeId() : this.activeId,
        accountError: accountError != null ? accountError() : this.accountError,
      );
}

class AppController extends Notifier<AppState> {
  @override
  AppState build() {
    _restore();
    return const AppState();
  }

  Future<void> _restore() async {
    final token = await Storage.token();
    state = state.copyWith(
      ready: true,
      token: () => token,
      user: () => null,
      sources: await Storage.sources(),
      activeId: () => null,
    );
    final user = await Storage.user();
    final activeId = await Storage.activeSourceId();
    state = state.copyWith(user: () => user, activeId: () => activeId);
    // Abonnements à jour en arrière-plan (les sources mémorisées restent
    // utilisables hors ligne).
    if (token != null) await syncAccount();
  }

  Future<void> login(String email, String password) async {
    final (token, user) = await AccountApi.login(email, password);
    await Storage.saveAccount(token, user);
    state = state.copyWith(token: () => token, user: () => user, accountError: () => null);
    await syncAccount(throwOnError: true);
  }

  /// Remplace les sources issues du compte par les abonnements actuels.
  Future<void> syncAccount({bool throwOnError = false}) async {
    final token = state.token;
    if (token == null) return;
    try {
      final (user, subs) = await AccountApi.me(token);
      final fromAccount = [
        for (final s in subs)
          if (s.playable) s.toSource(),
      ];
      final manual = state.sources.where((s) => !s.fromAccount);
      // Les abonnements actifs d'abord.
      fromAccount.sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0));
      await _setSources([...fromAccount, ...manual]);
      await Storage.saveAccount(token, user);
      state = state.copyWith(user: () => user, accountError: () => null);
    } on SessionExpired {
      await logout();
      state = state.copyWith(accountError: () => SessionExpired().message);
      if (throwOnError) rethrow;
    } on AppException catch (e) {
      state = state.copyWith(accountError: () => e.message);
      if (throwOnError) rethrow;
    }
  }

  Future<void> logout() async {
    await Storage.clearAccount();
    await _setSources(state.sources.where((s) => !s.fromAccount).toList());
    state = state.copyWith(token: () => null, user: () => null);
  }

  Future<void> addSource(Source source) async {
    await _setSources([...state.sources, source]);
    await select(source.id);
  }

  Future<void> removeSource(String id) =>
      _setSources(state.sources.where((s) => s.id != id).toList());

  Future<void> select(String id) async {
    await Storage.saveActiveSourceId(id);
    state = state.copyWith(activeId: () => id);
  }

  Future<void> _setSources(List<Source> sources) async {
    await Storage.saveSources(sources);
    final keepActive = sources.any((s) => s.id == state.activeId);
    state = state.copyWith(
      sources: sources,
      activeId: keepActive ? null : () => sources.isEmpty ? null : sources.first.id,
    );
  }
}

final appProvider = NotifierProvider<AppController, AppState>(AppController.new);

/// Catalogue de la source active (recréé seulement si la source change).
final contentProvider = Provider<ContentSource?>((ref) {
  final source = ref.watch(appProvider.select((s) => s.active));
  return source == null ? null : ContentSource.of(source);
});

ContentSource _content(Ref ref) {
  final content = ref.watch(contentProvider);
  if (content == null) throw AppException('Aucune source sélectionnée.');
  return content;
}

final liveCategoriesProvider = FutureProvider((ref) => _content(ref).liveCategories());
final liveChannelsProvider = FutureProvider((ref) => _content(ref).liveChannels());
final movieCategoriesProvider = FutureProvider((ref) => _content(ref).movieCategories());
final moviesProvider = FutureProvider((ref) => _content(ref).movies());
final seriesCategoriesProvider = FutureProvider((ref) => _content(ref).seriesCategories());
final seriesProvider = FutureProvider((ref) => _content(ref).series());
