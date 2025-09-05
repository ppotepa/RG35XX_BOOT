#!/bin/sh
# boot_custom.sh – unified custom boot initializer

LOG="/var/log/boot_custom.log"
echo "[BOOT_CUSTOM] $(date) starting custom boot" >> "$LOG"

# Show boot splash (redirect all output to log)
sh /mnt/vendor/bin/bootmenulogo.sh >> "$LOG" 2>&1 &

# Enable USB mass storage (redirect all output to log)
sh /mnt/vendor/bin/mass_storage.sh >> "$LOG" 2>&1 &

# Launch the menu binary
exec /mnt/vendor/bin/dmenu.bin