#!/usr/bin/env bash
#
# install-arch-deps.sh — install the packages these dotfiles need, on Arch / CachyOS.
#
# Why this exists: JaKooLit ships separate installers per distro. If you run the
# Fedora-Hyprland installer on an Arch-based distro (CachyOS, EndeavourOS, ...),
# every `dnf` call silently does nothing — you end up with the dotfiles but none
# of the programs they call. The symptom is no wallpaper and no waybar.
#
# This installs the same dependency set using pacman + an AUR helper.
#
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  echo "error: pacman not found — this script is for Arch-based distros." >&2
  exit 1
fi

echo "==> 1/4  Repo packages"
sudo pacman -S --needed --noconfirm \
  waybar swaync rofi wlogout \
  awww \
  hypridle hyprlock hyprsunset hyprpicker \
  cliphist wl-clipboard \
  kitty quickshell \
  nwg-look nwg-displays \
  grim slurp swappy \
  network-manager-applet blueman \
  brightnessctl pamixer pavucontrol playerctl \
  polkit-gnome \
  qt5ct qt6ct kvantum \
  cava btop fastfetch \
  mpv mpv-mpris mpvpaper imagemagick ffmpeg ffmpegthumbs \
  bc socat jq yad python-requests python-pyquery \
  gvfs nvtop xdg-desktop-portal-hyprland \
  lsd eza starship \
  noto-fonts-emoji ttf-jetbrains-mono-nerd otf-font-awesome

# Two upstream renames these dotfiles predate:
#   swww         -> awww         (package "awww" provides/replaces "swww")
#   rofi-wayland -> rofi         (rofi 2.0 has Wayland support built in)
echo "==> 2/4  swww -> awww compatibility symlinks"
# The dots still call swww/swww-daemon in ~40 places, so symlink rather than
# patch every call site (this also survives a dotfiles update).
sudo ln -sfn /usr/bin/awww        /usr/local/bin/swww
sudo ln -sfn /usr/bin/awww-daemon /usr/local/bin/swww-daemon

echo "==> 3/4  AUR helper + wallust"
if ! command -v paru >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm paru
fi
AUR=$(command -v paru || command -v yay)

# Microsoft's official VS Code build, for the SUPER+C keybind in UserKeybinds.conf.
# The repo package "code" (Code - OSS) is FOSS but cannot reach the Microsoft
# Marketplace, so Pylance, Remote-SSH and C/C++ are unavailable there.
# Both builds install /usr/bin/code, so the keybind works either way.
"$AUR" -S --needed --noconfirm visual-studio-code-bin \
  || echo "  warning: visual-studio-code-bin failed; continuing." >&2

if ! "$AUR" -S --needed --noconfirm wallust; then
  cat <<'EOF'

  NOTE: wallust failed to build.

  If it failed on "Validating source files with sha256sums ... FAILED", that is a
  known packaging issue, not a compromised download: Codeberg generates release
  tarballs on the fly, and a Forgejo change altered the gzip output. The contents
  are unchanged but the hash no longer matches what the AUR PKGBUILD pins.

  Do NOT just pass --skipchecksums. Verify the source first, then build:

    git clone --depth 1 --branch 3.5.2 \
      https://codeberg.org/explosion-mental/wallust.git /tmp/wallust-upstream
    cd ~/.cache/paru/clone/wallust
    tar xzf wallust-*.tar.gz
    diff -r --exclude=.git /tmp/wallust-upstream wallust   # must print nothing

  If the diff is empty the tarball matches the signed upstream tag, and you can
  update sha256sums in the PKGBUILD to the real value (sha256sum the tarball)
  and run `makepkg -si`.

  wallust is cosmetic — it regenerates colors from your wallpaper. Everything
  else works without it.

EOF
fi

echo "==> 4/4  Verifying"
fail=0
for b in waybar swww swww-daemon swaync rofi wlogout hypridle hyprlock \
         hyprsunset hyprpicker cliphist wl-paste kitty qs nwg-look \
         grim slurp swappy nm-applet brightnessctl pamixer playerctl \
         bc socat jq yad code; do
  if command -v "$b" >/dev/null 2>&1; then
    printf '  ok      %s\n' "$b"
  else
    printf '  MISSING %s\n' "$b"; fail=1
  fi
done

echo
if [ "$fail" -eq 0 ]; then
  echo "All present. Run 'hyprctl reload', or log out and back in."
else
  echo "Some binaries are missing (see MISSING above)."
fi

# Optional: waybar's keyboard-state module (caps/num lock) needs the input group.
# Be aware this lets any process running as you read all input devices:
#   sudo usermod -aG input "$USER"    # then log out and back in
