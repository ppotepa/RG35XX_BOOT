# Anbernic RG35XX Custom Boot & Kernel Mods

> ⚠️ **Work in Progress**  
> This project is under active development. Features, kernels, and installation procedures may change at any time.

This repo contains a collection of **custom boot modifications** and **kernel experiments** for the **Anbernic RG35XX H** handheld device.  
The goal is to make the RG35XX more **DIY-friendly**, enabling developers to replace stock software, customize boot behavior, and extend the console beyond retro gaming.

---

## 🔎 Project Status & Reality Check (2025-09-08)

**TL;DR:** Using this project will get you as far as **successfully changing the kernel**. After that, a stock userspace component **takes over the primary framebuffer** and **redirects the visible console to a different TTY**. 
You can still scrape logs and debug, but **it’s tedious compared to flashing a fresh, clean build**.

### What this means in practice
- After kernel → userspace handoff, the on-device screen often **stops showing the expected VT/console**. The launcher/boot wrapper writes straight to `/dev/fb0`, while the real console lives on another TTY (according to boot cfg its tty=S0) and may not be visible.
- Debugging still works via **serial console**, **initramfs shell**, or by forcing **`console=tty0`** (or baking it into the kernel with `CONFIG_CMDLINE`). On stock rootfs, though, you’ll play whack-a-mole.
- If you want fast iteration, **installing/flashing a freshly created build** (predictable services, getty/VT, logging) is usually **faster and cleaner** than fighting the stock image.

### Recommended paths
- **Stick with this repo** if you want to: swap kernels, test DTBs, validate boot packaging, or study the stock boot chain.
- **Prefer a fresh build** if you want: reproducible logs on LCD, straightforward TTY behavior, and fewer stock quirks.

---

## ✨ Features

### Boot Mods
- **Custom Splash Screen** → Replace the default boot logo with your own image.
- **Mass Storage Mode** → Expose internal partitions as USB drives for easy file management.
- **Boot Menu Wrapper** → Override stock `dmenu` with a custom menu for flexible booting and logging.
- **Safe Installation** → Automatic backup of original files before modification. :contentReference[oaicite:0]{index=0}

### Kernel & System Hacking
- **Kernel Builds** → Linux **4.14.170** compiled and tested for `arm64`.
- **Partition Mapping** → Identified all partitions (`mmcblk0p1–p7`) with roles (boot args, kernel, rootfs, etc.).
- **Bootargs Editing** → Verified UART/console redirection (e.g., `console=tty1` vs `console=ttyS0`).
- **Device Tree Work** → Attempted DTB extraction from `zImage` (LZO-compressed blobs).
- **Recovery Safety** → Backups of `boot_orig.img`, `kernel_partition.img`, and `bootargs_p3_backup.bin`. :contentReference[oaicite:1]{index=1}

---

## 🧷 Userspace Hooks: `/mnt/vendor/bin` (launchapp, dmenu_ln)

After the **boot sector** and **initial `boot.img`** are loaded, the stock userspace mounts a vendor partition at **`/mnt/vendor`**. The binaries in **`/mnt/vendor/bin`** are your key takeover points:

- **`launchapp`** → launches the **SDL-based UI** that draws directly to the framebuffer (steals `/dev/fb0`).
- **`dmenu_ln`** → handles the **main app/launcher**; wrapping this binary usually gives you control.

> Experience note: even after compiling an **Allwinner H700–friendly kernel**, you still run into a blocker—**DTB/DTS regions are LZ-compressed** inside the stock kernel image, which makes the **initial script chain complicated to overwrite**. Expect some yak-shaving; this path took ~**3–4 days** of digging.

### Practical wrapper approach

If you need to intercept control **after kernel handoff** but before the UI takes over the LCD:

