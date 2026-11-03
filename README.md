# Power Dialog Countdown for GNOME

This extension shows the remaining time, second by second, in GNOME's shutdown dialog. When the dialog is open, pressing the Power button a second time confirms shutdown.

## Compatibility

- Ubuntu 24.04, GNOME Shell 46, X11 or Wayland session.
- The Power button must use XKB keycode `124`, which this extension uses. The check depends on the session type.

## Installation

Use the install script for installation and configuration. From the repository root, open a terminal in your GNOME X11 or Wayland session and run:

```bash
./install.sh
```

Do not use `sudo`. The script checks compatibility and the Power key mapping, backs up an existing installation, installs the extension, sets the Power button action to `interactive`, and enables the extension for the next session. If an essential step fails, it attempts to restore the previous version and settings. It displays the backup path when a backup is made.

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
