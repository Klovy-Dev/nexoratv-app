import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'tv_text_field.dart';

/// Carte animée au survol : soulèvement, léger zoom, bordure corail et
/// ombre (même langage que les cartes du site).
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = Nx.radius,
    this.color = Nx.surface,
    this.scale = 1.03,
    this.padding = EdgeInsets.zero,
    this.selected = false,
    this.lift = 4,
    this.outlined = true,
    this.glass = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color color;
  final double scale;
  final EdgeInsetsGeometry padding;
  final bool selected;

  /// Soulèvement au survol, en pixels (0 pour les lignes de liste).
  final double lift;

  /// Faux : pas de bordure au repos (lignes de liste), seulement au survol.
  final bool outlined;

  /// Verre dépoli : carte translucide (à poser sur un [GlassBackdrop] pour
  /// que l'effet se voie). Pas de vrai flou, trop coûteux sur fond animé.
  final bool glass;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;
  bool _focus = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = (_hover || _focus) && widget.onTap != null;
    final highlight = active || widget.selected;
    // Focusable au clavier (Tab, flèches) et activable avec Entrée /
    // Espace : indispensable pour la télécommande d'Android TV.
    return FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      onShowHoverHighlight: (v) => setState(() {
        _hover = v;
        if (!v) _pressed = false;
      }),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (active ? widget.scale : 1),
          duration: Nx.fast,
          curve: Nx.ease,
          child: widget.glass
              ? _glass(active, highlight)
              : AnimatedContainer(
                  duration: Nx.fast,
                  curve: Nx.ease,
                  transform: Matrix4.translationValues(
                    0,
                    active ? -widget.lift : 0,
                    0,
                  ),
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? Color.alphaBlend(
                            Nx.accent.withValues(alpha: 0.08),
                            widget.color,
                          )
                        : widget.color,
                    borderRadius: BorderRadius.circular(widget.radius),
                    border: Border.all(
                      color: _focus
                          ? Nx.accent
                          : highlight
                          ? Nx.accent.withValues(alpha: 0.7)
                          : (widget.outlined ? Nx.border : Colors.transparent),
                      width: _focus ? 2 : 1,
                    ),
                    boxShadow: [
                      if (_focus) _focusRing,
                      if (active && widget.lift > 0)
                        BoxShadow(
                          color: Nx.accent.withValues(alpha: 0.18),
                          blurRadius: 28,
                          spreadRadius: -6,
                          offset: const Offset(0, 14),
                        ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.child,
                ),
        ),
      ),
    );
  }

  Widget _glass(bool active, bool highlight) {
    final radius = BorderRadius.circular(widget.radius);
    return AnimatedContainer(
      duration: Nx.fast,
      curve: Nx.ease,
      transform: Matrix4.translationValues(0, active ? -widget.lift : 0, 0),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: -12,
            offset: const Offset(0, 20),
          ),
          if (_focus) _focusRing,
          if (active)
            BoxShadow(
              color: Nx.accent.withValues(alpha: 0.22),
              blurRadius: 36,
              spreadRadius: -8,
              offset: const Offset(0, 16),
            ),
        ],
      ),
      // Pas de BackdropFilter : le fond (GlassBackdrop) n'est fait que de
      // dégradés très doux, le flouter ne change rien à l'image mais
      // coûterait un flou complet à chaque image tant que le fond bouge.
      // La teinte translucide suffit à l'effet verre.
      child: AnimatedContainer(
        duration: Nx.fast,
        curve: Nx.ease,
        padding: widget.padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: radius,
          // Teinte translucide + reflet en haut à gauche.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: active ? 0.13 : 0.09),
              Colors.white.withValues(alpha: active ? 0.05 : 0.025),
            ],
          ),
          border: Border.all(
            color: _focus
                ? Nx.accent
                : highlight
                ? Nx.accent.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.13),
            width: _focus ? 2 : 1,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Ligne de liste (catégories, chaînes) : fond discret au survol, barre
