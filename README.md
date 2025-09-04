# Anbernic RG35XX Custom Boot Mods

> **⚠️ Work in Progress**: This project is currently under active development. Features and installation procedures may change.

A collection of custom boot modifications for the Anbernic RG35XX handheld gaming device. The target is to override the stock dmenu application to show a custom menu for customized boot without the need of adding a second SD card or installing another system. Currently runs Ubuntu and includes custom splash screen support and mass storage functionality.

## Features

- **Custom Splash Screen**: Replace the default boot logo with your own image
- **Mass Storage Mode**: Expose internal partitions as USB drives for easy file management
- **Boot Menu Wrapper**: Enhanced boot menu functionality with logging
- **Safe Installation**: Automatic backup of original files before modification

## Technical Notes

- **dmenu**: The boot menu system is an SDL application that writes directly to `/dev/fb0` (framebuffer device)
- **Display Integration**: Custom logos and UI elements integrate with the existing framebuffer rendering system

## Installation

### Prerequisites

- Anbernic RG35XX device with root access
- Custom logo file (optional) - place `logo.png` in the same directory as `install.sh`
- Terminal access to the device

### Quick Install

1. **Download or copy the installer to your device**
2. **Make the installer executable:**

### Manual Installation Steps

If you prefer to understand what the installer does:

	1. **Backup original files**	 (installer does this automatically):