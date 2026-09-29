import 'dart:io';

import 'package:flutter/material.dart';

/// Largeur de mise en page de l'appli Windows plein écran sur un PC 1080p
/// (1920 px à 125 %) : c'est pour elle que les écrans sont dessinés.
const tvDesignWidth = 1536.0;

/// Sur une télé (Fire TV Stick, Android TV, box), Android ne donne que
/// 960 × 540 points à l'appli : les trois colonnes de la TV en direct
/// seraient écrasées. On dessine donc l'appli en [tvDesignWidth] de large,
/// exactement comme sous Windows, puis on l'agrandit pour remplir l'écran.
///
/// Seulement sur Android en paysage : un téléphone en portrait garde sa
/// taille normale.
Widget withTvScale(BuildContext context, Widget child) {
  if (!Platform.isAndroid) return child;
  final media = MediaQuery.of(context);
  final size = media.size;
  if (size.width <= size.height || size.width >= tvDesignWidth) return child;

  final scale = size.width / tvDesignWidth;
  final design = Size(tvDesignWidth, size.height / scale);
  EdgeInsets unscale(EdgeInsets e) => e / scale;

  return FittedBox(
    fit: BoxFit.fill,
    alignment: Alignment.topLeft,
    child: SizedBox.fromSize(
      size: design,
      child: MediaQuery(
        data: media.copyWith(
          size: design,
          // Les images se décodent toujours à la résolution réelle de l'écran.
          devicePixelRatio: media.devicePixelRatio * scale,
          padding: unscale(media.padding),
          viewPadding: unscale(media.viewPadding),
          viewInsets: unscale(media.viewInsets),
        ),
        child: child,
      ),
    ),
  );
}
