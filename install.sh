#!/usr/bin/env bash
# Sets up this i3 + polybar + rofi + copyq + picom rice on an Arch/CachyOS box.
# Run from inside the cloned repo: ./install.sh [options]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WITH_KITTY=0
WITH_NEMO=0
MODULES_ARG=""
ASK=1

for arg in "$@"; do
    case "$arg" in
        --all)          WITH_KITTY=1; WITH_NEMO=1; ASK=0 ;;
        --with-kitty)   WITH_KITTY=1; ASK=0 ;;
        --with-nemo)    WITH_NEMO=1;  ASK=0 ;;
        --minimal)      WITH_KITTY=0; WITH_NEMO=0; ASK=0 ;;
        --modules=*)    MODULES_ARG="${arg#--modules=}"; ASK=0 ;;
        -h|--help)
            cat <<EOF
Usage: ./install.sh [options]

With no flags, you'll be prompted for each optional component and for
which polybar modules to include in the top bar.

  --all             install every optional component, no prompts
  --minimal         core rice only, skip all optional components
  --with-kitty      also install the kitty terminal
  --with-nemo       also install the nemo file manager
  --modules=a,b,c   top-bar modules to include, comma-separated, from:
                    network,bluetooth,volume,cpu,temperature,memory,battery,clipboard,power
                    (default: all of them)
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

if [ "$ASK" -eq 1 ]; then
    confirm "Install kitty (terminal)?" && WITH_KITTY=1
    confirm "Install nemo (file manager)?" && WITH_NEMO=1
fi

ALL_MODULES=(network bluetooth volume cpu temperature memory battery clipboard power)
declare -A MODULE_DESC=(
    [network]="network / wifi-ethernet status"
    [bluetooth]="bluetooth status + device menu"
    [volume]="volume level + output switcher"
    [cpu]="CPU usage"
    [temperature]="CPU temperature"
    [memory]="memory usage"
    [battery]="battery percentage"
    [clipboard]="clipboard history (copyq)"
    [power]="power menu (lock/suspend/reboot/shutdown)"
)

SELECTED_MODULES=()
if [ -n "$MODULES_ARG" ]; then
    IFS=',' read -ra SELECTED_MODULES <<< "$MODULES_ARG"
    for i in "${!SELECTED_MODULES[@]}"; do
        # tolerate "a, b, c" as well as "a,b,c"
        SELECTED_MODULES[i]="$(echo "${SELECTED_MODULES[i]}" | xargs)"
    done
elif [ "$ASK" -eq 1 ]; then
    for m in "${ALL_MODULES[@]}"; do
        confirm "Include the $m module (${MODULE_DESC[$m]}) in the top bar?" && SELECTED_MODULES+=("$m")
    done
else
    SELECTED_MODULES=("${ALL_MODULES[@]}")
fi

CORE_PKGS=(
    i3-wm polybar rofi copyq picom feh playerctl xdotool
    maim xclip slop i3lock networkmanager networkmanager-dmenu
    rofimoji ttf-meslo-nerd bluez bluez-utils python
    pipewire pipewire-pulse pipewire-alsa wireplumber
)

OPTIONAL_PKGS=()
[ "$WITH_KITTY" -eq 1 ]  && OPTIONAL_PKGS+=(kitty)
[ "$WITH_NEMO" -eq 1 ]   && OPTIONAL_PKGS+=(nemo)

echo "==> Installing packages: ${CORE_PKGS[*]} ${OPTIONAL_PKGS[*]}"
sudo pacman -S --needed "${CORE_PKGS[@]}" "${OPTIONAL_PKGS[@]}"

echo "==> Enabling NetworkManager"
sudo systemctl enable --now NetworkManager.service

echo "==> Enabling bluetooth"
sudo systemctl enable --now bluetooth.service

link_file() {
    local src="$1"
    local dest="$2"

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "==> Backing up existing $dest to $dest.bak"
        mv "$dest" "$dest.bak"
    elif [ -L "$dest" ]; then
        rm "$dest"
    fi

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
}

echo "==> Linking configs (file-by-file, so apps that write runtime state into"
echo "    their config dir - like copyq - don't dump it into this repo. *.template"
echo "    files are skipped here; they're rendered separately, below.)"
for app in i3 polybar rofi picom kitty copyq networkmanager-dmenu; do
    [ -d "$REPO_DIR/config/$app" ] || continue
    while IFS= read -r -d '' src; do
        rel="${src#"$REPO_DIR"/config/"$app"/}"
        dest="$HOME/.config/$app/$rel"
        link_file "$src" "$dest"
        echo "==> Linked $dest -> $src"
    done < <(find "$REPO_DIR/config/$app" -type f ! -name '*.template' -print0)
done

