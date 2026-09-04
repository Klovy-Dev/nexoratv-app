# NexoraTV

Lecteur IPTV multiplateforme (Windows + Android) en Flutter.
Playlists **M3U** (URL) et comptes **Xtream Codes**. Un lien M3U
`.../get.php?username=…&password=…` est reconnu automatiquement comme un
compte Xtream (pour séparer TV / Films / Séries).

## Fonctionnalités

- Accueil : rangée **Reprendre** + 3 sections **TV / Films / Séries**
- Plusieurs sources, commutables, éditables ; vérifiées avant enregistrement
- Mot de passe Xtream stocké dans le trousseau système (`flutter_secure_storage`)
- Navigation par catégorie + recherche par section + **recherche globale**
- Films en **grille de jaquettes** (bascule liste/grille)
- Séries : grille → saisons / épisodes
- Favoris par chaîne
- Lecteur plein écran (media_kit / libmpv) : zapping ↑/↓, **zapping par numéro**,
  seek ←/→ (VOD), pause ␣, plein écran F, pistes audio / sous-titres,
  **reprise de lecture** VOD, barre de progression
- Cache disque par source (durée réglable) + secours hors-ligne
- **Mises à jour intégrées** (Windows + APK)
- Paramètres : cache, lecture, historique, mises à jour

## Distribution Windows — un seul fichier

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
```

Produit **`installer/Output/NexoraTV-Setup-<version>.exe`** (~28 Mo) : un
**installeur unique** à double-cliquer. Il installe dans
`%LOCALAPPDATA%\Programs\NexoraTV`, crée un raccourci « NexoraTV » (menu
Démarrer + Bureau), sans droits admin. Ensuite l'utilisateur lance juste
« NexoraTV » — aucune DLL à gérer.

Build brut (dossier portable) : `flutter build windows --release` →
`build/windows/x64/runner/Release/` (tout le dossier, `NexoraTV.exe` +
DLL + `data/`). L'exe seul ne suffit pas.

APK Android (quand le SDK est installé) : `flutter build apk --release` →
`build/app/outputs/flutter-apk/app-release.apk`.

Prérequis pour l'installeur : **Inno Setup 6**
(`winget install JRSoftware.InnoSetup`).

## Système de mise à jour

1. Héberger un fichier **`update.json`** (voir modèle à la racine) — par ex.
   `raw.githubusercontent.com/<user>/<repo>/main/update.json`.
2. Renseigner cette URL dans **Paramètres → Mises à jour → URL du manifeste**
   (valeur par défaut : `kDefaultUpdateManifestUrl` dans
   `lib/services/storage/settings_repository.dart`).
3. À chaque version : pousser un tag `vX.Y.Z`. Le workflow
   `.github/workflows/release.yml` build le zip Windows + l'APK, crée la
   *GitHub Release*, et met à jour `update.json` sur `main`.
4. L'app compare `pubspec.yaml > version` au manifeste, propose le
   téléchargement, puis lance l'installeur (Windows) ou l'APK (Android,
   permission `REQUEST_INSTALL_PACKAGES`).

Format `update.json` :
```json
{
  "version": "1.1.0",
  "notes": "…",
  "windows_url": "https://…/NexoraTV-1.1.0-windows-x64.zip",
  "android_url":  "https://…/nexoratv-1.1.0.apk",
  "mandatory": false
}
```

## Prérequis dev

- Flutter 3.47+ (`C:\src\flutter`, dans le PATH)
- **Windows** : Visual Studio 2022 + « Développement Desktop en C++ », Mode dev
- **Android** : Android Studio + SDK (API 23+)  *(pas encore installé)*

## Architecture

```
lib/
  models/       PlaylistSource, Channel, Series
  services/
    m3u_parser.dart / xtream_client.dart    (parsing en isolate)
    playlist_service.dart                   Source -> LoadedPlaylist
    update_service.dart                     manifeste + téléchargement + install
    storage/    source · favorites · settings · watch_history · playlist_cache
  state/        providers Riverpod
  features/
    home/       aiguillage + accueil (LibraryHome)
    catalog/    CatalogBrowser (liste/grille), PosterCard
    series/     grille + détail
    search/     recherche globale
    player/     lecteur (commandes maison)
    settings/   écran Paramètres
    sources/    ajout / édition / gestion
    update/     dialogue de mise à jour
```

## Roadmap

EPG XMLTV · fiches détaillées + TMDB · Android / Android TV · installeur MSIX ·
contrôle parental.
