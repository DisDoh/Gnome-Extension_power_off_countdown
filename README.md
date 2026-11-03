# Power Dialog Countdown for GNOME

This extension shows the remaining time, second by second, in GNOME's shutdown dialog. When the dialog is open, pressing the Power button a second time confirms shutdown.

## Compatibility

- Ubuntu 24.04, GNOME Shell 46, X11 or Wayland session.
- The Power button must use XKB keycode `124`, which this extension uses. The check depends on the session type.
- The Power button action must be set to `interactive`.

To check your session and current setting:

```bash
echo "$XDG_SESSION_TYPE"
gnome-shell --version
gsettings get org.gnome.settings-daemon.plugins.power power-button-action
```

## Automatic installation

From the repository root, open a terminal in your GNOME X11 or Wayland session and run:

```bash
./install.sh
```

Do not use `sudo`. The script checks for Ubuntu 24.04 and GNOME Shell 46. On X11, it checks that keycode `124` maps to `XF86PowerOff`; on Wayland, it checks that GNOME's Power shortcut contains `XF86PowerOff`. It backs up any existing installation, copies the files into your user account, sets the Power button action to `interactive`, and adds the extension's UUID to the enabled extensions for the next session. If an essential step fails, it attempts to restore the previous version and settings. The backup path is displayed at the end.

Log out and back in to GNOME to load and enable the new version. GNOME 46 does not discover an extension copied during the current session: the message “Extension does not exist” before you log back in is expected.

To check the extension's status:

```bash
gnome-extensions info ubuntu-power-countdown@local
```

Press Power once to open the shutdown dialog. The countdown should appear in seconds; a second press confirms shutdown. **Save your work before trying this.**

## Updating

After changing `extension.js`, run `./install.sh` again, then log out and back in to load the new version.

## Uninstalling

```bash
gnome-extensions disable ubuntu-power-countdown@local
rm -r ~/.local/share/gnome-shell/extensions/ubuntu-power-countdown@local
```

You can change the Power button setting separately with `gsettings` if needed.
