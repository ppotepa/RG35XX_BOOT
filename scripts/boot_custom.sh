#!/bin/sh
# boot_custom.sh – unified custom boot initializer

LOG="/var/log/boot_custom.log"
echo "[BOOT_CUSTOM] $(date) starting custom boot" >> "$LOG"

# Ensure we're using the primary console
export TERM=linux
exec >/dev/console 2>&1

# Show boot splash (redirect all output to log)
sh /mnt/vendor/bin/bootmenulogo.sh >> "$LOG" 2>&1 &

# Enable USB mass storage (redirect all output to log)
sh /mnt/vendor/bin/mass_storage.sh >> "$LOG" 2>&1 &

# Launch the menu binary (on primary console)
exec /mnt/vendor/bin/dmenu.bin