chmod +x "$REPO_DIR"/config/polybar/scripts/*.sh
chmod +x "$REPO_DIR"/config/polybar/launch.sh

echo "==> Detecting battery / AC adapter (/sys/class/power_supply)"
BATTERY=""
ADAPTER=""
for psu in /sys/class/power_supply/*; do
    [ -e "$psu/type" ] || continue
    case "$(cat "$psu/type")" in
        Battery) BATTERY="$(basename "$psu")" ;;
        Mains)   ADAPTER="$(basename "$psu")" ;;
    esac
done
if [ -z "$BATTERY" ]; then
    echo "    No battery found (desktop?) - omitting the battery module."
    SELECTED_MODULES=("${SELECTED_MODULES[@]/battery}")
else
    echo "    battery=$BATTERY adapter=$ADAPTER"
fi

echo "==> Detecting CPU thermal zone (/sys/class/thermal)"
THERMAL_ZONE=0
for tz in /sys/class/thermal/thermal_zone*; do
    [ -e "$tz/type" ] || continue
    case "$(cat "$tz/type")" in
        x86_pkg_temp|k10temp|acpitz)
            THERMAL_ZONE="${tz##*thermal_zone}"
            break
            ;;
    esac
done
echo "    thermal-zone=$THERMAL_ZONE"

# drop any empty slots left by removing "battery" above
compact=()
for m in "${SELECTED_MODULES[@]}"; do
    [ -n "$m" ] && compact+=("$m")
done
SELECTED_MODULES=("${compact[@]}")

MODULES_RIGHT=""
for m in "${SELECTED_MODULES[@]}"; do
    MODULES_RIGHT+=" sep $m"
done
MODULES_RIGHT="${MODULES_RIGHT# sep }"
echo "==> Top-bar modules: $MODULES_RIGHT"

if [ ! -f "$REPO_DIR/config/polybar/config.ini.template" ]; then
    echo "ERROR: $REPO_DIR/config/polybar/config.ini.template is missing - can't generate polybar's config.ini." >&2
    exit 1
fi

POLYBAR_CONF_DEST="$HOME/.config/polybar/config.ini"
if [ -e "$POLYBAR_CONF_DEST" ] && [ ! -L "$POLYBAR_CONF_DEST" ]; then
    echo "==> Backing up existing $POLYBAR_CONF_DEST to $POLYBAR_CONF_DEST.bak"
    mv "$POLYBAR_CONF_DEST" "$POLYBAR_CONF_DEST.bak"
elif [ -L "$POLYBAR_CONF_DEST" ]; then
    rm "$POLYBAR_CONF_DEST"
fi
mkdir -p "$(dirname "$POLYBAR_CONF_DEST")"
sed \
    -e "s|{{MODULES_RIGHT}}|$MODULES_RIGHT|" \
    -e "s|{{BATTERY}}|$BATTERY|" \
    -e "s|{{ADAPTER}}|$ADAPTER|" \
    -e "s|{{THERMAL_ZONE}}|$THERMAL_ZONE|" \
    "$REPO_DIR/config/polybar/config.ini.template" > "$POLYBAR_CONF_DEST"
echo "==> Generated $POLYBAR_CONF_DEST from config.ini.template"

echo "==> Installing wallpaper"
mkdir -p "$HOME/Pictures" "$HOME/Pictures/Screenshots"
cp "$REPO_DIR/wallpaper/wallpaper_4k.png" "$HOME/Pictures/wallpaper_4k.png"

echo "==> Installing touchpad config (two-finger tap = right-click)"
TOUCHPAD_CONF_DEST="/etc/X11/xorg.conf.d/40-libinput-touchpad.conf"
sudo mkdir -p /etc/X11/xorg.conf.d
if [ -e "$TOUCHPAD_CONF_DEST" ]; then
    sudo cp "$TOUCHPAD_CONF_DEST" "$TOUCHPAD_CONF_DEST.bak"
    echo "    Backed up existing $TOUCHPAD_CONF_DEST to $TOUCHPAD_CONF_DEST.bak"
fi
sudo cp "$REPO_DIR/config/xorg/40-libinput-touchpad.conf" "$TOUCHPAD_CONF_DEST"
echo "    This only takes effect on the next X server start - log out and back"
echo "    in (Xorg input config isn't hot-reloadable)."

echo "==> Done."
echo "This installer never launches picom/copyq/polybar itself - on a machine"
echo "that also runs another desktop environment (KDE, GNOME, etc.) in"
echo "parallel, starting picom here would fight that DE's own compositor and"
echo "can wedge session logout. Log into (or switch to) the i3 session for"
echo "these to autostart via i3's 'exec' lines - that only fires on login or"
echo "'i3-msg restart', not a plain 'i3-msg reload'."
