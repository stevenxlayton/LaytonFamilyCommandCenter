#!/usr/bin/env bash
# Writes the latest Home Assistant OS (generic x86-64) image onto the internal SSD of the box
# this is running on. Run it from a LIVE UBUNTU session ("Try Ubuntu") with Ethernet plugged in:
#
#   curl -sL https://raw.githubusercontent.com/stevenxlayton/LaytonFamilyCommandCenter/main/tools/haos-install.sh | bash
#
# (or  wget -qO- <same url> | bash  if curl is missing)
#
# It finds the internal disk, ignores the USB stick you booted from, shows you what it picked,
# and makes you type the disk name plus YES before writing. Everything on that disk is destroyed.
set -euo pipefail

fetch() { if command -v curl >/dev/null; then curl -sL "$1"; else wget -qO- "$1"; fi; }

echo "== Home Assistant OS installer =="
echo

# 1. Latest release asset
echo "Looking up the latest HAOS release..."
URL=$(fetch https://api.github.com/repos/home-assistant/operating-system/releases/latest \
      | grep -o 'https://[^"]*haos_generic-x86-64-[^"]*\.img\.xz' | head -n1 || true)
if [ -z "$URL" ]; then
    echo "Could not find the image URL. Is the Ethernet cable plugged in?"; exit 1
fi
echo "Image: $URL"
echo

# 2. Candidate target: whole disks that are not USB (the live stick is USB)
echo "Disks on this machine:"
lsblk -d -o NAME,SIZE,MODEL,TRAN,TYPE
echo
CANDIDATES=()
for n in $(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
    case "$n" in zram*|loop*|ram*|sr*|fd*) continue ;; esac   # Ubuntu live-session virtual disks
    t=$(lsblk -d -n -o TRAN "/dev/$n" 2>/dev/null || true)
    [ "$t" = "usb" ] || CANDIDATES+=("$n")
done
SUGGEST=""
if [ "${#CANDIDATES[@]}" -eq 1 ]; then
    SUGGEST="${CANDIDATES[0]}"
    echo "Internal disk looks like:  /dev/$SUGGEST   $(lsblk -d -n -o SIZE,MODEL "/dev/$SUGGEST")"
else
    echo "Found ${#CANDIDATES[@]} non-USB disks (${CANDIDATES[*]:-none}). Pick the 128 GB CF450 from the list above."
fi
echo

# 3. Confirm by typing the device name, then YES
read -r -p "Type the disk NAME to wipe (e.g. ${SUGGEST:-sda}) - EVERYTHING on it will be erased: " TARGET < /dev/tty
DEV="/dev/$TARGET"
[ -b "$DEV" ] || { echo "$DEV is not a disk. Aborting."; exit 1; }
[ "$(lsblk -d -n -o TYPE "$DEV")" = "disk" ] || { echo "$DEV is a partition, not a whole disk. Aborting."; exit 1; }
if [ "$(lsblk -d -n -o TRAN "$DEV" 2>/dev/null || true)" = "usb" ]; then
    echo "$DEV is a USB device - that's the stick, not the SSD. Aborting."; exit 1
fi
echo
lsblk "$DEV"
echo
read -r -p "Last chance. Type YES to write Home Assistant OS to $DEV: " GO < /dev/tty
[ "$GO" = "YES" ] || { echo "Aborted. Nothing was written."; exit 1; }

# 4. Download
IMG=/tmp/haos.img.xz
echo
echo "Downloading..."
if command -v curl >/dev/null; then curl -L --progress-bar -o "$IMG" "$URL"; else wget -q --show-progress -O "$IMG" "$URL"; fi

# 5. Unmount anything Ubuntu auto-mounted from that disk, then write
echo
echo "Unmounting $DEV partitions..."
for p in $(lsblk -ln -o NAME "$DEV" | tail -n +2); do sudo umount -q "/dev/$p" 2>/dev/null || true; done
echo "Writing to $DEV (a few minutes)..."
xz -dc "$IMG" | sudo dd of="$DEV" bs=4M status=progress conv=fsync
sync
echo
echo "Done."
echo "  1. Shut down (NOT reboot). Pull the USB stick."
echo "  2. Power on with Ethernet plugged in. Wait ~5 minutes on first boot."
echo "  3. From the desktop open  http://homeassistant.local:8123"
