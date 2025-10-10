# CachyInstaller

A robust and professional post-installation script designed to enhance your CachyOS system with optimized configurations, essential tools, and advanced features, focusing on stability, performance, and security.

## Overview

CachyInstaller streamlines the post-installation experience for CachyOS. It intelligently detects your system's hardware and environment to apply tailored optimizations, ensuring a highly performant and secure operating system. From gaming enhancements to system maintenance, CachyInstaller provides a comprehensive and automated solution.

<img width="820" height="444" alt="Screenshot_20250918_081412" src="https://github.com/user-attachments/assets/bb676b34-ae3f-4625-b8c9-7338c116c85e" />

## Features

- **Automated Enhancements**: Fully automated setup process with interactive prompts for user preferences.
- **System-Aware Optimizations**: Dynamically adapts configurations based on detected hardware (GPU, laptop/desktop) and desktop environment (KDE, GNOME, COSMIC).
- **Intelligent Package Management**:
    - **Optimized Mirror Selection**: Utilizes `rate-mirrors` and `reflector` for the fastest package download mirrors.
    - **Parallel Downloads**: Configures `pacman` and `paru` for efficient package installations based on network speed.
    - **AUR Integration**: Seamless installation of packages from the Arch User Repository (AUR) via `paru`.
    - **Flatpak Support**: Integrates and manages Flatpak applications from Flathub.
- **Enhanced Gaming Experience**:
    - **CachyOS Gaming Meta Package**: Prioritizes installation of the `cachyos-gaming-meta` package for a comprehensive gaming setup including Steam, Wine, MangoHud, GameMode, Lutris, Gamescope, and Goverlay.
    - **GPU Driver Configuration**: Automatic detection and installation of optimal drivers for NVIDIA, AMD, and Intel graphics cards.
    - **ProtonCachyOS**: Installs an optimized Proton version for superior Windows game compatibility on Steam.
- **Robust Shell Setup**:
    - **Fish Shell Optimization**: Configures the Fish shell with a Starship prompt and essential plugins (autopair, done, fzf, sponge).
    - **Fastfetch Integration**: Installs a customized Fastfetch configuration for system information display.
- **Security Hardening**:
    - **UFW Firewall**: Configures and enables the Uncomplicated Firewall (UFW) with sensible defaults.
    - **Fail2ban Protection**: Sets up Fail2ban to defend against brute-force attacks, particularly for SSH.
- **System Maintenance & Snapshots**:
    - **Automatic Cleanup**: Regularly cleans package caches, AUR build directories, and unused Flatpak runtimes.
    - **Btrfs Snapshot Management**: Integrates Snapper with `snap-pac` and `btrfs-assistant` for automated, bootable Btrfs snapshots, including pacman hooks for pre/post transaction snapshots.
    - **Bootloader Integration**: Configures GRUB or systemd-boot for seamless snapshot recovery.
- **Error Resilience & Recovery**:
    - **State Tracking**: Preserves installation state, allowing safe resumption after interruptions.
    - **Detailed Logging**: Comprehensive log file (`~/.cachyinstaller.log`) for reviewing installation steps and troubleshooting any issues.
    - **Configuration Backups**: Automatically backs up existing critical configuration files before applying changes.

---

## Installation

To get started with CachyInstaller, follow these steps:

1. Clone the repository:
```bash
git clone https://github.com/username/cachyinstaller.git
```

2. Navigate to the directory:
```bash
cd cachyinstaller
```

3. Run the installer:
```bash
./install.sh
```

## Installation Options

### Standard Mode (Recommended)
A complete setup encompassing all recommended optimizations and features, including:
- Comprehensive gaming tools and performance enhancements.
- Installation of essential applications and utilities.
- Automatic GPU driver configuration.
- Optimized Fish shell environment.
- Advanced security features (firewall, SSH protection).
- Desktop environment-specific improvements.

### Minimal Mode
A lightweight setup focused on core functionalities, providing:
- Essential gaming features.
- Fundamental system tools.
- Basic security configurations.
- Minimal shell enhancements.

