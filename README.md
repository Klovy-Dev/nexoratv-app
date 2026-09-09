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

Chaque plateforme a **sa propre version** et se release indépendamment via un
tag préfixé :

| Tag poussé        | Ce qui est buildé                     | Par            |
|-------------------|---------------------------------------|----------------|
| `win-v2.1.0`      | Installeur Windows + zip portable     | GitHub Actions |
| `android-v1.5.0`  | APK release                           | GitHub Actions |
| `ios-v1.0.5`      | IPA → TestFlight                      | Codemagic      |
| `v1.4.0` *(ancien schéma)* | Windows **+** Android d'un coup | GitHub Actions |

1. Le workflow `.github/workflows/release.yml` build la (les) plateforme(s)
   concernée(s), crée la *GitHub Release* du tag, et met à jour le **bloc
   correspondant** de `update.json` sur `main` — l'autre plateforme n'est pas
   touchée.
2. L'app lit **un seul** manifeste (`kDefaultUpdateManifestUrl` dans
   `lib/services/storage/settings_repository.dart`, modifiable dans
   **Paramètres → Mises à jour**), y prend le bloc de sa plateforme, compare à
   sa version courante et propose le téléchargement : installeur (Windows) ou
   APK (Android, permission `REQUEST_INSTALL_PACKAGES`).
3. iOS ne consulte pas le manifeste : les MAJ passent par TestFlight /
   l'App Store.

Format `update.json` (bloc par plateforme) :
```json
{
  "windows": {
    "version": "2.1.0",
    "url": "https://…/NexoraTV-Setup-2.1.0.exe",
    "notes": "…",
    "mandatory": false
  },
  "android": {
    "version": "1.5.0",
    "url": "https://…/NexoraTV-1.5.0.apk",
    "notes": "…",
    "mandatory": false
  }
}
```

Les champs à plat (`version`, `windows_url`, `android_url`) restent écrits pour
les clients d'avant la migration — `version` à plat vaut la plus **basse** des
deux plateformes, pour ne jamais proposer un téléchargement inadapté.
`UpdateService.parseManifest` lit les deux formats.

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
