#!/bin/sh
#
# mass_storage.sh – expose internal partitions as USB drives
#

LOG="/var/log/mass_storage.log"
G=/sys/kernel/config/usb_gadget/anbernic

echo "[mass_storage] $(date) Starting mass storage setup" >> "$LOG"

# Check if configfs is available
if [ ! -d /sys/kernel/config ]; then
    echo "[mass_storage] ERROR: configfs not available" >> "$LOG"
    exit 1
fi

# Mount configfs if not mounted
if ! mount | grep -q "type configfs"; then
    echo "[mass_storage] Mounting configfs" >> "$LOG"
    mount -t configfs none /sys/kernel/config
    if [ $? -ne 0 ]; then
        echo "[mass_storage] ERROR: Failed to mount configfs" >> "$LOG"
        exit 1
    fi
fi

# Clean up previous gadget if it exists
if [ -d "$G" ]; then
    echo "[mass_storage] Cleaning up existing gadget" >> "$LOG"
    # First try to unbind UDC
    if [ -f "$G/UDC" ]; then
        echo "" > "$G/UDC" 2>/dev/null || true
    fi
    # Remove symlinks first
    rm -f "$G"/configs/c.1/mass_storage.* 2>/dev/null || true
    # Remove the gadget directory
    rm -rf "$G" 2>/dev/null || true
fi

# Create gadget directory
mkdir -p "$G"
if [ ! -d "$G" ]; then
    echo "[mass_storage] ERROR: Failed to create gadget directory" >> "$LOG"
    exit 1
fi

cd "$G"

# USB IDs (Linux Foundation)
echo 0x1d6b > idVendor
echo 0x0104 > idProduct
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

echo "[mass_storage] Set USB device IDs" >> "$LOG"

# Device class (mass storage)
echo 0x00 > bDeviceClass
echo 0x00 > bDeviceSubClass
echo 0x00 > bDeviceProtocol

# Strings
mkdir -p strings/0x409
echo "RG35XX-$(date +%s)" > strings/0x409/serialnumber
echo "Anbernic"           > strings/0x409/manufacturer
echo "RG35XX Mass Storage" > strings/0x409/product

echo "[mass_storage] Set device strings" >> "$LOG"

# Configuration
mkdir -p configs/c.1
mkdir -p configs/c.1/strings/0x409
echo "Mass Storage Configuration" > configs/c.1/strings/0x409/configuration
echo 0x80 > configs/c.1/bmAttributes  # Bus powered
echo 250 > configs/c.1/MaxPower       # 500mA

echo "[mass_storage] Created configuration" >> "$LOG"

# List of partitions to export (safer partitions for Windows compatibility)
# Check for ROM partition (usually FAT32) or user data partition
PARTS=""

# Look for FAT32 partitions first (Windows compatible)
for part in /dev/mmcblk0p*; do
    if [ -e "$part" ]; then
        # Check if it's a FAT partition by trying to mount it
        FSTYPE=$(blkid -o value -s TYPE "$part" 2>/dev/null)
        case "$FSTYPE" in
            "vfat"|"fat32"|"fat16")
                echo "[mass_storage] Found FAT partition: $part ($FSTYPE)" >> "$LOG"
                PARTS="$PARTS $part"
                ;;
            "ext4"|"ext3"|"ext2")
                echo "[mass_storage] Skipping Linux partition: $part ($FSTYPE)" >> "$LOG"
                ;;
            *)
                # Unknown filesystem, check if it's safe to expose
                if echo "$part" | grep -E "(mmcblk0p[4-9]|mmcblk0p1[0-9])" > /dev/null; then
                    echo "[mass_storage] Found user partition: $part (unknown fs: $FSTYPE)" >> "$LOG"
                    PARTS="$PARTS $part"
                else
                    echo "[mass_storage] Skipping system partition: $part ($FSTYPE)" >> "$LOG"
                fi
                ;;
        esac
    fi
done

# If no FAT partitions found, don't expose anything to avoid data corruption
if [ -z "$PARTS" ]; then
    echo "[mass_storage] No safe partitions found for Windows exposure" >> "$LOG"
    exit 1
fi

echo "[mass_storage] Starting partition setup" >> "$LOG"

i=0
for part in $PARTS; do
    if [ -e "$part" ]; then
        echo "[mass_storage] Processing $part as LUN $i" >> "$LOG"
        
        # Create function directory
        mkdir -p "functions/mass_storage.usb$i"
        
        # Check if partition is currently mounted and unmount if necessary
        if mount | grep -q "$part"; then
            echo "[mass_storage] WARNING: $part is mounted, unmounting..." >> "$LOG"
            umount "$part" 2>/dev/null || true
        fi
        
        # Set the backing file
        echo "$part" > "functions/mass_storage.usb$i/lun.0/file"
        echo 1 > "functions/mass_storage.usb$i/lun.0/ro"  # Read-only for safety
        echo 0 > "functions/mass_storage.usb$i/lun.0/removable"  # Non-removable
        
        # Link to configuration
        ln -s "functions/mass_storage.usb$i" "configs/c.1/"
        
        echo "[mass_storage] Added $part as LUN $i" >> "$LOG"
        i=$((i+1))
    else
        echo "[mass_storage] Partition $part not found, skipping" >> "$LOG"
    fi
done

# Check if we have any LUNs configured
if [ $i -eq 0 ]; then
    echo "[mass_storage] ERROR: No partitions found to export" >> "$LOG"
    exit 1
fi

# Find available UDC controller
UDC_CONTROLLER=""
for udc in /sys/class/udc/*; do
    if [ -e "$udc" ]; then
        UDC_CONTROLLER=$(basename "$udc")
        break
    fi
done

if [ -z "$UDC_CONTROLLER" ]; then
    echo "[mass_storage] ERROR: No UDC controller found" >> "$LOG"
    exit 1
fi

echo "[mass_storage] Using UDC controller: $UDC_CONTROLLER" >> "$LOG"

# Bind to UDC controller
echo "$UDC_CONTROLLER" > UDC
if [ $? -eq 0 ]; then
    echo "[mass_storage] Successfully exposed $i partitions over USB" >> "$LOG"
    echo "[mass_storage] Exposed $i partitions over USB"
else
    echo "[mass_storage] ERROR: Failed to bind to UDC controller" >> "$LOG"
    exit 1
fi
