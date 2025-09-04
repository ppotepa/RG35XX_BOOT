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
