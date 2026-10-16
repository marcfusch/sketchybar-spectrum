# sketchybar-spectrum

Un analyseur de spectre façon MiniMeters, affiché dans un emplacement vide de SketchyBar.

Le son du Mac est capturé par un process tap Core Audio (pas besoin de BlackHole), analysé par FFT avec Accelerate, puis dessiné dans une fenêtre transparente posée exactement sur un item SketchyBar vide.

## Prérequis

* macOS 14.2 ou plus récent (process taps)
* Xcode ou les Command Line Tools (Swift 5.10 ou plus récent)
* SketchyBar, de préférence avec `sticky=on`

## Installation

```sh
make run
```

Compile, installe l'app dans `~/Applications`, crée la commande `sketchyspectrum` dans `/opt/homebrew/bin` (changeable avec `BINDIR=`), crée la config si elle manque, puis (re)lance le service. Au premier lancement, macOS demande l'accès « audio du système ».

Ensuite, dans la config SketchyBar, à l'endroit où tu veux le spectre (par exemple dans la section `# Center`) :

```sh
source "$HOME/Documents/git/sketchybar-spectrum/sketchybar/spectrum.sh"
```

Ce script réserve seulement l'item `spectrum` ; le service le retrouve tout seul et règle sa largeur selon `width`.

## Service

Comme yabai et skhd, l'app tourne en LaunchAgent (`com.marcfusch.SketchySpectrum`) : lancée à la connexion, relancée si elle plante.

```sh
sketchyspectrum --start-service
sketchyspectrum --stop-service
sketchyspectrum --restart-service
sketchyspectrum --install-service     # écrit seulement le plist
sketchyspectrum --uninstall-service
```

| Cible make | Effet |
|---|---|
| `make run` | build, installation, redémarrage du service |
| `make demo` | arrête le service et lance un signal synthétique (`make run` pour revenir) |
| `make logs` | suit `/tmp/sketchyspectrum_$USER.err.log` |
| `make uninstall` | retire le service, l'app et la commande (la config reste) |
| `make reset-permission` | oublie l'accès audio accordé à l'app |

## Configuration

`~/.config/sketchybar-spectrum/config.json`, au format JSON5 (commentaires acceptés), copié depuis `config.example.json`. Toutes les clés sont facultatives, il est rechargé dès qu'il change, et les clés inconnues sont signalées dans les logs.

**Placement**

| Clé | Rôle |
|---|---|
| `item` | nom de l'item SketchyBar recouvert |
| `width`, `height` | taille du spectre en points ; `width` redimensionne aussi l'item |
| `padding`, `y_offset` | marge horizontale dans l'item, décalage vertical (positif vers le haut) |
| `sketchybar` | chemin du binaire `sketchybar`, si ce n'est ni `/opt/homebrew/bin` ni `/usr/local/bin` |

**Apparence**

| Clé | Rôle |
|---|---|
| `colors` | couleurs du remplissage, du plus faible au plus fort (`0xAARRGGBB` ou `#RRGGBB`) |
| `color_mode` | `level` colore selon le niveau, `frequency` en dégradé des graves aux aigus |
| `fill_opacity` | opacité du remplissage |
| `line_color`, `line_width` | contour ; `line_width` à 0 le masque |
| `grid`, `grid_color` | lignes de fréquences, les décades plus marquées |

**Analyse** (les équivalents MiniMeters entre parenthèses)

| Clé | Rôle |
|---|---|
| `fft_size` | échantillons par FFT (FFT Size) ; plus grand = graves plus fins mais plus de retard |
| `fast_fft_size`, `crossover` | FFT courte utilisée au dessus de `crossover` Hz, pour que les aigus et les attaques arrivent plus tôt ; 0 la désactive |
| `window` | `hann`, `hamming`, `blackman`, `blackman_harris`, `flat_top`, `rectangular` |
| `scale` | `log`, `mel` ou `linear` (FFT Scale) |
| `min_freq`, `max_freq` | plage de fréquences |
| `min_db`, `max_db` | niveaux affichés en bas et en haut |
| `tilt` | dB par octave autour de 1 kHz (Tilt) |
| `smoothing` | 0 à 0.99, ou 0 à 99 : part de la frame précédente gardée à 60 fps (Smoothing) |

**Comportement**

| Clé | Rôle |
|---|---|
| `fps` | 0 suit la fréquence de l'écran |
| `hide_when_silent`, `silence_timeout` | masque le spectre et met le rendu en pause après N secondes de silence |

Signaux : `pkill -HUP -x SketchySpectrum` recharge la config, `pkill -USR1 -x SketchySpectrum` recalcule la position.

## Fonctionnement

1. `PlaybackMonitor` regarde deux fois par seconde si une autre app joue du son. Seulement dans ce cas, `AudioTap` crée le process tap, car une capture active empêche la mise en veille du Mac ; il est relâché 15 s après le dernier son.
2. Le tap mélange gauche et droite en mono dans un ring buffer.
3. À chaque image de l'écran, `Channel` lit les derniers échantillons, calcule les deux FFT, les ramène sur une colonne par pixel, applique le tilt, la plage en dB et le lissage.
4. `SpectrumPainter` écrit directement les pixels (remplissage, grille, contour) et Core Animation affiche l'image.
5. `SpectrumController` place la fenêtre sur l'item, au niveau juste au dessus de la barre, dans un space privé comme `sticky=on` pour qu'elle ne glisse pas entre les bureaux. Il ne réinterroge SketchyBar que quand ses fenêtres changent.

## Organisation du code

```
Sources/SketchySpectrum/
  App/        démarrage, arguments, service, config, boucle d'affichage
  Audio/      process tap, détection de lecture, ring buffer, source de démo
  Analysis/   FFT, fenêtres, échelles, colonnes, lissage
  Display/    fenêtre, vue, rendu bitmap
  Bar/        dialogue avec SketchyBar et ses fenêtres
```

## Dépannage

* **Rien ne s'affiche** : c'est normal en silence (`hide_when_silent`). Sinon, regarder `make logs`, et vérifier que l'item existe : `sketchybar --query spectrum`.
* **Plus rien n'est capté après un rebuild** : la signature ad hoc change à chaque build ; `make reset-permission` puis `make run`.
* **Délai au démarrage** : quand un son commence après un long silence, compter environ 2 s, le temps de créer le tap.
* **Consommation** : presque nulle en silence ; environ 4 % d'un cœur de M1 pendant la lecture.
