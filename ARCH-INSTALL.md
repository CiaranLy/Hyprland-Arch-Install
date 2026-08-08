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

## Added keybinds

| Key | Action |
|---|---|
| `SUPER + C` | VS Code |
| `SUPER + V` | Superset ([superset.sh](https://superset.sh)) |

Both live in `UserKeybinds.conf`, which upstream reserves for user additions, so
a dotfiles update will not overwrite them. Both keys were unbound upstream — the
calculator is `SUPER+ALT+C` and the clipboard manager is `SUPER+ALT+V`, so
neither needs an `unbind`.

**VS Code:** the installer pulls Microsoft's `visual-studio-code-bin` from the
AUR rather than the repos' `code` (Code - OSS), because only the Microsoft build
can reach the Marketplace for Pylance, Remote-SSH and C/C++. Both install
`/usr/bin/code`, so the keybind works with either.

**Superset:** an Electron AI code editor, packaged as an AppImage. Two AUR
packages wrap the identical AppImage and conflict with each other;
`superset-desktop-bin` is preferred because it patches the `.desktop`
`Exec`/`Icon` paths so launching from rofi and app menus works.

The AUR package has lagged upstream by a few releases. To build a newer version,
bump `pkgver` in the PKGBUILD and verify the download against the `sha512` that
upstream publishes in `latest-linux.yml` on each release, rather than trusting
whatever downloads:

```bash
git clone https://aur.archlinux.org/superset-desktop-bin.git
cd superset-desktop-bin
sed -i 's/^pkgver=.*/pkgver=<new>/' PKGBUILD
curl -sL https://github.com/superset-sh/superset/releases/download/desktop-v<new>/latest-linux.yml
curl -fLO https://github.com/superset-sh/superset/releases/download/desktop-v<new>/superset-<new>-x86_64.AppImage
sha512sum superset-<new>-x86_64.AppImage | cut -d' ' -f1 | xxd -r -p | base64 -w0   # must match the yml
sed -i "s/^sha256sums=.*/sha256sums=('$(sha256sum superset-<new>-x86_64.AppImage | cut -d' ' -f1)')/" PKGBUILD
makepkg -si
```

## VS Code extensions

`vscode-extensions.txt` lists extension IDs, one per line; the installer feeds
each to `code --install-extension --force`. `--force` makes it idempotent, so
re-running the script is safe.

To capture your current set on any machine:

```bash
code --list-extensions > vscode-extensions.txt
```

For ongoing sync across machines, VS Code's built-in **Settings Sync**
(gear icon → Backup and Sync Settings) is the better tool — it covers settings,
keybindings and snippets too, and updates continuously. The list here is for
reproducible fresh installs.

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