---

## Smart System Optimization

### **Network Speed Detection**
- Automatic measurement of network download speed to inform optimizations.
- Dynamic adjustment of package manager configurations based on detected speed.
- Optimized parallel downloads for faster package retrieval.
- Intelligent selection of the fastest mirrors using `rate-mirrors` or `reflector`.

### **Package Manager Optimization**
- Configuration of parallel downloads in `pacman` and `paru` according to network bandwidth.
- Enhanced `pacman` with colored output and verbose package lists for better user experience.
- Automated `paru` cache cleaning for efficient AUR package management.

### **Gaming Optimization**
- Precise GPU-specific driver installation for NVIDIA, AMD, and Intel.
- System-wide gaming mode tweaks for improved performance and responsiveness.
- Configuration of MangoHud for in-game performance monitoring.
- Automatic detection of hardware components to tailor gaming optimizations.

### **Desktop Environment Integration**
- Specific optimizations and configurations for KDE Plasma, GNOME, and Cosmic Desktop.
- Custom global shortcut configuration for enhanced workflow.
- Theme compatibility adjustments.
- Automatic backup of existing desktop configuration files to prevent data loss.

---

## Installation Process

CachyInstaller guides you through a structured installation process, with each step designed for clarity and efficiency:

### **Step 1: System Preparation** 
- Measures network speed and optimizes package manager settings.
- Updates pacman mirror lists for faster downloads.
- Performs initial system detection for hardware and environment.

### **Step 2: Shell Setup**
- Installs and configures the Fish shell (or enhances existing setup).
- Sets up the Starship cross-shell prompt for a modern command-line interface.
- Installs various shell utilities and plugins for improved productivity.

### **Step 3: Programs Installation**
- Installs a curated selection of essential applications and tools from Pacman, AUR, and Flatpak.
- Tailors installations based on your chosen installation mode (Standard or Minimal).

### **Step 4: Gaming Mode**
- Installs `cachyos-gaming-meta` or individual gaming components.
- Configures GPU drivers and gaming-specific optimizations.
- Sets up tools like MangoHud and GameMode.

### **Step 5: Security Setup**
- Installs and configures the UFW firewall.
- Sets up Fail2ban for protection against brute-force attacks on services like SSH.

### **Step 6: System Services**
- Configures and enables essential system services such as `fstrim.timer`, `systemd-timesyncd`, `sshd` (if OpenSSH is installed), and `bluetooth` (if hardware detected).
- Applies desktop environment-specific tweaks for optimal integration.

### **Step 7: Maintenance**
- Performs a comprehensive system cleanup, including package caches and unused Flatpaks.
- Configures Btrfs snapshot management with Snapper and bootloader integration for recovery.
- Removes non-essential development helper packages like `gendesk`.

---

## Technical Features

### **System Detection**
- Advanced hardware identification, including GPU vendor and type.
- Accurate detection of laptop or desktop systems.
- Comprehensive environment detection for tailored configurations.

### **Performance Optimization**
- Dynamic tuning of package managers based on real-time network conditions.
- Optimized kernel parameters and system services for peak performance.
- Background process management for a responsive system.

### **Backup System**
- Automatic creation of timestamped backups for critical configuration files.
- State preservation during the installation process for seamless resumption.
- Facilitates recovery options for peace of mind.

### **Error Handling**
- Robust error detection and reporting with detailed log entries.
- Intelligent retry mechanisms for package installations.
- Preservation of installation state to enable recovery from interruptions.

---

## Btrfs Snapshot Management

CachyInstaller provides a highly integrated and automated Btrfs snapshot system for enhanced system resilience and easy recovery.

### **Bootloader Integration**
- Automatically detects and configures both GRUB and systemd-boot.
- Integrates snapshot recovery options directly into the boot menu.
- Ensures seamless bootloader updates while maintaining snapshot integrity.

### **Automated Snapshot System**
- Deep integration with Snapper for efficient system snapshots.
- `snap-pac` provides automatic pre- and post-transaction snapshots for package operations.
- `btrfs-assistant` GUI tool is installed for intuitive snapshot management.
- Intelligent cleanup policies automatically manage snapshot retention.