```bash
# Ensure vendor is mounted and writable
mount | grep -q ' /mnt/vendor ' || mount /mnt/vendor || true
mount -o rw,remount /mnt/vendor

# Wrap dmenu_ln (can be a symlink or binary)
if [ -e /mnt/vendor/bin/dmenu_ln ] && [ ! -e /mnt/vendor/bin/dmenu_ln.orig ]; then
  mv /mnt/vendor/bin/dmenu_ln /mnt/vendor/bin/dmenu_ln.orig
fi

cat > /mnt/vendor/bin/dmenu_ln <<'SH'
#!/bin/sh
set -eu
# Optional: log early somewhere writable
# exec >/tmp/dmenu_ln.log 2>&1
# Optionally adjust env:
# export SDL_VIDEODRIVER=fbcon
exec /mnt/vendor/bin/dmenu_ln.orig "$@"
SH
chmod +x /mnt/vendor/bin/dmenu_ln

# (Optional) Similarly wrap launchapp if needed:
# mv /mnt/vendor/bin/launchapp /mnt/vendor/bin/launchapp.orig
# ...create a wrapper that logs/adjusts env, then execs launchapp.orig
````

**Caveats**

* Some stock images **restore** these files on boot via init scripts. Do changes **late** (e.g., custom initramfs) or protect your wrapper.
* `dmenu_ln` may be a **symlink**; point the wrapper to the real target.
* Prefer **serial** or **early initramfs** logging while iterating; the userspace UI will still try to steal `/dev/fb0` soon after.

---

## 📂 Repo Structure

```
RG35XX_BOOT/
├── kernel-4.1/        # Kernel-related bits for the 4.14.x line
├── scripts/           # Helper scripts (packing, etc.)
├── install.sh         # Quick installer
├── logo.png           # Example custom splash/logo
└── README.md
```

> Note: names reflect the current repo state. Adjust as you add newer kernel trees (e.g., `linux-6.10.y`). ([GitHub][1])

---

## ⚙️ Technical Notes

* **Bootloader & Menu** → The stock menu stack is a graphics/SDL userspace that **writes directly to `/dev/fb0`** and can **steal the visible display** from the framebuffer console.
* **Framebuffer** → Custom logos/UI integrate with the framebuffer; expect userspace to overwrite the screen soon after boot.
* **Kernel Args** → Boot args live in a dedicated partition; tweak to force `console=tty0` or configure serial (`ttyS0`).
* **Stock Kernel Lineage** → Allwinner **4.9.x**, DTBs embedded in compressed `zImage`.
* **Custom Kernel Lineage** → **4.14.170** currently noted here; ensure **correct DTB** for panel/input power/clocking. ([GitHub][1])

---

## 🚀 Installation

### Prerequisites

* RG35XX H with **root access**
* **Terminal/SSH access** to the device
* (Optional) Custom splash/logo file (`logo.png`) ([GitHub][1])

### Quick Install

1. Copy the repository (or just the scripts you need) to the device.
2. Make the installer executable and run it:

   ```bash
   chmod +x ./install.sh
   ./install.sh
   ```

> The installer backs up boot/args, applies your boot menu/logo changes, and installs as configured. ([GitHub][1])

### Manual Install (Expert)

1. **Back up**: boot image, kernel partition (if separate), and boot args.
2. **Build kernel** (match your target branch) and **select DTB**.
3. **Package & Flash**: repack the boot image with your kernel+DTB strategy, flash it to the boot partition, and install matching modules.
4. **Adjust bootargs** (console, loglevel) as needed.

---

## 🧰 Troubleshooting & Tips

* **No console on LCD?** It’s likely been redirected. Try:

  * Force `console=tty0` (and/or start a getty on `tty0`).
  * Use **serial console** for reliable visibility.
  * Temporarily boot with `init=/bin/sh` to keep control before userspace steals the framebuffer.
* **Panel/input issues?** Re-test with alternate DTBs for H700 variants.
* **Need logs?** Use serial, or dump `dmesg` early from initramfs to a writable partition.

---

## 🗺️ Roadmap

* [ ] Document a **clean, fresh-build path** (recommended for day-to-day hacking).
* [ ] Harden guidance for **DTB selection/merge** on H700 panels.
* [ ] Provide an optional **initramfs** with early shell + netconsole.
* [ ] Expand boot menu with **multi-OS / multi-kernel** support. ([GitHub][1])

---

## 💡 Why This Project?

The RG35XX H is:

* **Cheap** (\~\$50 handheld with dual USB-C)
* **Expandable** (Wi-Fi, BT, USB storage, serial adapters)
* **Hackable** (Allwinner SoC with accessible boot partitions)

This project turns it from a **closed retro handheld** into a **general-purpose Linux hacking playground**. If you hit the stock userspace wall, consider the **fresh build** route—fewer surprises, faster iteration.
