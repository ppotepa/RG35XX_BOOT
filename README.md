# Anbernic RG35XX Custom Boot & Kernel Mods

> ⚠️ **Work in Progress**
> This project is under active development. Features, kernels, and installation procedures may change at any time.

This repo contains a collection of **custom boot modifications** and **kernel experiments** for the **Anbernic RG35XX H** handheld device.
The goal is to make the RG35XX more **DIY-friendly**, enabling developers to replace stock software, customize boot behavior, and extend the console beyond retro gaming.

---

## ✨ Features

### Boot Mods

* **Custom Splash Screen** → Replace the default boot logo with your own image.
* **Mass Storage Mode** → Expose internal partitions as USB drives for easy file management.
* **Boot Menu Wrapper** → Override stock `dmenu` with a custom menu for flexible booting and logging.
* **Safe Installation** → Automatic backup of original files before modification.

### Kernel & System Hacking

* **Kernel Builds** → Linux 4.14.170 compiled and tested for `arm64`.
* **Partition Mapping** → Identified all partitions (`mmcblk0p1–p7`) with roles (boot args, kernel, rootfs, etc.).
* **Bootargs Editing** → Verified UART/console redirection (e.g. `console=tty1` vs `console=ttyS0`).
* **Device Tree Work** → Attempted DTB extraction from `zImage` (LZO-compressed blobs).
* **Recovery Safety** → Full backups of `boot_orig.img`, `kernel_partition.img`, and `bootargs_p3_backup.bin` stored.

---

## 📂 Repo Structure

```
rg35xx_mods/
├── backups/                  # Original boot + kernel backups
├── kernels/                  # Custom kernel sources and builds
│   ├── linux-4.14.170/
│   ├── Image
│   └── zImage
├── splash/                   # Custom splash/logo tools
├── rg35xx_dtb_extract/       # DTB extraction scripts
│   └── find_dtb.sh
└── README.md
```

---

## ⚙️ Technical Notes

* **Bootloader & dmenu** → Boot menu system is an SDL app writing directly to `/dev/fb0`.
* **Framebuffer** → Custom logos and UI elements integrate with the framebuffer rendering pipeline.
* **Kernel Boot Args** → Located in `mmcblk0p3` (boot args partition), editable for console/debug tweaks.
* **Stock Kernel** → Allwinner 4.9.170-based, with DTBs embedded in the compressed `zImage`.
* **Custom Kernel** → Built from 4.14.170, currently boots but requires correct DTB integration.

---

## 🚀 Installation

### Prerequisites

* RG35XX H with **root access**.
* **Terminal/SSH access** to the device.
* (Optional) Custom splash/logo file (`logo.png`).

### Quick Install

1. Download or copy the installer to your device.
2. Make the installer executable:

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

### Manual Install

If you want to see what the installer does:

1. Backup original files (`dmenu`, bootargs, kernel image).
2. Replace with patched binaries/logos.
3. Update boot partition as required.

---

## 🛠️ Current Roadmap

* [ ] Finalize **DTB extraction and repack** into custom kernel image.
* [ ] Add **serial console + framebuffer console** simultaneously for debugging.
* [ ] Document safe **kernel swap procedure** (repacking `boot.img`).
* [ ] Expand boot menu with **multi-OS / multi-kernel support**.

---

## 💡 Why This Project?

The RG35XX H is:

* **Cheap** (\~\$50 handheld with dual USB-C)
* **Expandable** (WiFi, BT, USB storage, serial adapters)
* **Hackable** (Allwinner SoC with accessible boot partitions)

This project turns it from a **closed retro handheld** into a **general-purpose Linux hacking playground**.
