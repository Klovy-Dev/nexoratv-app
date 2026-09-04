import 'package:flutter/material.dart';

/// Observe les changements de route pour que le lecteur se mette en pause
/// quand un autre écran passe par-dessus (à brancher sur `MaterialApp`).
final routeObserver = RouteObserver<PageRoute<dynamic>>();

/// Transition "fade-through" (Material) commune à toute l'app.
Future<T?> pushFade<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(_FadeRoute(page));
}

class _FadeRoute<T> extends PageRouteBuilder<T> {
  _FadeRoute(Widget page)
      : super(
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, anim, _, child) {
            final curved =
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
