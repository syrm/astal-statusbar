# Bouh statusbar

A simple bar for Hyprland using

meson setup build --wipe --prefix "$PWD/result"
meson install -C build
./result/bin/bouh-statusbar

To run runcat you need to copy the font:
cp -r runcat.ttf ~/.local/share/fonts

- [Hyprland library](https://aylur.github.io/astal/guide/libraries/hyprland).
- [Mpris library](https://aylur.github.io/astal/guide/libraries/mpris).
- [Tray library](https://aylur.github.io/astal/guide/libraries/tray).
- [dart-sass](https://sass-lang.com/dart-sass/) as the css precompiler