/// corail à gauche quand elle est sélectionnée, contour au focus clavier.
class ListRow extends StatefulWidget {
  const ListRow({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final Widget child;
  final VoidCallback onTap;

  /// OK maintenu (télécommande), clic droit ou appui long (souris).
  final VoidCallback? onLongPress;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  State<ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<ListRow> {
  /// Durée d'appui sur OK au-delà de laquelle c'est un appui long.
  static const _longPress = Duration(milliseconds: 500);

  bool _hover = false;
  bool _focus = false;
  Timer? _hold;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  /// OK court = clic, OK maintenu = [ListRow.onLongPress]. La touche est
  /// gérée ici (avant les raccourcis de l'appli, qui activeraient la ligne
  /// en boucle tant qu'on appuie).
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (!tvSelectKeys.contains(e.logicalKey)) return KeyEventResult.ignored;
    if (e is KeyDownEvent) {
      _hold?.cancel();
      _hold = Timer(_longPress, () {
        _hold = null;
        widget.onLongPress?.call();
      });
    } else if (e is KeyUpEvent && _hold != null) {
      _hold!.cancel();
      _hold = null;
      widget.onTap();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final row = _row();
    if (widget.onLongPress == null) return row;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: row,
    );
  }

  Widget _row() => FocusableActionDetector(
    mouseCursor: SystemMouseCursors.click,
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onTap();
          return null;
        },
      ),
    },
    onShowHoverHighlight: (v) => setState(() => _hover = v),
    onShowFocusHighlight: (v) => setState(() => _focus = v),
    child: GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onSecondaryTap: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: widget.selected
              ? Nx.surface2
              : (_hover || _focus ? Nx.surface : Colors.transparent),
          borderRadius: BorderRadius.circular(Nx.radiusSm),
          border: Border.all(
            color: _focus ? Nx.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Nx.fast,
              curve: Nx.ease,
              width: 3,
              height: widget.selected ? 20 : 0,
              decoration: BoxDecoration(
                color: Nx.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Fondu en haut et en bas d'une liste qui défile : le texte qui passe
/// sous un titre s'efface au lieu d'être coupé net.
class EdgeFade extends StatelessWidget {
  const EdgeFade({super.key, required this.child, this.size = 14});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final stop = c.maxHeight <= 0 ? 0.0 : (size / c.maxHeight).clamp(0, 0.5);
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0, stop.toDouble(), 1 - stop.toDouble(), 1],
        ).createShader(rect),
        child: child,
      );
    },
  );
}

/// Halo autour de l'élément qui a le focus clavier (lisible de loin, sur
/// une télé comme sur un PC).
const _focusRing = BoxShadow(color: Color(0x59FF4B3E), spreadRadius: 4);

/// Fond animé pour l'effet verre : halos corail et ambrés, très flous, qui
/// dérivent lentement derrière les cartes.
class GlassBackdrop extends StatefulWidget {
  const GlassBackdrop({super.key, required this.child});
  final Widget child;

  @override
  State<GlassBackdrop> createState() => _GlassBackdropState();
}

class _GlassBackdropState extends State<GlassBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      // Le fond se repeint seul (aucune reconstruction de widgets) et le
      // contenu, dans sa propre couche, n'est jamais repeint à cause de lui.
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: _BlobPainter(_drift)),
        ),
      ),
      RepaintBoundary(child: widget.child),
    ],
  );
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.drift) : super(repaint: drift);

  final Animation<double> drift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Nx.bg);
    final t = Curves.easeInOut.transform(drift.value);
    _blob(
      canvas,
      size,
      Alignment(-0.75 + 0.25 * t, -0.55 + 0.2 * t),
      310,
      Nx.accent,
      0.42,
    );
    _blob(
      canvas,
      size,
      Alignment(0.85 - 0.2 * t, 0.2 - 0.3 * t),
      280,
      const Color(0xFFFF9A3C),
      0.26,
    );
    _blob(
      canvas,
      size,
      Alignment(0.05 + 0.15 * t, 1.1 - 0.15 * t),
      350,
      const Color(0xFF8E1B3A),
      0.38,
    );
  }

  void _blob(
    Canvas canvas,
    Size size,
    Alignment at,
    double radius,
    Color color,
    double alpha,
  ) {
    final center = at.alongSize(size);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.drift != drift;
}

/// Image réseau avec repli sur les initiales (logos de chaînes, affiches).
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    required this.label,
    this.fit = BoxFit.cover,
    this.cacheWidth = 320,
  });

  final String? url;
  final String label;
  final BoxFit fit;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final fallback = _Initials(label);
    final u = url;
    if (u == null || !u.startsWith('http')) return fallback;
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const ColoredBox(color: Nx.surface2),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final words = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2);
    final initials = words.map((w) => w.characters.first.toUpperCase()).join();
    return ColoredBox(
      color: Nx.surface2,
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            fontFamily: Nx.display,
            fontWeight: FontWeight.w700,
            color: Nx.muted,
          ),
        ),
      ),
    );
  }
}

/// Champ de recherche compact.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TvTextField(
    onChanged: onChanged,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      isDense: true,
      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Nx.muted),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    ),
  );
}

/// Pastille de catégorie (films / séries).
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: HoverCard(
      onTap: onTap,
      radius: 999,
      scale: 1.04,
      selected: selected,
      color: selected ? Nx.accent : Nx.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Nx.bg : Nx.text,
        ),
      ),
    ),
  );
}

/// États de chargement / erreur / vide homogènes.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Chargement…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6, color: Nx.accent),
        ),
        const SizedBox(height: 14),
        Text(label, style: const TextStyle(color: Nx.muted)),
      ],
    ),
  );
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Nx.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Nx.accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Nx.muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}

String errorText(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
