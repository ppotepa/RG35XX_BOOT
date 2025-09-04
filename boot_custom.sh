#!/bin/sh
# boot_custom.sh – unified custom boot initializer

LOG="/var/log/boot_custom.log"
echo "[BOOT_CUSTOM] $(date) starting custom boot" >> "$LOG"

# Show boot splash
sh /mnt/vendor/bin/bootmenulogo.sh &

# Enable USB mass storage
sh /mnt/vendor/bin/mass_storage.sh &

# Launch the menu binary
exec /mnt/vendor/bin/dmenu.bin