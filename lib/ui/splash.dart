import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import 'onboarding.dart';
import 'theme.dart';
import 'widgets.dart';

enum _Step {
  live('TV'),
  movies('Films'),
  series('Séries');

  const _Step(this.label);
  final String label;
}

/// Écran de chargement : logo entouré d'un arc qui tourne, pendant que le
/// compte est relu et que le catalogue de la source active (TV, films,
/// séries) est préchargé. Les écrans s'ouvrent ensuite sans attente.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Au-delà, on passe à l'étape suivante sans attendre ce serveur.
  static const _stepTimeout = Duration(seconds: 20);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  final _done = <_Step>{};

  /// Étape en cours de chargement (null avant et après).
  _Step? _current;
  bool _preloading = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  /// TV, puis Films, puis Séries, l'un après l'autre ; l'accueil ne
  /// s'affiche qu'une fois les trois terminés.
  Future<void> _run() async {
    // Durée minimale pour que le logo ne fasse pas qu'un flash.
    final minimum = Future<void>.delayed(const Duration(milliseconds: 1200));
    await ref.read(appProvider.notifier).restored;
    if (!mounted) return;
    if (ref.read(contentProvider) != null) {
      setState(() => _preloading = true);
      await _load(
        _Step.live,
        () => [
          ref.read(liveCategoriesProvider.future),
          ref.read(liveChannelsProvider.future),
        ],
      );
      await _load(
        _Step.movies,
        () => [
          ref.read(movieCategoriesProvider.future),
          ref.read(moviesProvider.future),
        ],
      );
      await _load(
        _Step.series,
        () => [
          ref.read(seriesCategoriesProvider.future),
          ref.read(seriesProvider.future),
        ],
      );
    }
    await minimum;
    if (mounted) widget.onDone();
  }

  /// [start] ne lance les requêtes qu'au moment de l'étape.
  Future<void> _load(_Step step, List<Future<Object?>> Function() start) async {
    if (!mounted) return;
    setState(() => _current = step);
    try {
      await Future.wait(start()).timeout(_stepTimeout);
    } catch (_) {
      // Un échec ou un serveur trop lent ne bloque pas le démarrage : le
      // chargement continue en fond et l'écran concerné affichera son état
      // (chargement, ou erreur avec « Réessayer »).
    }
    if (mounted) {
      setState(() {
        _done.add(step);
        _current = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GlassBackdrop(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Seule la rotation est animée : l'arc n'est jamais repeint.
                  RepaintBoundary(
                    child: RotationTransition(
                      turns: _spin,
                      child: const CustomPaint(
                        size: Size.square(168),
                        painter: _ArcPainter(),
                      ),
                    ),
                  ),
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 132,
                      height: 132,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Brand(size: 30),
            const SizedBox(height: 24),
            AnimatedOpacity(
              opacity: _preloading ? 1 : 0,
              duration: Nx.fast,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final step in _Step.values) ...[
                    if (step != _Step.live) const SizedBox(width: 22),
                    _StepLabel(
                      label: step.label,
                      state: _done.contains(step)
                          ? _StepState.done
                          : step == _current
                          ? _StepState.loading
                          : _StepState.waiting,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

enum _StepState { waiting, loading, done }

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: 16,
        child: AnimatedSwitcher(
          duration: Nx.fast,
          child: switch (state) {
            _StepState.done => const Icon(
              Icons.check_circle_rounded,
              key: ValueKey(_StepState.done),
              size: 16,
              color: Nx.success,
            ),
            _StepState.loading => const CircularProgressIndicator(
              key: ValueKey(_StepState.loading),
              strokeWidth: 2,
              color: Nx.accent,
            ),
            _StepState.waiting => Icon(
              Icons.circle_outlined,
              key: const ValueKey(_StepState.waiting),
              size: 16,
              color: Nx.muted.withValues(alpha: 0.5),
            ),
          },
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: state == _StepState.waiting ? Nx.muted : Nx.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

/// Arc corail (environ un tiers de cercle) dont la queue s'efface.
class _ArcPainter extends CustomPainter {
  const _ArcPainter();

  static const _stroke = 4.0;
  static const _sweep = 2.2; // radians

  /// Décalage du début de l'arc : l'arrondi de la queue ne doit pas passer
  /// sous l'angle 0, où le dégradé reprend sa couleur pleine (point rouge).
  static const _start = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [Nx.accent.withValues(alpha: 0), Nx.accent],
      ).createShader(rect);
    canvas.drawArc(rect, _start, _sweep, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => false;
}