### **Snapshot Features**
- Configures timeline snapshots (hourly, daily, weekly) for continuous system protection.
- Supports pre and post-package installation snapshots, creating recovery points before system changes.
- Enables bootable snapshot recovery, allowing you to revert to a previous working state directly from the boot menu.
- Implements space-aware snapshot management to prevent excessive disk usage.

### **Recovery Options**
- Utilizes bootloader integration (GRUB or systemd-boot) for easy access to recovery options.
- Offers GUI-based snapshot restoration via `btrfs-assistant`.
- Provides command-line tools for advanced recovery scenarios.

### **Configuration**
- Sets up optimal retention policies for snapshots (e.g., 5 hourly, 7 daily).
- Integrates `snapper` with `pacman` hooks for automatic snapshot creation around system updates.

### **Bootloader-Specific Features**
**GRUB:**
- Direct boot menu entries for easy access to snapshots via `grub-btrfs`.
- Automatic updates of the GRUB menu when new snapshots are created.

**systemd-boot:**
- Efficient boot entry integration for snapshots.
- Manages kernel parameters for snapshot booting.
- Auto-updates boot entries for new snapshots.

## Error Handling and Recovery

CachyInstaller is built with robustness in mind, offering extensive error handling and recovery mechanisms.

### **Automatic State Management**
- Continuously tracks the installation state, allowing for safe resumption from any point of interruption.
- Automatically cleans up temporary files and states upon successful completion.

### **Package Installation Protection**
- Implements intelligent retry logic for transient package installation failures.
- Performs verification checks after each package installation to ensure integrity.

### **System Integrity**
- Validates critical system packages and services.
- Monitors filesystem health and ensures configuration validity.

### **Error Logging**
- Records all installation steps, warnings, and errors in a detailed log file (`~/.cachyinstaller.log`).
- Provides clear messages and actionable advice for troubleshooting.

---

## Installation Summary

Upon completion, the installer provides a comprehensive summary of the entire process, including:
- Total installation duration.
- Statistics on packages installed, updated, or removed.
- A concise overview of all applied configuration changes.
- Details on system and network performance optimizations.
- Information on detected hardware components.

---

## FAQ
## Frequently Asked Questions

### Is CachyInstaller safe to use?
Yes, CachyInstaller is meticulously designed for CachyOS, prioritizing system stability and integrity. It includes automatic backup features for critical configurations.

### Do I need to back up my files?
While CachyInstaller is engineered for safety, it is always best practice to perform a full backup of your important data before running any system modification script.

### Will this modify my Fish shell?
Yes, the script will enhance your Fish shell (or set it up if not present) with an optimized Starship prompt, essential plugins, and a custom Fastfetch configuration, significantly improving your command-line experience.

### Will it improve gaming performance?
Absolutely. CachyInstaller includes a suite of gaming-specific optimizations, GPU driver installations, and configuration of tools like MangoHud and GameMode, all aimed at delivering the best possible gaming performance on CachyOS.

### What if something goes wrong during installation?
CachyInstaller features robust error handling and state tracking, allowing it to safely resume from interruptions. Detailed logs (`~/.cachyinstaller.log`) are generated to assist with troubleshooting.

### Do I need to reboot after installation?
Yes, a reboot is highly recommended to ensure all system services, kernel parameters, and desktop environment configurations are fully applied and take effect.

---

## Contributing

We welcome and appreciate all forms of contributions to CachyInstaller:
-   **Code Improvements**: Enhance existing features or add new ones.
-   **Package Suggestions**: Recommend additional packages or optimizations.
-   **Documentation Updates**: Improve clarity and completeness of the README or other docs.
-   **Testing Feedback**: Report bugs or suggest usability improvements.

---

## License

CachyInstaller is released under the MIT License.

---

**Ready to elevate your CachyOS experience?** Let's begin!

```bash
git clone https://github.com/username/cachyinstaller.git
cd cachyinstaller
./install.sh
```
