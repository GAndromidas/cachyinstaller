# CachyInstaller (Personal Fork)

> Automated post-installation script for CachyOS with Hyprland, NVIDIA Wayland, and AI/Dev workflow setup.

---

## Based on the work of GAndromidas

This project is a fork of the original [CachyInstaller](https://github.com/GAndromidas/cachyinstaller) by GAndromidas. The original project provided a solid foundation — a robust, automated post-installation script for CachyOS that handles package installation, shell configuration, gaming setup, and system services with minimal user interaction.

This fork diverges significantly to serve a specific personal setup: a Hyprland-only environment on an NVIDIA laptop with an AI/development workflow. The changes are not a criticism of the original — they reflect a different use case. If you need multi-DE support (KDE, GNOME, COSMIC) or the original feature set, the upstream repository is the right choice.

Thank you, GAndromidas, for building something that saved real time and made this fork possible.

---

## What this fork does differently

- **Hyprland-only** — KDE, GNOME, and COSMIC support removed
- **NVIDIA Wayland compatibility** — dedicated hardware setup step with environment variables, EGL, and VA-API drivers
- **Flatpak runtime available, no Flatpak installs** — Flatpak runtime is kept for compatibility, but package installations are removed (handled elsewhere if needed)
- **Gaming mode restored** — installs Steam, MangoHud, GameMode, Wine, and Proton tools via `cachyos-gaming-meta` (Lutris and Heroic excluded — not needed for this setup)
- **xdg-desktop-portal configured** — Hyprland portal + KDE portal for Dolphin and Qt/KDE apps to open files correctly
- **AI/Dev packages added** — Ollama, Docker, nvidia-container-toolkit, Python, Rust, Node.js, plus uv and mise (AUR)
- **Script modularization** — `common.sh` refactored into `ui.sh`, `logging.sh`, `install_helpers.sh`
- **constants.sh added** — centralized named constants for disk space, steps, Fisher URL/checksum
- **Fisher checksum verification** — SHA256 validation before Fisher install
- **`--keep` flag** — keeps installer directory after completion
- **README environment variables section** — documented all variables and shared arrays

---

## Requirements

- CachyOS (fresh install recommended)
- NVIDIA GPU (this fork is tuned for NVIDIA + Wayland)
- Internet connection
- Minimum 2GB free disk space
- User with sudo privileges (do NOT run as root)

---

## Installation

```bash
git clone https://github.com/Hnocuru/cachyinstaller.git
cd cachyinstaller
chmod +x install.sh
./install.sh
```

### Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Preview all changes without applying anything |
| `--keep` | Keep the installer directory after completion |
| `--help` | Show usage information |
| `-v, --verbose` | Enable verbose output |
| `-q, --quiet` | Quiet mode (minimal output) |

---

## Installation steps

| Step | Script | Description |
|------|--------|-------------|
| 1 | `system_preparation.sh` | pacman optimization, mirrors, base config |
| 2 | `hardware_setup.sh` | NVIDIA + Wayland env vars, kernel param check |
| 3 | `shell_setup.sh` | Fish shell, Starship, Fisher plugins, portal config |
| 4 | `programs.sh` | packages via pacman, paru AUR, Docker, virtualization |
| 5 | `gaming_mode.sh` | Optional: Steam, MangoHud, GameMode, Proton (confirm prompt) |
| 6 | `fail2ban.sh` | SSH protection |
| 7 | `system_services.sh` | systemd services: UFW, bluetooth, fstrim, timesyncd |
| 8 | `maintenance.sh` | cache cleanup |

---

## Package highlights

### Hyprland stack
waybar, hyprlock, hypridle, hyprpaper, hyprpolkitagent, wofi, kitty, mako, qt5-wayland, qt6-wayland, qt5ct, qt6ct, kvantum, nwg-look, dolphin, ark, gwenview, okular, kate, wl-clipboard, cliphist, grim, slurp, xdg-desktop-portal-hyprland, xdg-desktop-portal-kde

### Development and AI
ollama, docker, docker-compose, lazydocker, nvidia-container-toolkit, python, python-pip, direnv, zellij, atuin, uv (AUR), mise (AUR), rustup, nodejs, npm, pnpm, lazygit, visual-studio-code-bin (AUR)

### Gaming (optional step)
Steam, MangoHud, GameMode, Wine, cachyos-gaming-meta, protonplus
(Lutris and Heroic excluded — not needed for this setup)

---

## CUDA — manual install note

CUDA is not installed automatically (~5GB download). Install only after verifying your Hyprland session is stable:

```bash
# Verify GPU is detected first
nvidia-smi

# Then install CUDA (~5GB download)
sudo pacman -S cuda
```

Required for: Blender OptiX/CUDA rendering, Ollama GPU inference, and ML/AI workflows with GPU acceleration.

---

## Environment Variables

These variables control installer behavior. They can be set before running `install.sh` to override defaults.

| Variable | Type | Default | Description | Defined in |
|---|---|---|---|---|
| INSTALL_MODE | string | default | Package set to install (default/minimal) | install.sh |
| VERBOSE | bool | false | Print progress messages to stdout | install.sh |
| DRY_RUN | bool | false | Preview changes without applying them | install.sh |
| GPU_VENDOR | string | auto-detected | Override GPU vendor detection (amd/nvidia/intel) | install.sh |
| IS_LAPTOP | bool | auto-detected | Override laptop detection | install.sh |
| INSTALL_LOG | string | ~/.cachyinstaller.log | Path to installation log file | install.sh |
| KEEP_DIR | bool | false | Keep installer directory after completion | install.sh |
| MIN_DISK_KB | int | 2097152 | Minimum free disk space in KB (2 GB) | constants.sh |
| TOTAL_STEPS | int | 8 | Number of installation steps | constants.sh |
| FISHER_URL | string | (see constants.sh) | Fisher install script URL | constants.sh |
| FISHER_CHECKSUM | string | (see constants.sh) | Expected SHA256 of Fisher script | constants.sh |

### Shared Arrays

These arrays are declared globally in `common.sh` and shared across scripts.

| Array | Purpose | Written by | Read by |
|---|---|---|---|
| INSTALLED_PACKAGES | Tracks successfully installed packages | programs.sh, gaming_mode.sh | install.sh (final summary) |
| FAILED_PACKAGES | Tracks packages that failed to install | programs.sh, gaming_mode.sh | install.sh (final summary) |
| ERRORS | General error messages for final report | all scripts via log_error() | install.sh (final summary) |

---

## Project structure

```
cachyinstaller/
├── install.sh
├── README.md
├── LICENSE
├── scripts/
│   ├── common.sh          # entry point — sources all modules
│   ├── constants.sh       # named constants and URLs
│   ├── ui.sh              # gum wrappers and ANSI output
│   ├── logging.sh         # log file management
│   ├── install_helpers.sh # package installation wrappers
│   ├── hardware_setup.sh  # NVIDIA + Wayland compatibility
│   ├── shell_setup.sh     # Fish, Starship, Fisher, portal config
│   ├── programs.sh        # package installation
│   ├── gaming_mode.sh     # optional gaming stack
│   ├── fail2ban.sh        # SSH protection
│   ├── system_services.sh # systemd services
│   ├── system_preparation.sh
│   └── maintenance.sh
├── configs/
│   ├── programs.yaml      # package definitions
│   ├── gaming_mode.yaml  # gaming packages
│   ├── fish/
│   ├── fastfetch/
│   ├── user-fish-config/
│   ├── cachyos-fish-config/
│   ├── kglobalshortcutsrc
│   └── MangoHud.conf
└── tests/
    ├── run_tests.sh
    ├── static/
    ├── unit/
    └── integration/
```

---

## License

MIT License — same as the original project. See [LICENSE](LICENSE) file for details.