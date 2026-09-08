# Publication App Store — NexoraTV (iPhone / iPad)

Tout se remplit dans **App Store Connect → Apps → NexoraTV**.
Le binaire est déjà sur TestFlight, il n'y a que la fiche + la soumission.

---

## 0. Pré-requis à préparer avant de commencer

| Élément | Où / comment |
|---|---|
| **Politique de confidentialité (URL publique)** | ✅ Page créée : `https://<domaine-nexoratv>/confidentialite-application` (déployée via Vercel). C'est cette URL qui va dans le champ « Privacy Policy URL ». |
| **URL de support** | Une page contact / WhatsApp du site NexoraTV, ou `https://nexoratv…/support` |
| **Captures d'écran** | iPhone 6.7" (1290×2796) **et** 6.5" (1242×2688) obligatoires. iPad 12.9" (2048×2732) si tu actives iPad. Voir §4. |
| **Compte Xtream de review** | Compte **permanent (sans expiration)** créé sur ton panel, réservé à Apple. Contenu **exclusivement légal / gratuit** (chaînes publiques, chaînes FAST, contenu libre). ⚠️ Aucun flux premium (chaînes payantes, sport PPV, plateformes SVOD) : le reviewer cherche exactement ça → rejet 5.2.3 immédiat. Noter : URL serveur, identifiant, mot de passe. |

---

## 1. Informations sur l'app (section « Général »)

- **Nom** : `NexoraTV`
- **Sous-titre** (30 car. max) :
  `Lecteur IPTV M3U & Xtream`
- **Catégorie principale** : Divertissement
- **Catégorie secondaire** : (aucune, ou Utilitaires)

---

## 2. Version à publier (ex. 1.3.1)

### Texte promotionnel (170 car., modifiable sans review)
```
Lisez votre compte Xtream Codes : TV en direct, films et séries, favoris, reprise de lecture. Vous fournissez votre propre source.
```

### Description
```
NexoraTV est un lecteur IPTV générique. Connectez votre compte Xtream Codes
et NexoraTV organise vos contenus : télévision en direct, films et séries.

L'application ne fournit aucune chaîne ni aucun contenu : vous utilisez votre
propre source.

FONCTIONNALITÉS
• Comptes Xtream Codes (TV / Films / Séries séparés automatiquement)
• Accueil : reprise de lecture + sections TV, Films, Séries
• Plusieurs sources commutables et éditables
• Navigation par catégorie, recherche par section et recherche globale
• Films en grille de jaquettes (bascule liste / grille)
• Séries : saisons et épisodes
• Favoris par chaîne
• Lecteur plein écran : zapping, saisie du numéro de chaîne, avance/retour
  sur les films et séries, pistes audio et sous-titres, reprise de lecture
• Cache par source avec secours hors-ligne
• Mot de passe Xtream stocké dans le trousseau iOS, jamais transmis à un tiers

NexoraTV ne collecte aucune donnée personnelle.
```

### Nouveautés de cette version
```
Première version iOS de NexoraTV.
```
(pour les suivantes : reprendre `CHANGELOG_LATEST.md`)

### Mots-clés (100 car., séparés par des virgules, sans espaces superflus)
```
iptv,xtream,xtream codes,lecteur,tv,streaming,chaines,films,series,player,vod,m3u
```

### URL marketing (optionnel)
Laisser vide ou mettre le site NexoraTV.

---

## 3. Général de la version

- **URL de support** : (ta page support)
- **URL marketing** : optionnel
- **Version** : `1.3.1` (doit correspondre au `CFBundleShortVersionString` du build)
- **Build** : sélectionner le build TestFlight (bouton « + » à côté de « Build »)
- **Copyright** : `2026 Gabriel Defressine`
- **Coordonnées de la personne-ressource** (Contact review) : tes nom / téléphone / email

---

## 4. Captures d'écran

Le plus simple sans Mac : lance l'app iOS via **TestFlight sur ton iPhone**, fais
des captures (Volume haut + latéral), recadre si besoin.

- **iPhone 6.7"** : au moins 3, idéalement 5 (Accueil, grille Films, lecteur,
  détail série, recherche)
