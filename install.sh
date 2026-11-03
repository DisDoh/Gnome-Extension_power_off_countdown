#!/usr/bin/env bash
set -Eeuo pipefail

uuid='ubuntu-power-countdown@local'
power_schema='org.gnome.settings-daemon.plugins.power'
power_key='power-button-action'
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/gnome-extension/$uuid"

fail() {
    printf 'Erreur : %s\n' "$*" >&2
    exit 1
}

info() {
    printf '%s\n' "$*"
}

for command_name in gnome-shell gsettings gjs mktemp install; do
    command -v "$command_name" >/dev/null 2>&1 || fail "commande manquante : $command_name"
done

[[ $EUID -ne 0 ]] || fail 'exécutez ce script avec votre compte utilisateur, sans sudo.'
case ${XDG_SESSION_TYPE:-} in
    x11)
        [[ -n ${DISPLAY:-} ]] || fail 'la variable DISPLAY est absente ; lancez le script depuis la session graphique X11.'
        command -v xmodmap >/dev/null 2>&1 || fail 'commande manquante pour X11 : xmodmap'
        ;;
    wayland)
        [[ -n ${WAYLAND_DISPLAY:-} ]] || fail 'la variable WAYLAND_DISPLAY est absente ; lancez le script depuis la session graphique Wayland.'
        ;;
    *)
        fail 'une session GNOME X11 ou Wayland est nécessaire.'
        ;;
esac
[[ -n ${HOME:-} ]] || fail 'la variable HOME est absente.'
[[ -f $source_dir/extension.js && -f $source_dir/metadata.json ]] || fail 'fichiers de l’extension introuvables.'

# The extension uses GNOME Shell 46 APIs and XKB keycode 124.
[[ -r /etc/os-release ]] || fail 'impossible de vérifier la version d’Ubuntu.'
# shellcheck source=/dev/null
source /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 24.04 ]] || fail 'cette extension est prévue pour Ubuntu 24.04.'
shell_version=$(gnome-shell --version) || fail 'impossible de vérifier la version de GNOME Shell.'
[[ $shell_version =~ ([0-9]+)\. ]] || fail "version de GNOME Shell non reconnue : $shell_version"
[[ ${BASH_REMATCH[1]} == 46 ]] || fail "GNOME Shell 46 est requis (détecté : $shell_version)."
if [[ $XDG_SESSION_TYPE == x11 ]]; then
    xmodmap_output=$(xmodmap -pk) || fail 'impossible de lire le clavier X11 avec xmodmap.'
    awk '$1 == "124" && /XF86PowerOff/ { found = 1 } END { exit !found }' <<< "$xmodmap_output" ||
        fail 'le code X11 124 ne correspond pas à XF86PowerOff sur ce clavier.'
else
    power_binding=$(gsettings get org.gnome.settings-daemon.plugins.media-keys power-static) ||
        fail 'impossible de lire le raccourci du bouton Power.'
    [[ $power_binding == *XF86PowerOff* ]] ||
        fail 'le raccourci Wayland du bouton Power ne contient pas XF86PowerOff.'
fi

[[ $(gsettings writable "$power_schema" "$power_key") == true ]] ||
    fail 'le réglage du bouton Power est verrouillé ou indisponible.'
previous_power_action=$(gsettings get "$power_schema" "$power_key") ||
    fail 'impossible de lire le réglage actuel du bouton Power.'
for key in enabled-extensions disabled-extensions; do
    [[ $(gsettings writable org.gnome.shell "$key") == true ]] ||
        fail "le réglage GNOME $key est verrouillé ou indisponible."
done
[[ $(gsettings get org.gnome.shell disable-user-extensions) == false ]] ||
    fail 'les extensions utilisateur sont désactivées dans GNOME.'
[[ $(gsettings get org.gnome.shell allow-extension-installation) == true ]] ||
    fail 'GNOME interdit l’installation des extensions utilisateur.'
previous_enabled_extensions=$(gsettings get org.gnome.shell enabled-extensions) ||
    fail 'impossible de lire les extensions activées.'
previous_disabled_extensions=$(gsettings get org.gnome.shell disabled-extensions) ||
    fail 'impossible de lire les extensions désactivées.'

data_home=${XDG_DATA_HOME:-$HOME/.local/share}
extensions_dir="$data_home/gnome-shell/extensions"
destination="$extensions_dir/$uuid"
backup_parent="$data_home/gnome-shell/extension-backups"
staging=''
backup_dir=''
old_moved=false
new_moved=false
power_touched=false
extension_settings_touched=false
success=false

