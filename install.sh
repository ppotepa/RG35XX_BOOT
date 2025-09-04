#!/bin/sh
#
# install.sh – safe one-shot installer for Anbernic custom boot mods
#

SCRIPT_DIR="$(dirname "$0")/scripts"
BOOTMENU="/mnt/vendor/bin/bootmenu.sh"
CUSTOMBOOT="/mnt/vendor/bin/boot_custom.sh"
DMENU_WRAPPER="/mnt/vendor/ctrl/dmenu_ln"
MSCRIPT="/mnt/vendor/bin/mass_storage.sh"
LOGOSCRIPT="/mnt/vendor/bin/bootmenulogo.sh"
SYSTEM_LOGO="/mnt/vendor/res1/boot/logo.png"
CUSTOM_LOGO="$(dirname "$0")/logo.png"
LOADAPP="/mnt/vendor/bin/loadapp.sh"

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
    else
        echo "[*] File $src does not exist, no backup needed."
    fi
}

install_script() {
    src="$1"
    dest="$2"
    name="$3"
    
    if [ -f "$src" ]; then
        # Backup the destination file if it exists
        backup_file "$dest"
        
        cp "$src" "$dest"
        chmod +x "$dest"
        echo "[*] Installed $name: $src -> $dest"
    else
        echo "[!] ERROR: $name script not found: $src"
        exit 1
    fi
}

echo "[*] Starting custom boot installer..."

# Check if required files exist
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "[!] ERROR: Scripts directory not found: $SCRIPT_DIR"
    echo "    Make sure the 'scripts' folder is in the same directory as install.sh"
    exit 1
fi

if [ ! -f "boot_custom.sh" ]; then
    echo "[!] ERROR: boot_custom.sh not found in the same directory as install.sh"
    exit 1
fi

# --- Backup all files that will be modified ---
echo "[*] Creating backups of existing files..."
backup_file "$BOOTMENU"
backup_file "$DMENU_WRAPPER"
backup_file "$SYSTEM_LOGO"
backup_file "$LOADAPP"
backup_file "$CUSTOMBOOT"
backup_file "$MSCRIPT"
backup_file "$LOGOSCRIPT"

# --- Replace system splash logo ---
if [ -f "$CUSTOM_LOGO" ]; then
    backup_file "$SYSTEM_LOGO"
    cp "$CUSTOM_LOGO" "$SYSTEM_LOGO"
    echo "[*] Installed custom splash logo: $CUSTOM_LOGO -> $SYSTEM_LOGO"
else
    echo "[!] No custom logo.png found next to install.sh"
fi

# --- Install all scripts ---
echo "[*] Installing scripts..."
install_script "$SCRIPT_DIR/bootmenulogo.sh" "$LOGOSCRIPT" "boot menu logo script"
install_script "$SCRIPT_DIR/mass_storage.sh" "$MSCRIPT" "mass storage script"
install_script "boot_custom.sh" "$CUSTOMBOOT" "custom boot middleware"
install_script "$SCRIPT_DIR/dmenu_wrapper.sh" "$DMENU_WRAPPER" "dmenu wrapper"

# --- Patch loadapp.sh to use boot_custom.sh ---
echo "[*] Patching loadapp.sh..."
if grep -q "BOOTMENU=" "$LOADAPP"; then
    sed -i 's|^BOOTMENU=.*|BOOTMENU="/mnt/vendor/bin/boot_custom.sh"|' "$LOADAPP"
    echo "[*] Updated loadapp.sh to use boot_custom.sh"
else
    echo "[!] Could not find BOOTMENU= line in loadapp.sh, manual edit may be needed."
fi

echo "[*] Custom boot installation complete. Reboot to test."
