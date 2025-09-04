#!/bin/sh
LOG="/var/log/bootmenu_wrapper.log"
echo "[WRAPPER] $(date) dmenu_ln wrapper starting" >> "$LOG"

# Kill any old menu instance
pkill -9 dmenu.bin 2>/dev/null || true

# Run boot_custom on its own VT
if command -v openvt >/dev/null 2>&1; then
  openvt -c 2 -w -- /bin/sh /mnt/vendor/bin/boot_custom.sh
else
  exec </dev/tty2 >/dev/tty2 2>&1 /bin/sh /mnt/vendor/bin/boot_custom.sh
fi

# If custom boot exits, fallback
echo "[WRAPPER] boot_custom returned; starting stock" >> "$LOG"
exec /mnt/vendor/ctrl/dmenu_stock
