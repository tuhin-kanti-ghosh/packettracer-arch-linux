# Packet Tracer Installer for Arch Linux

A Bash script that installs Cisco Packet Tracer on Arch Linux (and Arch-based
distros like CachyOS, Manjaro, EndeavourOS) from the official `.deb` package.
Cisco only distributes Packet Tracer as a `.deb`/`.rpm`, with no official
Arch or AUR package — this script extracts the `.deb` and installs it the
way a native package roughly would, without needing a Debian chroot or
`dpkg`.

> Cisco Packet Tracer itself is proprietary software. This script does not
> include or distribute it — you need to download the `.deb` yourself from
> the [Cisco Networking Academy](https://www.netacad.com/) (a free account
> is required).

## Features

- Extracts the `.deb` and copies its files into `/opt/pt` and `/usr` — no
  Debian/`dpkg` toolchain required.
- Auto-detects the `.deb` file in the current directory if you don't pass
  one explicitly.
- Installs dependencies via `pacman -Syu` (full sync + upgrade) rather than
  a plain `-S`, avoiding Arch's "partial upgrade" dependency conflicts.
- Handles `openssl-1.1` gracefully — it's been dropped from both the
  official repos and the AUR, so the script skips it without failing the
  whole install if it's unavailable.
- Verifies the installed binary after copying, via `ldd`, and reports any
  shared library it can't find, so a missing dependency shows up as a clear
  warning instead of a silent crash on launch.
- Creates a `.desktop` entry so Packet Tracer shows up in your app launcher.

## Requirements

- Arch Linux or an Arch-based distro
- `sudo`/root access
- `binutils` (for `ar`) — installed by default on most Arch systems
- The Packet Tracer `.deb` package, downloaded from Cisco

## Usage

```bash
# Auto-detect a .deb in the current directory
sudo ./packettracer_installer.sh

# Or specify the file explicitly
sudo ./packettracer_installer.sh PacketTracer822_amd64_signed_en-US.deb
```

Run with `--help` for usage details.

## What it does

1. Extracts the `.deb`'s `data.tar.*` archive (whatever compression it uses)
   into a temporary directory.
2. Installs Qt5, GStreamer, and other runtime dependencies via `pacman`.
3. Copies the extracted `/opt/pt` and `/usr` contents onto the system.
4. Creates a desktop entry so Packet Tracer appears in your application menu.
5. Checks the installed binary for missing shared libraries.

## A note on how it installs files

This script copies files directly into `/opt` and `/usr` rather than
building a proper Arch package (via `makepkg`/`PKGBUILD`). That means
`pacman` won't track these files — `pacman -Qo` won't show them as owned by
anything, and a future official package shipping the same path could
conflict. This keeps the script simple and dependency-free, but if you'd
rather have a package `pacman` can track and cleanly remove, wrapping this
as a proper `PKGBUILD` is the more "correct" long-term approach.

## Uninstalling

Since files aren't tracked by `pacman`, removal is manual:

```bash
sudo rm -rf /opt/pt
sudo rm -f /usr/share/applications/packettracer.desktop
```

(Icons and MIME files copied into `/usr/share` are left in place, since they
may be shared with other packages.)

## License

[MIT](LICENSE) — or pick whichever license you prefer before publishing.

## Disclaimer

Cisco Packet Tracer is a trademark of Cisco Systems, Inc. This project is
not affiliated with or endorsed by Cisco.
