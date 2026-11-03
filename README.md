# Power Dialog Countdown pour GNOME

Cette extension affiche le temps restant, seconde par seconde, dans la boîte de dialogue d’extinction de GNOME. Quand cette boîte est ouverte, un deuxième appui sur le bouton Power confirme l’extinction.

## Compatibilité

- Ubuntu 24.04, GNOME Shell 46, session X11 ou Wayland.
- Le bouton Power doit correspondre au code XKB `124`, utilisé par cette extension. La vérification diffère selon le type de session.
- L’action du bouton Power doit être réglée sur `interactive`.

Pour vérifier la session et le réglage actuel :

```bash
echo "$XDG_SESSION_TYPE"
gnome-shell --version
gsettings get org.gnome.settings-daemon.plugins.power power-button-action
```

## Installation automatique

Depuis la racine du dépôt, ouvrez un terminal dans votre session GNOME X11 ou Wayland et exécutez :

```bash
./install.sh
```

N’utilisez pas `sudo`. Le script vérifie Ubuntu 24.04 et GNOME Shell 46. Sous X11, il vérifie que le code `124` correspond à `XF86PowerOff` ; sous Wayland, il vérifie que le raccourci Power de GNOME contient `XF86PowerOff`. Il sauvegarde une version déjà installée, copie les fichiers dans votre compte, règle l’action du bouton Power sur `interactive` et inscrit son UUID dans les extensions activées pour la prochaine session. Si une étape essentielle échoue, il tente de restaurer l’ancienne version et les réglages précédents. Le chemin de la sauvegarde est affiché à la fin.

Déconnectez-vous puis reconnectez-vous à GNOME pour charger et activer la nouvelle version. GNOME 46 ne découvre pas une extension copiée pendant la session en cours : le message « Extension does not exist » avant reconnexion est attendu.

Pour vérifier l’état de l’extension :

```bash
gnome-extensions info ubuntu-power-countdown@local
```

Appuyez une fois sur Power pour ouvrir la boîte de dialogue d’extinction. Le compte à rebours doit s’afficher en secondes ; un deuxième appui confirme l’extinction. **Enregistrez votre travail avant cet essai.**

## Mise à jour

Après une modification de `extension.js`, relancez `./install.sh`, puis déconnectez-vous et reconnectez-vous pour charger la nouvelle version.

## Désinstallation

```bash
gnome-extensions disable ubuntu-power-countdown@local
rm -r ~/.local/share/gnome-shell/extensions/ubuntu-power-countdown@local
```

Le réglage du bouton Power peut être modifié séparément avec `gsettings` si nécessaire.
