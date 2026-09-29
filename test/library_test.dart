import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexoratv/core/models.dart';
import 'package:nexoratv/state/app_state.dart';
import 'package:nexoratv/state/library.dart';
import 'package:nexoratv/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = Source(id: 'a', name: 'A', kind: SourceKind.xtream);
const _b = Source(id: 'b', name: 'B', kind: SourceKind.xtream);

class _App extends AppController {
  @override
  AppState build() =>
      const AppState(ready: true, sources: [_a, _b], activeId: 'a');

  @override
  Future<void> get restored => Future.value();

  void use(String id) => state = state.copyWith(activeId: () => id);
}

WatchProgress _progress(int seconds, {int duration = 3600, String id = 'm1'}) =>
    WatchProgress(
      kind: MediaKind.movie,
      id: id,
      title: 'Film',
      position: Duration(seconds: seconds),
      duration: Duration(seconds: duration),
      updatedAt: DateTime.now(),
    );

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        appProvider.overrideWith(_App.new),
      ],
    );
    addTearDown(container.dispose);
  });

  LibraryController lib() => container.read(libraryProvider.notifier);
  Library state() => container.read(libraryProvider);

  test('favoris : ajout puis retrait', () {
    lib().toggleFavorite(MediaKind.live, '42');
    expect(state().isFavorite(MediaKind.live, '42'), isTrue);
    expect(state().favoriteIds(MediaKind.live), {'42'});
    expect(state().favoriteIds(MediaKind.movie), isEmpty);
    lib().toggleFavorite(MediaKind.live, '42');
    expect(state().isFavorite(MediaKind.live, '42'), isFalse);
  });

  test('reprise : seulement après 30 s, retirée quand presque fini', () {
    lib().saveProgress(_progress(10));
    expect(state().progressFor(MediaKind.movie, 'm1'), isNull);

    lib().saveProgress(_progress(600));
    expect(
      state().progressFor(MediaKind.movie, 'm1')?.position,
      const Duration(seconds: 600),
    );

    lib().saveProgress(_progress(3550)); // moins de 90 s restantes
    expect(state().progressFor(MediaKind.movie, 'm1'), isNull);
  });

  test('chaque source a ses favoris et sa reprise', () {
    lib().toggleFavorite(MediaKind.movie, 'x');
    lib().saveProgress(_progress(600));

    (container.read(appProvider.notifier) as _App).use('b');
    expect(state().favorites, isEmpty);
    expect(state().progress, isEmpty);

    (container.read(appProvider.notifier) as _App).use('a');
    expect(state().isFavorite(MediaKind.movie, 'x'), isTrue);
    expect(state().progressFor(MediaKind.movie, 'm1'), isNotNull);
  });

  test('avancement d’un programme TV', () {
    final start = DateTime(2026, 9, 25, 20);
    final e = EpgEntry(
      title: 'Journal',
      start: start,
      end: start.add(const Duration(hours: 1)),
    );
    expect(e.progressAt(start.add(const Duration(minutes: 15))), 0.25);
    expect(e.progressAt(start.subtract(const Duration(minutes: 5))), 0);
    expect(e.progressAt(start.add(const Duration(hours: 2))), 1);
  });
}
