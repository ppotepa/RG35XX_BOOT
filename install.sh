#!/bin/sh
#
# install.sh – safe one-shot installer for Anbernic custom boot mods
#

BOOTMENU="/boot/bootmenu.sh"
DMENU_WRAPPER="/mnt/vendor/ctrl/dmenu_ln"
MSCRIPT="/usr/local/bin/mass_storage.sh"
LOGOSCRIPT="/usr/local/bin/bootmenulogo.sh"
SYSTEM_LOGO="/mnt/vendor/res1/boot/logo.png"
CUSTOM_LOGO="$(dirname "$0")/logo.png"

timestamp=$(date +%Y%m%d%H%M%S)

backup_file() {
    src="$1"
    if [ -f "$src" ]; then
        # Only back up once (never overwrite)
        if ! ls "${src}".backup.* >/dev/null 2>&1; then
            cp "$src" "$src.backup.$timestamp"
            echo "[*] Backed up $src -> $src.backup.$timestamp"
        else
            echo "[*] Backup for $src already exists, skipping."
        fi
    fi
}

echo "[*] Starting custom boot installer..."

# --- Backup originals ---
backup_file "$BOOTMENU"
backup_file "$DMENU_WRAPPER"
backup_file "$SYSTEM_LOGO"

# --- Replace system splash logo ---
if [ -f "$CUSTOM_LOGO" ]; then
    cp "$CUSTOM_LOGO" "$SYSTEM_LOGO"
    echo "[*] Installed custom splash logo: $CUSTOM_LOGO -> $SYSTEM_LOGO"
else
    echo "[!] No custom logo.png found next to install.sh"
fi

# --- Install dmenu_ln wrapper ---
echo "[*] Installing dmenu_ln wrapper..."
cat > "$DMENU_WRAPPER" <<"EOF"
#!/bin/sh
LOG="/var/log/bootmenu_wrapper.log"
echo "[WRAPPER] $(date) dmenu_ln wrapper starting" >> "$LOG"

# Kill any old menu instance
pkill -9 dmenu.bin 2>/dev/null || true

# Run boot menu on its own VT
if command -v openvt >/dev/null 2>&1; then
  openvt -c 2 -w -- /bin/sh /mnt/vendor/bin/bootmenu.sh
else
  exec </dev/tty2 >/dev/tty2 2>&1 /bin/sh /mnt/vendor/bin/bootmenu.sh
fi

# If bootmenu exits, fallback
echo "[WRAPPER] bootmenu returned; starting stock" >> "$LOG"
exec /mnt/vendor/ctrl/dmenu_stock
EOF
chmod +x "$DMENU_WRAPPER"

# --- Install mass_storage.sh ---
echo "[*] Installing mass_storage.sh..."
cat > "$MSCRIPT" <<"EOF"
#!/bin/sh
#
# mass_storage.sh – expose internal partitions as USB drives
#

G=/sys/kernel/config/usb_gadget/anbernic

# Mount configfs if not mounted
mount | grep -q "type configfs" || mount -t configfs none /sys/kernel/config

# Clean up previous gadget if it exists
[ -d $G ] && rm -rf $G

mkdir -p $G
cd $G

# USB IDs
echo 0x1d6b > idVendor
echo 0x0104 > idProduct
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# Strings
mkdir -p strings/0x409
echo "RG35XX-$(date +%s)" > strings/0x409/serialnumber
echo "Anbernic"           > strings/0x409/manufacturer
echo "RG35XX Mass Storage" > strings/0x409/product

# Config
mkdir -p configs/c.1
mkdir -p configs/c.1/strings/0x409
echo "All partitions" > configs/c.1/strings/0x409/configuration

# List of partitions to export
PARTS="/dev/mmcblk0p1 /dev/mmcblk0p2 /dev/mmcblk0p3 \
       /dev/mmcblk0p4 /dev/mmcblk0p5 /dev/mmcblk0p6 /dev/mmcblk0p7"

i=0
for part in $PARTS; do
    if [ -e "$part" ]; then
        echo "[mass_storage] Adding $part as LUN $i"
        mkdir -p functions/mass_storage.$i
        echo $part > functions/mass_storage.$i/lun.0/file
        ln -s functions/mass_storage.$i configs/c.1/
        i=$((i+1))
    fi
done

# Bind to known controller
echo 5100000.udc-controller > UDC

echo "[mass_storage] Exposed $i partitions over USB"
EOF
chmod +x "$MSCRIPT"

# --- Install bootmenulogo.sh ---
echo "[*] Installing bootmenulogo.sh..."
cat > "$LOGOSCRIPT" <<"EOF"
#!/bin/sh
#
# bootmenulogo.sh – show custom bootmenu logo
#

LOG="/var/log/bootmenu_logo.log"
echo "[LOGO] $(date) drawing boot menu logo" >> "$LOG"

# Clear screen (black)
dd if=/dev/zero of=/dev/fb0 bs=1 count=0 seek=0 conv=notrunc status=none

# Draw logo if fbv is present
if command -v fbv >/dev/null 2>&1 && [ -f /mnt/vendor/res1/boot/logo.png ]; then
    fbv -i /mnt/vendor/res1/boot/logo.png >/dev/null 2>&1
    echo "[LOGO] Displayed PNG with fbv" >> "$LOG"
elif [ -f /mnt/vendor/res1/boot/logo.raw ]; then
    cat /mnt/vendor/res1/boot/logo.raw > /dev/fb0
    echo "[LOGO] Displayed raw framebuffer logo" >> "$LOG"
else
    echo "[LOGO] No logo found" >> "$LOG"
fi
EOF
chmod +x "$LOGOSCRIPT"

# --- Patch bootmenu.sh ---
echo "[*] Patching bootmenu.sh..."

if ! grep -q "$LOGOSCRIPT" "$BOOTMENU"; then
    echo "sh $LOGOSCRIPT &" >> "$BOOTMENU"
fi

if ! grep -q "$MSCRIPT" "$BOOTMENU"; then
    echo "sh $MSCRIPT &" >> "$BOOTMENU"
fi

echo "[*] Custom boot installation complete. Reboot to test."
