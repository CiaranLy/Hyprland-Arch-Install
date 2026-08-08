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

# Discord. vesktop rather than the official "discord" package: it runs natively
# on Wayland and can share screen audio, which the official Linux client cannot.
# It is a third-party client bundling Vencord, so client mods are a ToS grey
# area — swap in "discord" if you would rather stay first-party.
sudo pacman -S --needed --noconfirm vesktop

# Gaming. steam and the lib32-* packages need the [multilib] repo enabled in
# /etc/pacman.conf; CachyOS enables it by default, plain Arch does not.
# Proton itself is NOT a package — the Steam client downloads it once you tick
# Settings > Compatibility > "Enable Steam Play for all other titles".
# The lib32 counterparts of gamemode/mangohud are what 32-bit titles load.
echo "==> 1b/4  Gaming"
if grep -q '^\[multilib\]' /etc/pacman.conf; then
  sudo pacman -S --needed --noconfirm \
    steam gamemode lib32-gamemode mangohud lib32-mangohud
else
  echo "  skipped: [multilib] is not enabled in /etc/pacman.conf." >&2
  echo "  Uncomment the [multilib] section there, run 'sudo pacman -Sy', re-run this." >&2
fi

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

# Superset (superset.sh), an Electron AI code editor, for the SUPER+V keybind.
# Prefer superset-desktop-bin over superset-bin: they wrap the same AppImage
# (identical sha256) and conflict with each other, but this one patches the
# .desktop Exec/Icon paths so launching from rofi and app menus works.
# Note: this AUR package has lagged upstream by a few releases; check
# https://github.com/superset-sh/superset/releases if you need the newest.
"$AUR" -S --needed --noconfirm superset-desktop-bin \
  || echo "  warning: superset-desktop-bin failed; continuing." >&2

# VS Code extensions, listed in vscode-extensions.txt next to this script.
# Skipped silently if code did not install. --force makes this idempotent, so
# re-running the script is safe.
EXT_LIST="$(dirname "$(realpath "$0")")/vscode-extensions.txt"
if command -v code >/dev/null 2>&1 && [ -f "$EXT_LIST" ]; then
  echo "==> 3b/4  VS Code extensions"
  while IFS= read -r ext; do
    ext="${ext%%#*}"                        # strip comments
    ext="$(echo "$ext" | tr -d '[:space:]')" # strip whitespace
    [ -z "$ext" ] && continue
    printf '  %s\n' "$ext"
    code --install-extension "$ext" --force >/dev/null 2>&1 \
      || echo "    warning: failed to install $ext" >&2
  done < "$EXT_LIST"
fi

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
         bc socat jq yad code superset-desktop steam gamemode mangohud vesktop; do
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
