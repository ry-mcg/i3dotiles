#!/usr/bin/env bash
# Reverses install.sh: removes the symlinks it created under ~/.config
# (restoring any .bak backup it made), and optionally removes the packages
# it installed. Run from inside the repo: ./uninstall.sh [options]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PURGE_PACKAGES=0
REMOVE_WALLPAPER=0
ASK=1

for arg in "$@"; do
    case "$arg" in
        --purge-packages)   PURGE_PACKAGES=1; ASK=0 ;;
        --keep-packages)    PURGE_PACKAGES=0; ASK=0 ;;
        --remove-wallpaper) REMOVE_WALLPAPER=1 ;;
        -h|--help)
            cat <<EOF
Usage: ./uninstall.sh [--purge-packages | --keep-packages] [--remove-wallpaper]

Always removes the symlinks install.sh created under ~/.config, restoring
any *.bak backup it made along the way.

  --purge-packages    also uninstall the packages install.sh installed
                      (skips the confirmation prompt)
  --keep-packages     skip package removal entirely, no prompt
  --remove-wallpaper  also delete ~/Pictures/wallpaper_4k.png
EOF
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

confirm() {
    local prompt="$1"
    read -rp "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

echo "==> Stopping polybar/picom/copyq"
killall -q polybar picom copyq 2>/dev/null || true

unlink_file() {
    local dest="$1"
    if [ -L "$dest" ]; then
        rm "$dest"
        echo "==> Removed symlink $dest"
        if [ -e "$dest.bak" ]; then
            mv "$dest.bak" "$dest"
            echo "==> Restored backup $dest.bak -> $dest"
        fi
    fi
}

echo "==> Removing symlinked configs"
for app in i3 polybar rofi picom kitty copyq networkmanager-dmenu; do
    [ -d "$REPO_DIR/config/$app" ] || continue
    while IFS= read -r -d '' src; do
        rel="${src#"$REPO_DIR"/config/"$app"/}"
        dest="$HOME/.config/$app/$rel"
        unlink_file "$dest"
    done < <(find "$REPO_DIR/config/$app" -type f ! -name '*.template' -print0)
done

# polybar/config.ini is generated (from config.ini.template) rather than
# symlinked, since it bakes in machine-specific battery/thermal-zone/module
# values - unlink_file wouldn't touch it, so handle it explicitly.
POLYBAR_CONF="$HOME/.config/polybar/config.ini"
if [ -e "$POLYBAR_CONF" ] && [ ! -L "$POLYBAR_CONF" ]; then
    rm -f "$POLYBAR_CONF"
    echo "==> Removed generated $POLYBAR_CONF"
    if [ -e "$POLYBAR_CONF.bak" ]; then
        mv "$POLYBAR_CONF.bak" "$POLYBAR_CONF"
        echo "==> Restored backup $POLYBAR_CONF.bak -> $POLYBAR_CONF"
    fi
fi

if [ "$REMOVE_WALLPAPER" -eq 1 ]; then
    rm -f "$HOME/Pictures/wallpaper_4k.png"
    echo "==> Removed wallpaper"
fi

TOUCHPAD_CONF="/etc/X11/xorg.conf.d/40-libinput-touchpad.conf"
if [ -e "$TOUCHPAD_CONF" ]; then
    sudo rm -f "$TOUCHPAD_CONF"
    echo "==> Removed $TOUCHPAD_CONF"
    if [ -e "$TOUCHPAD_CONF.bak" ]; then
        sudo mv "$TOUCHPAD_CONF.bak" "$TOUCHPAD_CONF"
        echo "==> Restored backup $TOUCHPAD_CONF.bak -> $TOUCHPAD_CONF"
    fi
fi

if [ "$ASK" -eq 1 ]; then
    confirm "Also uninstall the packages install.sh installed (i3, polybar, rofi, kitty, etc)?" && PURGE_PACKAGES=1
fi

if [ "$PURGE_PACKAGES" -eq 1 ]; then
    # bluez, pipewire, and wireplumber are deliberately excluded, same as
    # networkmanager - on a machine that also runs a full DE (KDE, GNOME,
    # etc.) those are load-bearing system packages (e.g. bluez-qt,
    # pipewire-session-manager, qt6-multimedia, xdg-desktop-portal all
    # depend on them), not i3-rice-specific, and pacman will refuse the
    # whole transaction if asked to remove them anyway.
    PKGS=(
        i3-wm polybar rofi copyq picom feh playerctl xdotool
        maim xclip slop i3lock networkmanager-dmenu
        rofimoji ttf-meslo-nerd
        kitty nemo asusctl rog-control-center
    )
    installed=()
    for p in "${PKGS[@]}"; do
        pacman -Qi "$p" >/dev/null 2>&1 && installed+=("$p")
    done
    if [ "${#installed[@]}" -gt 0 ]; then
        echo "==> Removing packages: ${installed[*]}"
        echo "    (networkmanager, bluez, pipewire, and wireplumber are left"
        echo "    installed - they're commonly load-bearing for other"
        echo "    software, including a full desktop environment.)"
        sudo pacman -Rns "${installed[@]}"
    else
        echo "==> None of the installed-by-install.sh packages are present, nothing to remove."
    fi
fi

echo "==> Done."
