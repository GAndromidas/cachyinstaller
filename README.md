<div align="center">

# CachyInstaller
### Your Fully Automated CachyOS Post-Install Companion

</div>

<p align="center">
  A simple, robust, and professional post-installation script designed to enhance your CachyOS system. It respects CachyOS defaults, runs unattended after your initial choice, and leaves your system perfectly configured and ready to use.
</p>

</div>

---

## ➤ Core Principles

CachyInstaller is built on a clear philosophy to ensure a safe, pleasant, and powerful user experience.

-   **⚙️ Fire-and-Forget Automation**: After an initial menu selection, the script runs to completion without any further user interaction.
-   **🛡️ Enhance, Don't Replace**: The installer enhances your system without overriding the sensible defaults and performance optimizations provided by the CachyOS team — especially regarding drivers, the bootloader, and the kernel.
-   **✍️ Non-Destructive**: Your personal configuration files are safe. The script will only place default configurations (`fish`, `starship`, `MangoHud`, etc.) if you don't already have one, and it never rewrites your bootloader.
-   **🔁 Resumable**: Progress is tracked per step. If the run is interrupted, just run the installer again — completed steps are skipped automatically.
-   **👁️ Verifiable**: A read-only health check (`scripts/verify.sh`, or `./install.sh --check`) confirms the install actually worked after you reboot.

---

## ➤ Getting Started

Getting your CachyOS system set up is simple.

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/GAndromidas/cachyinstaller.git
    ```

2.  **Navigate to the Directory**
    ```bash
    cd cachyinstaller
    ```

3.  **Make the Script Executable**
    ```bash
    chmod +x install.sh
    ```

4.  **Run the Installer**
    ```bash
    ./install.sh
    ```

Requirements: a fresh CachyOS installation, an active internet connection, a regular user account with sudo privileges, and at least 2GB of free disk space.

---

## ➤ Installation Modes

You will be prompted to choose one of two installation modes for general applications. The optional Gaming Mode setup is offered separately as its own step.

### Standard Mode (Recommended)
This is the fully automated "do everything" option. It installs a complete suite of applications and enhancements for a feature-rich desktop experience.

### Minimal Mode
This provides a lightweight setup with only essential tools, perfect for users who prefer a smaller base to build upon.

---

## ➤ Command-Line Options

```
./install.sh [OPTIONS]

    -h, --help      Show the help message and exit
    -V, --version   Show version information and exit
    -v, --verbose   Enable verbose output (show all package installation details)
    -q, --quiet     Quiet mode (minimal output)
    -d, --dry-run   Preview what will be installed without making changes
    -a, --auto      Automatically select the recommended installation mode
    -y, --yes       Non-interactive mode: accept safe/default prompts automatically
    -c, --check     Read-only health check (runs scripts/verify.sh, changes nothing)
```

Examples:

```bash
./install.sh                # Interactive install
./install.sh --dry-run      # Preview changes without making them
./install.sh --auto         # Automatically choose the recommended mode
./install.sh --yes          # Run unattended with safe/default choices
./install.sh --check        # Verify an installed system (safe, read-only)
```

---

## ➤ Features & The Installation Process

CachyInstaller runs through a sequence of 9 steps with a live dashboard, providing a clear summary of packages to be installed at each stage.

| # | Step | What it does |
|---|------|--------------|
| 1 | System Preparation | Optimizes `pacman` for your network speed, refreshes keyrings, and syncs package databases. |
| 2 | Shell Enhancement | Sets up the modern **Fish shell** with the **Starship** prompt, Fisher, and useful plugins. Only places default configs if none exist. |
| 3 | Program Installation | Installs applications from `programs.yaml` based on your mode (Standard/Minimal) and desktop environment (KDE, GNOME, etc.) via official repos, the AUR (`paru`), and Flatpak. |
| 4 | Gaming Mode (optional) | Installs the CachyOS gaming stack (Steam, Wine, MangoHud, launchers). You are always asked first — declining cleanly skips the step. |
| 5 | Bootloader Verification | **Read-only.** Reports whether GRUB or systemd-boot is in use and confirms its core files are present. Your bootloader is never installed, reconfigured, or overwritten. |
| 6 | Security Hardening | Installs, configures, and enables the **UFW firewall** and **Fail2ban** (SSH brute-force protection). |
| 7 | System Services | Enables useful systemd services (`fstrim.timer` for SSDs, time sync, Bluetooth/SSH where hardware applies) and desktop tweaks (e.g. KDE global shortcuts). |
| 8 | Wake-on-LAN (opt-in) | Configures Wake-on-LAN on wired desktops that support it (systemd unit + udev rule). Skipped automatically on VMs, laptops without consent, and Wi-Fi-only systems. |
| 9 | Maintenance & Cleanup | Cleans package manager caches (`pacman`, `paru`, `flatpak`) to free up disk space. |

Key technologies:

-   **Fish shell + Starship**: modern interactive shell with plugins (`fisher`, `fzf.fish`, `autopair`, `done`, `sponge`).
-   **paru**: the default AUR helper — AUR packages install through `paru` (with `yay` accepted as a fallback if you already have it).
-   **btrfs / snapper preserved**: if your CachyOS install uses btrfs with snapper, the installer leaves that stack alone and the verifier reports on it.
-   **Hardware-aware**: multi-GPU detection (hybrids fully reported), laptop detection (battery + chassis type), and desktop-environment-aware package selection.

---

## ➤ Project Structure

```
cachyinstaller/
├── install.sh              # Orchestrator: flags, dashboard, per-step runner, resume
├── scripts/
│   ├── common.sh           # Compatibility facade (banner, menu, reboot prompt, summary)
│   ├── lib/
│   │   ├── core.sh         # Logging, error handling, core utilities
│   │   ├── ui.sh           # Terminal UI (gum with plain-text fallback)
│   │   ├── system.sh       # Hardware detection (GPU, laptop, bootloader, VM)
│   │   ├── package.sh      # pacman / paru / Flatpak helpers with retries
│   │   ├── config.sh       # YAML parsing (yq with built-in fallback)
│   │   ├── state.sh        # Resume state (COMPLETED / SKIPPED / FAILED)
│   │   └── dashboard.sh    # Live step dashboard
│   ├── modules/
│   │   ├── system_preparation.sh
│   │   ├── shell_setup.sh
│   │   ├── programs.sh
│   │   ├── gaming_mode.sh
│   │   ├── bootloader_check.sh
│   │   ├── fail2ban.sh
│   │   ├── system_services.sh
│   │   ├── wakeonlan_config.sh
│   │   └── maintenance.sh
│   └── verify.sh           # Read-only post-reboot health check
├── configs/
│   ├── programs.yaml       # Packages for Standard / Minimal modes
│   ├── gaming_mode.yaml    # Packages for the optional Gaming Mode
│   └── fish/ ...           # Default Fish / Starship / Fastfetch configs
└── tests/
    └── syntax.sh           # bash -n over every shell script