- **iPhone 6.5"** : Apple accepte de réutiliser les mêmes visuels redimensionnés,
  mais il faut fournir le format. Si ton iPhone est un modèle 6.7", tu peux
  générer le 6.5" avec un simple redimensionnement (ratio identique 19.5:9).
- Pas de cadre d'appareil, pas de mockup obligatoire.

⚠️ Les captures ne doivent montrer que du contenu **légal / neutre** (chaînes
publiques, écrans vides, contenu libre de droits). Pas de logo de chaîne payante.

---

## 5. Classification par âge

Questionnaire → réponds honnêtement :
- **Accès web sans restriction** : **Oui** (l'app peut charger n'importe quel flux)
  → cela force la note **17+**. C'est normal et attendu pour un lecteur IPTV.
- Tout le reste : Aucun / Non.

---

## 6. Confidentialité de l'app (App Privacy)

Section **« Confidentialité de l'app »** → **« Aucune donnée collectée »**.

Justification (vrai pour le code actuel) : aucun SDK d'analytics, pas de compte,
pas de backend. Les playlists et le mot de passe Xtream restent sur l'appareil
(trousseau iOS). Les seules requêtes réseau vont vers **les serveurs que
l'utilisateur saisit lui-même** + le manifeste de mise à jour (désactivé sur iOS).

- **URL politique de confidentialité** : `https://<domaine-nexoratv>/confidentialite-application`

---

## 7. Prix et disponibilité

- **Prix** : Gratuit (Tier 0)
- **Disponibilité** : tous les pays, ou restreindre si tu veux (ex. France + francophonie)

---

## 8. Notes pour l'App Review (champ « Notes »)

```
NexoraTV est un lecteur multimédia générique pour comptes Xtream Codes et
playlists IPTV. L'application ne fournit, n'héberge et ne diffuse aucun
contenu : l'utilisateur configure sa propre source.

L'app est équivalente à VLC ou Infuse : un lecteur, pas un fournisseur de contenu.

COMPTE DE TEST (Xtream Codes)
Adresse du serveur : http://<TON_SERVEUR>:<PORT>
Identifiant : <REVIEW_USERNAME>
Mot de passe : <REVIEW_PASSWORD>

Étapes :
1. Ouvrir l'app → Ajouter une source → onglet « Xtream Codes »
2. Saisir l'adresse du serveur, l'identifiant et le mot de passe ci-dessus
3. « Vérifier et ajouter » → les chaînes apparaissent, la lecture fonctionne
4. Sections TV / Films / Séries navigables depuis l'accueil

Ce compte donne accès à des chaînes gratuites et publiques uniquement.
```

---

## 9. Export / chiffrement

Déjà réglé dans `Info.plist` (`ITSAppUsesNonExemptEncryption = false`).
Si la question apparaît quand même : **« Non »** (pas de chiffrement propriétaire).

---

## 10. Soumettre

Bouton **« Ajouter pour examen »** puis **« Soumettre à l'examen »**.

- Délai : généralement 24–48 h.
- Rejet possible sur guideline **4.3 (spam)** ou **5.2.3 (droits sur le contenu)** :
  si ça arrive, répondre dans **Resolution Center** en réexpliquant que l'app ne
  fournit aucun contenu (copier les notes reviewer). Souvent 1 aller-retour suffit.

---

## 11. Après acceptation

- Passer la version en **« Publier automatiquement »** ou **manuellement**.
- Les builds suivants : incrémenter `version:` dans `pubspec.yaml`, lancer un
  build Codemagic, il monte sur TestFlight, puis « + Build » sur la fiche →
  soumettre (review plus rapide pour les mises à jour).

---

## Annexe — Politique de confidentialité

✅ Déjà en ligne : **page `/confidentialite-application`** ajoutée au site NexoraTV
(repo `nexoratv-vercel`, fichier `app/confidentialite-application/page.tsx`),
poussée sur `main`. Vérifier que Vercel a bien déployé, puis utiliser
`https://<domaine>/confidentialite-application` comme URL de confidentialité
dans App Store Connect **et** Google Play.

À vérifier sur la page en ligne : la ligne « Contact » renvoie vers `/contact`
du site — s'assurer que cette page fonctionne.
