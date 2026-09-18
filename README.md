# dotfiles

i3 + polybar + rofi + copyq + picom rice, set up on CachyOS (Arch-based).

## install

```sh
git clone https://github.com/ry-mcg/i3dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

with no flags you will be asked if you want any other apps or what modules you want on poly bar

```sh
./install.sh --all           # install everything, including optional apps
./install.sh --minimal       # core rice only
./install.sh --with-kitty --with-nemo
./install.sh --modules=network,volume,cpu,memory,power   # pick top-bar modules
```

Available modules: `network`, `bluetooth`, `volume`, `cpu`, `temperature`,
`memory`, `battery`, `clipboard`, `power`. default is all (minus
`battery` if on a machine with no battery).

## uninstall

```sh
./uninstall.sh
```

```sh
./uninstall.sh --purge-packages   # also remove the packages, no prompt
./uninstall.sh --keep-packages    # just remove symlinks, no prompt
./uninstall.sh --remove-wallpaper # also delete ~/Pictures/wallpaper_4k.png
```

![my i3 dotfiles setup](i3dotfiles.png)