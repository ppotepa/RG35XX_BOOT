#!/bin/bash
# Immediate reboot, bypassing frontend splash/shutdown handlers

LOGFILE="/var/log/fastreboot.log"
echo "[$(date '+%F %T')] Fast reboot triggered" >> "$LOGFILE"

# Kill vendor frontend quickly if running
killall -9 dmenu.bin 2>/dev/null
killall -9 loadapp.sh 2>/dev/null

# Kill our custom processes too
killall -9 bootmenulogo.sh 2>/dev/null
killall -9 mass_storage.sh 2>/dev/null
killall -9 usb_monitor.sh 2>/dev/null
killall -9 boot_custom.sh 2>/dev/null

# Clean up USB gadget if active
if [ -d /sys/kernel/config/usb_gadget/anbernic ]; then
    echo "" > /sys/kernel/config/usb_gadget/anbernic/UDC 2>/dev/null || true
    rm -rf /sys/kernel/config/usb_gadget/anbernic 2>/dev/null || true
fi

# Sync filesystem to avoid corruption
sync

# Hard reboot
echo b > /proc/sysrq-trigger