cleanup() {
    local status=$?
    trap - EXIT
    if [[ $success != true ]]; then
        if [[ $power_touched == true ]] &&
           [[ $(gsettings get "$power_schema" "$power_key" 2>/dev/null) != "$previous_power_action" ]]; then
            gsettings set "$power_schema" "$power_key" "$previous_power_action" ||
                printf 'Attention : restaurez le réglage Power à %s\n' "$previous_power_action" >&2
        fi
        if [[ $extension_settings_touched == true ]]; then
            gsettings set org.gnome.shell enabled-extensions "$previous_enabled_extensions" ||
                printf 'Attention : restaurez la liste des extensions activées.\n' >&2
            gsettings set org.gnome.shell disabled-extensions "$previous_disabled_extensions" ||
                printf 'Attention : restaurez la liste des extensions désactivées.\n' >&2
        fi
        if [[ $new_moved == true ]]; then
            rm -r -- "$destination" || printf 'Attention : impossible de retirer %s\n' "$destination" >&2
        fi
        if [[ $old_moved == true ]]; then
            mv -- "$backup_dir/$uuid" "$destination" ||
                printf 'Attention : restaurez l’ancienne extension depuis %s\n' "$backup_dir/$uuid" >&2
        fi
        [[ $status -eq 0 ]] || printf 'Installation annulée ; les modifications ont été restaurées si possible.\n' >&2
    fi
    if [[ -n $staging && -d $staging ]]; then
        rm -r -- "$staging"
    fi
    if [[ $success != true && -n $backup_dir && -d $backup_dir ]]; then
        rmdir -- "$backup_dir" 2>/dev/null || true
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p -- "$extensions_dir"
[[ ! -L $destination ]] || fail "destination inattendue (lien symbolique) : $destination"
[[ ! -e $destination || -d $destination ]] || fail "destination inattendue : $destination"

staging=$(mktemp -d "$extensions_dir/.${uuid}.tmp.XXXXXX")
install -m 0644 -- "$source_dir/extension.js" "$staging/extension.js"
install -m 0644 -- "$source_dir/metadata.json" "$staging/metadata.json"

if [[ -d $destination ]]; then
    mkdir -p -- "$backup_parent"
    backup_dir=$(mktemp -d "$backup_parent/${uuid}.XXXXXX")
    mv -- "$destination" "$backup_dir/$uuid"
    old_moved=true
fi

mv -- "$staging" "$destination"
staging=''
new_moved=true

if [[ $previous_power_action != "'interactive'" ]]; then
    power_touched=true
    gsettings set "$power_schema" "$power_key" 'interactive'
    [[ $(gsettings get "$power_schema" "$power_key") == "'interactive'" ]] ||
        fail 'le réglage du bouton Power n’a pas été appliqué.'
fi

extension_settings_touched=true
gjs -c '
const Gio = imports.gi.Gio;
const uuid = "ubuntu-power-countdown@local";
const settings = new Gio.Settings({schema_id: "org.gnome.shell"});
const disabled = settings.get_strv("disabled-extensions").filter(id => id !== uuid);
if (!settings.set_strv("disabled-extensions", disabled))
    throw new Error("Impossible de retirer l’extension de la liste désactivée");
const enabled = settings.get_strv("enabled-extensions");
if (!enabled.includes(uuid))
    enabled.push(uuid);
if (!settings.set_strv("enabled-extensions", enabled))
    throw new Error("Impossible d’activer l’extension pour la prochaine session");
Gio.Settings.sync();
if (!settings.get_strv("enabled-extensions").includes(uuid) ||
    settings.get_strv("disabled-extensions").includes(uuid))
    throw new Error("Les réglages de l’extension n’ont pas été enregistrés");
'

success=true
info "Extension installée dans $destination"
if [[ -n $backup_dir ]]; then
    info "Ancienne version sauvegardée dans $backup_dir/$uuid"
fi
if [[ $previous_power_action != "'interactive'" ]]; then
    info 'Action du bouton Power réglée sur interactive.'
fi

info 'Activation enregistrée pour la prochaine session GNOME.'
info "Déconnectez-vous puis reconnectez-vous à GNOME $XDG_SESSION_TYPE pour charger et activer cette version."
