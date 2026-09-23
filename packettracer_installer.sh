#!/bin/bash

# Exit the script on any error
set -euo pipefail

show_help() {
    echo 'Usage: sudo ./packettracer_installer.sh [packettracer.deb]'
    echo 'Installs Cisco Packet Tracer from a .deb package on Arch Linux.'
    echo
    echo 'If no .deb path is given, the script looks for a single .deb file'
    echo 'in the current directory and uses it automatically.'
}

if [[ "${1:-}" == '--help' || "${1:-}" == '-h' ]]; then
    show_help
    exit 0
fi

if [ "$EUID" -ne 0 ]; then
    echo 'To install Packet Tracer, root privileges are required. Please run this script with sudo.'
    exit 1
fi

packettracer_binary="${1:-}"

if [ -z "$packettracer_binary" ]; then
    # No path given: try to auto-detect a Packet Tracer .deb in the current directory.
    shopt -s nullglob nocaseglob
    candidates=(./*packettracer*.deb)
    shopt -u nocaseglob

    if [ "${#candidates[@]}" -eq 0 ]; then
        # Fall back to any single .deb file sitting in the current directory.
        candidates=(./*.deb)
    fi
    shopt -u nullglob

    if [ "${#candidates[@]}" -eq 1 ]; then
        packettracer_binary="${candidates[0]}"
        echo "No file given, using detected package: $packettracer_binary"
    elif [ "${#candidates[@]}" -eq 0 ]; then
        echo -e 'No Packet Tracer .deb file provided or found in the current directory.\n'
        show_help
        exit 1
    else
        echo -e "Multiple .deb files found in the current directory; please specify one:\n"
        printf '  %s\n' "${candidates[@]}"
        exit 1
    fi
fi

if [ ! -f "$packettracer_binary" ]; then
    echo "File not found: $packettracer_binary"
    exit 1
elif ! command -v ar > /dev/null 2>&1; then
    echo "'ar' command not found. Please install 'binutils' package first."
    exit 1
fi

# Resolve to an absolute path now, before we cd into the tmpdir below.
packettracer_binary="$(realpath "$packettracer_binary")"

tmpdir=$(mktemp -d)

# Remove the tmpdir on exit (success or failure)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

echo 'Extracting deb package...'
(cd "$tmpdir" && ar x "$packettracer_binary")

# Find the data archive regardless of its compression (xz, zst, gz, ...)
data_archive=$(find "$tmpdir" -maxdepth 1 -name 'data.tar.*' -print -quit)

if [ -z "$data_archive" ]; then
    echo 'Invalid Packet Tracer file (data.tar.* not found).'
    exit 1
fi

echo "Extracting $(basename "$data_archive")..."
tar -xf "$data_archive" -C "$tmpdir"

# Check if the extracted data contains valid data
if [ ! -d "$tmpdir/usr/" ] ||
    [ ! -d "$tmpdir/usr/share/" ] ||
    [ ! -d "$tmpdir/usr/share/icons/" ] ||
    [ ! -d "$tmpdir/usr/share/mime/" ] ||
    [ ! -d "$tmpdir/opt/" ] ||
    [ ! -d "$tmpdir/opt/pt/" ]; then
    echo 'Invalid Packet Tracer file data.'
    exit 1
fi

# Install dependencies. openssl-1.1 has been dropped from both the official
# Arch repos and the AUR, so it's handled separately and treated as optional:
# Packet Tracer may run fine without it (some versions bundle their own copy
# or work against system openssl3), so a missing openssl-1.1 shouldn't abort
# the whole install. The post-install ldd check below confirms either way.
echo 'Installing dependencies...'
pacman -S --needed --noconfirm \
  qt5-networkauth qt5-base qt5-multimedia qt5-websockets qt5-webengine qt5-svg qt5-speech qt5-script \
  gstreamer gst-plugins-base nss alsa-lib

if ! pacman -S --needed --noconfirm openssl-1.1; then
    echo "Note: 'openssl-1.1' isn't available from your configured repos (it has been"
    echo 'dropped from both the official Arch repos and the AUR). Continuing without it;'
    echo 'the check after installation will confirm whether Packet Tracer actually needs it.'
fi

# Copy data (force overwrite, preserve permissions)
echo 'Copying Packet Tracer files...'
cp -rf "$tmpdir/opt/pt" /opt/
cp -rf "$tmpdir/usr/." /usr/

if [ ! -x /opt/pt/bin/PacketTracer ]; then
    chmod +x /opt/pt/bin/PacketTracer
fi

# Create a desktop entry
echo 'Creating desktop entry...'
cat <<EOF > /usr/share/applications/packettracer.desktop
[Desktop Entry]
Name=Cisco Packet Tracer
Comment=Networking Simulation Tool
Exec=/opt/pt/bin/PacketTracer
Icon=/opt/pt/art/app.png
Type=Application
Categories=Education;Network;
Terminal=false
StartupNotify=true
EOF
chmod 644 /usr/share/applications/packettracer.desktop

echo 'Successfully installed Packet Tracer.'

# Report any shared libraries PacketTracer can't find at runtime, so a missing
# optional dependency (like openssl-1.1 above) shows up here instead of as a
# silent crash when the user launches the app.
missing_libs=$(ldd /opt/pt/bin/PacketTracer 2>/dev/null | awk '/not found/ {print $1}')
if [ -n "$missing_libs" ]; then
    echo
    echo 'Warning: PacketTracer is missing the following shared libraries:'
    echo "$missing_libs" | sed 's/^/  /'
    echo "It may fail to start until these are provided (check the AUR, or Cisco's site)."
fi
