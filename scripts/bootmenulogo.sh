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
