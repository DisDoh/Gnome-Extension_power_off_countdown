import Clutter from 'gi://Clutter';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';
import {EndSessionDialog} from 'resource:///org/gnome/shell/ui/endSessionDialog.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as ModalDialog from 'resource:///org/gnome/shell/ui/modalDialog.js';

export default class PowerDialogCountdown extends Extension {
    enable() {
        this._injectionManager = new InjectionManager();
        this._injectionManager.overrideMethod(EndSessionDialog.prototype, '_sync',
            originalSync => function (...args) {
                if (this._type !== 1 && this._type !== 2 && this._type !== 3)
                    return originalSync.apply(this, args);

                const totalSeconds = this._totalSecondsToStayOpen;
                try {
                    this._totalSecondsToStayOpen = Math.max(0, Math.ceil(this._secondsLeft));
                    return originalSync.apply(this, args);
                } finally {
                    this._totalSecondsToStayOpen = totalSeconds;
                }
            });

        this._confirmingPowerOff = false;
        this._dialogOpenedId = Main.endSessionDialog.connect('opened', () => {
            this._confirmingPowerOff = false;
            this._bindPowerKey(true);
        });
        this._dialogClosedId = Main.endSessionDialog.connect('closed', () => {
            this._restorePowerBinding();
        });

        // The media-keys daemon may register its shortcut after extensions
        // start. Refresh it again when the first press opens the dialog.
        this._bindPowerKey();
        this._injectionManager.overrideMethod(Main.shellDBusService,
            '_emitAcceleratorActivated', originalEmit => (action, ...args) => {
                if (action === this._powerAction && this._confirmPowerOff())
                    return;
                return originalEmit.call(Main.shellDBusService, action, ...args);
            });
        this._acceleratorId = global.display.connect('accelerator-activated',
            (_display, action) => {
                if (this._ownPowerGrab && action === this._powerAction)
                    this._confirmPowerOff();
            });

        // Keep a fallback for configurations where the key reaches the stage.
        this._stageEventId = global.stage.connect('captured-event', (_actor, event) => {
            if (event.type() !== Clutter.EventType.KEY_PRESS ||
                event.get_key_symbol() !== Clutter.KEY_XF86PowerOff)
                return Clutter.EVENT_PROPAGATE;
            return this._confirmPowerOff() ? Clutter.EVENT_STOP : Clutter.EVENT_PROPAGATE;
        });
    }

    _bindPowerKey(allowOwnGrab = false) {
        // GNOME 46's evdev XKB keymap assigns the Power key code 124 on
        // both X11 and Wayland. The symbol grab below covers missing bindings.
        let action = global.display.get_keybinding_action(124, 0);
        if (action === Meta.KeyBindingAction.NONE && allowOwnGrab) {
            action = global.display.grab_accelerator('XF86PowerOff',
                Meta.KeyBindingFlags.IGNORE_AUTOREPEAT);
            this._ownPowerGrab = action !== Meta.KeyBindingAction.NONE;
        }
        if (action === Meta.KeyBindingAction.NONE) {
            if (allowOwnGrab)
                console.warn('Power Dialog Countdown: unable to bind Power while shutdown dialog is open');
            return;
        }

        const name = Meta.external_binding_name_for_action(action);
        if (this._powerBindingName && this._powerBindingName !== name)
            this._restorePowerBinding();

        if (!this._powerBindingName) {
            this._powerBindingName = name;
            this._previousPowerModes = Main.wm._allowedKeybindings[name];
        }
        this._powerAction = action;
        // The shutdown dialog has SYSTEM_MODAL mode; GNOME's default Power
        // binding does not include it, so the second press is filtered out.
        Main.wm.allowKeybinding(name,
            (this._previousPowerModes ?? 0) | Shell.ActionMode.SYSTEM_MODAL);
        if (allowOwnGrab)
            console.log(`Power Dialog Countdown: dialog Power action ${action} ready`);
    }

    _restorePowerBinding() {
        if (!this._powerBindingName)
            return;
        Main.wm.allowKeybinding(this._powerBindingName,
            this._previousPowerModes ?? Shell.ActionMode.NONE);
        if (this._ownPowerGrab)
            global.display.ungrab_accelerator(this._powerAction);
        this._ownPowerGrab = false;
        this._powerBindingName = null;
        this._powerAction = Meta.KeyBindingAction.NONE;
    }

    _confirmPowerOff() {
        const dialog = Main.endSessionDialog;
        if (dialog._type !== 1 ||
            dialog.state !== ModalDialog.State.OPENED ||
            this._confirmingPowerOff)
            return false;

        this._confirmingPowerOff = true;
        console.log('Power Dialog Countdown: second Power press confirms shutdown');
        dialog._confirm('ConfirmedShutdown').catch(logError);
        return true;
    }

    disable() {
        global.stage.disconnect(this._stageEventId);
        global.display.disconnect(this._acceleratorId);
        Main.endSessionDialog.disconnect(this._dialogOpenedId);
        Main.endSessionDialog.disconnect(this._dialogClosedId);
        this._restorePowerBinding();
        this._injectionManager.clear();
        this._injectionManager = null;
    }
}
