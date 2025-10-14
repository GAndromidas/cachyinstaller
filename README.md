# CachyInstaller

A simple, robust, and fully automated post-installation script designed to enhance your CachyOS system. It respects CachyOS defaults, runs unattended, and cleans up after itself, leaving your system perfectly configured.

## Overview

CachyInstaller streamlines the post-installation experience for CachyOS. It intelligently applies optimizations, installs curated applications based on your preferences, and enhances system security. The script is designed to be "fire-and-forget"—run it once, and your system is ready to go.

<img width="820" height="444" alt="Screenshot_20250918_081412" src="https://github.com/user-attachments/assets/bb676b34-ae3f-4625-b8c9-7338c116c85e" />

## Core Principles

-   **Fully Automated**: After an initial menu selection, the script runs without any further user interaction (with one optional exception in Minimal mode).
-   **Respects Defaults**: The installer enhances your system without overriding the sensible defaults provided by the CachyOS team, especially regarding drivers and snapshot configurations.
-   **Non-Destructive**: Your personal configuration files are safe. The script will only place default configurations if you don't already have one.
-   **Self-Cleaning**: Upon successful completion, the script automatically removes its own directory and log files, leaving no trace.

---

## Installation

To get started with CachyInstaller, follow these steps:

1.  Clone the repository:
    ```bash
    git clone https://github.com/your-username/cachyinstaller.git
    ```

2.  Navigate to the directory:
    ```bash
    cd cachyinstaller
    ```

3.  Make the script executable and run it:
    ```bash
    chmod +x install.sh
    ./install.sh
    ```

---

## Installation Options

You will be prompted to choose one of two installation modes:

### Standard Mode (Recommended)
This is the fully automated "do everything" option. It installs a complete suite of applications and enhancements for a feature-rich desktop experience, including the full gaming setup.

### Minimal Mode
This provides a lightweight setup with essential tools. It will pause once to ask for your confirmation before installing the gaming-related packages, giving you control over your minimal installation.

---

## The Process

CachyInstaller runs through a sequence of 7 automated steps:

-   **Step 1: System Preparation**: Optimizes `pacman` for your network speed and updates system keyrings and package lists.
-   **Step 2: Shell Enhancement**: Sets up the Fish shell with the Starship prompt and useful plugins. Only places default configs if none exist.
-   **Step 3: Program Installation**: Installs applications from the `programs.yaml` file based on your chosen mode (Standard/Minimal) and detected desktop environment.
-   **Step 4: Gaming Mode**: Installs the `cachyos-gaming-meta` package to provide the official CachyOS gaming experience. In Minimal mode, this step is optional.
-   **Step 5: Security Hardening**: Automatically installs, configures, and enables the UFW firewall and Fail2ban (for SSH protection).
-   **Step 6: System Services**: Enables useful systemd services and applies non-destructive desktop tweaks (e.g., KDE global shortcuts).
-   **Step 7: Maintenance & Cleanup**: Cleans all package manager caches (`pacman`, `paru`, `flatpak`) to free up disk space. **This step does not touch your Btrfs snapshot setup.**

---

## FAQ

### Is this script safe to re-run?
Yes. The script is designed to be idempotent. Package installations will only install missing or outdated packages, and configuration files will not be overwritten if they already exist. You can safely re-run the script to install new packages you've added to the `programs.yaml` file.

### Will this overwrite my custom shell configuration?
No. The script will only copy default configuration files for `fish`, `starship`, `MangoHud`, etc., if it detects that you don't already have one. Your existing custom configs are safe.

### Does this script manage my Btrfs snapshots?
No. To fully respect the CachyOS defaults, this script **does not** install, remove, or configure any snapshot software like Snapper or Timeshift. Your existing snapshot setup is left untouched.

### What happens after the script finishes?
If the script completes without any errors, it will ask you to reboot. It will then automatically delete the `cachyinstaller` directory and its log file, leaving your system clean. If an error occurs, the files will be left in place for you to inspect the logs.

---

## License

CachyInstaller is released under the MIT License.