```

---

## ➤ Customization

The heart of CachyInstaller's flexibility lies in its configuration files. You can easily add or remove packages to perfectly tailor the installation to your needs before running the script:
-   **`configs/programs.yaml`**: Manages packages for the `Standard` and `Minimal` installation modes.
-   **`configs/gaming_mode.yaml`**: Manages all packages for the optional Gaming Mode setup.

---

## ➤ Resume & Safety

-   **Resume**: progress is recorded in `/var/tmp/cachyinstaller.state` (which survives reboots; legacy `~/.cachyinstaller.state` files migrate forward automatically). Re-run `./install.sh` to continue from the last successful step. To start over, delete the state file: `rm -f /var/tmp/cachyinstaller.state`.
-   **Dry-run**: `./install.sh --dry-run` previews every step without writing files, installing packages, or changing services.
-   **Logs**: full output is saved to `/var/tmp/cachyinstaller.log`. The log is kept after installation for troubleshooting — the installer never deletes its own logs or state on success.
-   **Signals**: `Ctrl+C` stops the installer safely, records the failure, and tells you how to resume.
-   **Idempotent**: package installs only affect missing packages, config files are not overwritten, and re-running is always safe.

---

## ➤ Verification

After rebooting, confirm the install actually worked:

```bash
bash scripts/verify.sh
# or
./install.sh --check
```

The check is entirely read-only and covers: boot mode and bootloader presence, CPU/GPU drivers, storage and btrfs/snapper health, firewall and fail2ban status, Wake-on-LAN state, maintenance timers, Fish/Starship/paru presence, and the gaming stack (when installed).

Check code health anytime with:

```bash
bash tests/syntax.sh
```

---

## ➤ Troubleshooting

| Symptom | What to do |
|---------|------------|
| `System compatibility check failed` | Confirm you are on CachyOS with internet access and 2GB+ free space; see the log for the exact issue. |
| A step failed but others passed | Re-run `./install.sh` — completed steps are skipped; only the failed step retries. |
| `paru` prompts during AUR installs | AUR builds can ask interactive questions; run in a terminal you can watch, or pre-install `paru` yourself. |
| Steam installed without Vulkan choice | Gaming Mode installs Steam non-interactively (provider auto-selected). For `mesa-git` instead of `mesa`, install it manually: `sudo pacman -S mesa-git`. |
| Wake-on-LAN shows "Skipped" | Expected on VMs, Wi-Fi-only systems, and NICs without magic-packet support. Also enable "Power On by PCI-E" in your BIOS/UEFI. |
| Need a fresh start | `rm -f /var/tmp/cachyinstaller.state` and run again. |

---

## ➤ Frequently Asked Questions (FAQ)

**Is this script safe to re-run?**
> Yes. The script is designed to be idempotent. Package installations only affect missing or outdated packages, and configuration files are not overwritten. You can safely re-run it to apply changes from your `programs.yaml` file.

**Will this overwrite my custom shell configuration?**
> No. The script will only copy default configuration files for `fish`, `starship`, `MangoHud`, etc., if it detects that you don't already have one (or yours differs and you chose a preset that replaces it). Your custom configs are safe.

**Will this touch my bootloader?**
> No. The bootloader step is verification-only: it reports GRUB or systemd-boot and checks that core files exist. It never installs or reconfigures anything boot-related.

**What happens after the script finishes?**
> You get a summary of what was set up, the log path, and a reboot prompt. Logs and progress files are kept in `/var/tmp` for troubleshooting.

---

## ➤ Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request for any improvements or bug fixes.

## ➤ License

This project is licensed under the **MIT License**.
