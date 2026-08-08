# Arch / CachyOS notes

A fork of [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) with the
fixes needed to run on **CachyOS** (or any Arch-based distro) with **Hyprland 0.56.x**.

All credit for the dotfiles themselves goes to [JaKooLit](https://github.com/JaKooLit).
Upstream was archived in March 2026.

## Quick start

```bash
./install-arch-deps.sh
hyprctl reload
```

## What's different from upstream

### 1. An Arch dependency installer

Upstream ships one installer per distro. Running the **Fedora** installer on an
Arch-based distro leaves you with the dotfiles but no programs — every `dnf` call
silently does nothing. The symptom is **no wallpaper and no waybar**, which looks
like broken configs but is just missing packages.

`install-arch-deps.sh` installs the same dependency set via `pacman` + `paru`.

### 2. Hyprland 0.56 compatibility

These dotfiles predate Hyprland 0.56, which removed three things. Each one puts
Hyprland's **red Error Overlay** at the top of the screen — exactly where waybar
sits, so it reads as "waybar is broken" when waybar isn't the problem.

| File | Change | Reason |
|---|---|---|
| `config/hypr/configs/Keybinds.conf` | `togglesplit` → `layoutmsg, togglesplit` | No longer a standalone dispatcher |
| `config/hypr/scripts/ChangeLayout.sh` | same | same |
| `config/hypr/configs/SystemSettings.conf` | `dwindle:pseudotile` commented out | Option removed; use the `pseudo` dispatcher |
| `config/hypr/configs/SystemSettings.conf` | `misc:vfr` commented out | Option removed; VFR is always on now |

Check your own config at any time with:

```bash
hyprctl configerrors
```

### 3. Two upstream package renames

- **`swww` is now `awww`.** The package `provides`/`replaces` swww so pacman
  resolves it, but it installs only `awww` and `awww-daemon` binaries. These
  dotfiles call `swww-daemon` in ~40 places, so the installer symlinks
  `/usr/local/bin/swww{,-daemon}` → `awww{,-daemon}` rather than patching every
  call site. That also survives a dotfiles update.
- **`rofi-wayland` is now just `rofi`.** rofi 2.0 merged Wayland support and
  `provides rofi-wayland`.

## Known upstream issue: wallust fails to build

`wallust` comes from the AUR and currently fails with:

```
wallust-3.5.2.tar.gz ... FAILED
==> ERROR: One or more files did not pass the validity check!
```

This is a **packaging** problem, not a compromised download. Codeberg generates
release tarballs on the fly, and a Forgejo change altered the gzip output — same
source, different bytes, so the hash pinned in the PKGBUILD no longer matches.

Rather than passing `--skipchecksums` (which accepts whatever you downloaded, no
questions asked), verify the source against the upstream tag first:

```bash
git clone --depth 1 --branch 3.5.2 \
  https://codeberg.org/explosion-mental/wallust.git /tmp/wallust-upstream
cd ~/.cache/paru/clone/wallust
tar xzf wallust-*.tar.gz
diff -r --exclude=.git /tmp/wallust-upstream wallust    # empty output = genuine
```

If the diff is empty, the tarball matches the upstream tag. Then put the real
hash in the PKGBUILD and build:

```bash
sha256sum wallust-*.tar.gz                              # copy this value
sed -i "s/^sha256sums=.*/sha256sums=('<value>')/" PKGBUILD
makepkg -si
```

wallust is cosmetic — it regenerates colors from your wallpaper. Everything else
works without it.

## Optional: waybar keyboard-state module

waybar disables its caps/num-lock indicator unless you're in the `input` group:

```bash
sudo usermod -aG input "$USER"    # log out and back in
```

Worth knowing: membership in `input` lets **any** process running as you read all
input devices, including keystrokes. It only affects that one indicator, so
skipping it costs little.
