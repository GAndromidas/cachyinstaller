<div align="center">

# CachyInstaller
### Your Fully Automated CachyOS Post-Install Companion

</div>

<p align="center">
  A simple, robust, and professional post-installation script designed to enhance your CachyOS system. It respects CachyOS defaults, runs unattended after your initial choice, and cleans up after itself, leaving your system perfectly configured and ready to use.
</p>

<div align="center">

<img width="820" height="444" alt="Screenshot_20250918_081412" src="https://github.com/user-attachments/assets/bb676b34-ae3f-4625-b8c9-7338c116c85e" />

</div>

---

## ➤ Core Principles

CachyInstaller is built on a clear philosophy to ensure a safe, pleasant, and powerful user experience.

-   **⚙️ Fire-and-Forget Automation**: After an initial menu selection, the script runs to completion without any further user interaction.
-   **🛡️ Respects Defaults**: The installer enhances your system without overriding the sensible defaults provided by the CachyOS team, especially regarding drivers.
-   **✍️ Non-Destructive**: Your personal configuration files are safe. The script will only place default configurations (`fish`, `MangoHud`, etc.) if you don't already have one.
-   **🧹 Clean Finish**: Upon successful completion, the script automatically removes its own directory and log files, leaving no trace.

---

## ➤ Getting Started

Getting your CachyOS system set up is simple.

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/your-username/cachyinstaller.git
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

---

## ➤ Installation Modes

You will be prompted to choose one of two installation modes for general applications. The optional Gaming Mode setup is offered separately after this choice.

### Standard Mode (Recommended)
This is the fully automated "do everything" option. It installs a complete suite of applications and enhancements for a feature-rich desktop experience.

### Minimal Mode
This provides a lightweight setup with only essential tools, perfect for users who prefer a smaller base to build upon.

---

## ➤ Features & The Installation Process

CachyInstaller runs through a sequence of 7 automated steps, providing a clear and beautiful summary of packages to be installed at each stage.

#### ✔️ Step 1: System Preparation
Optimizes `pacman` for your network speed by configuring parallel downloads and updates system keyrings and package lists.

#### ✔️ Step 2: Shell Enhancement
Sets up the modern and user-friendly **Fish shell** with the **Starship** prompt and useful plugins. It only places default configs if none exist, preserving your customizations.

#### ✔️ Step 3: Program Installation
Installs applications from the `programs.yaml` file based on your chosen mode (Standard/Minimal) and your detected desktop environment (KDE, GNOME, etc.). It handles packages from the official repositories, the AUR, and Flatpak.

#### ✔️ Step 4: Gaming Mode
Offers a comprehensive gaming setup by installing the official `cachyos-gaming-meta` package, which provides a cohesive, high-performance CachyOS gaming experience. The script also installs other essential tools like Discord, OBS Studio, and Wine, and modern game launchers like Heroic Games Launcher and Faugus Launcher via Flatpak. This hybrid approach ensures you get the best of the CachyOS optimizations while guaranteeing all your favorite applications are present. The script will always ask for your confirmation before installing any gaming-related packages.

#### ✔️ Step 5: Security Hardening
Automatically installs, configures, and enables the **UFW firewall** and **Fail2ban** (for SSH brute-force protection).

#### ✔️ Step 6: System Services
Enables useful systemd services (like `fstrim.timer` for SSDs) and applies non-destructive desktop tweaks (e.g., KDE global shortcuts).

#### ✔️ Step 7: Maintenance & Cleanup
Cleans all package manager caches (`pacman`, `paru`, `flatpak`) to free up valuable disk space.

---

## ➤ Customization

The heart of CachyInstaller's flexibility lies in its configuration files. You can easily add or remove packages to perfectly tailor the installation to your needs before running the script:
-   **`configs/programs.yaml`**: Manages packages for the `Standard` and `Minimal` installation modes.
-   **`configs/gaming_mode.yaml`**: Manages all packages for the optional Gaming Mode setup.

---

## ➤ Frequently Asked Questions (FAQ)

**Is this script safe to re-run?**
> Yes. The script is designed to be idempotent. Package installations only affect missing or outdated packages, and configuration files are not overwritten. You can safely re-run it to apply changes from your `programs.yaml` file.

**Will this overwrite my custom shell configuration?**
> No. The script will only copy default configuration files for `fish`, `starship`, `MangoHud`, etc., if it detects that you don't already have one. Your custom configs are safe.

**What happens after the script finishes?**
> If the script completes without any errors, it will ask you to reboot and then automatically delete its own directory and log file. If an error occurs, the files will be left in place for you to inspect the logs for troubleshooting.

---

## ➤ Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request for any improvements or bug fixes.

## ➤ License

This project is licensed under the **MIT License**.