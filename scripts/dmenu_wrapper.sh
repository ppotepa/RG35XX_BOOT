#!/bin/sh
LOG="/var/log/bootmenu_wrapper.log"
echo "[WRAPPER] $(date) dmenu_ln wrapper starting" >> "$LOG"

# Kill any old menu instance
pkill -9 dmenu.bin 2>/dev/null || true

# Run boot_custom directly on the current console
echo "[WRAPPER] Starting boot_custom.sh" >> "$LOG"
exec /bin/sh /mnt/vendor/bin/boot_custom.sh
