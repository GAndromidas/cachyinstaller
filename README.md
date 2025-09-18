# CachyInstaller 🎮

**The definitive post-installation script for CachyOS** - Transform your fresh CachyOS installation into a fully-configured gaming powerhouse!

---

## 🎬 Demo

<img width="825" height="739" alt="Screenshot_20250918_075832" src="https://github.com/user-attachments/assets/a5b45fe3-b9f8-460b-a9b7-81d3e83631aa" />

## 🌟 What Makes CachyInstaller Special?

- **🎯 CachyOS Native**: Built specifically for CachyOS with zero conflicts
- **🎮 Gaming-First**: Always includes gaming packages with GPU-specific drivers
- **🔧 Simplified Modes**: Just 3 options - Default, Minimal, or Exit
- **🐚 Smart Shell Handling**: Fish enhancement or complete ZSH conversion
- **🛡️ Security Ready**: Automatic Fail2ban SSH protection
- **🔥 Zero Bloat**: Only installs what you actually need
- **📊 Smart Tracking**: Real-time installation progress and comprehensive logging

---

## 🚀 Quick Installation

```bash
git clone https://github.com/username/cachyinstaller.git
cd cachyinstaller
chmod +x install.sh
./install.sh
```

**That's it!** CachyInstaller handles everything else automatically.

---

## 🎮 Gaming Excellence

CachyInstaller transforms CachyOS into the **ultimate gaming machine**:

### **🎯 Core Gaming Stack**
- **Steam**: Via CachyOS gaming meta package (Mesa-git compatible)
- **ProtonCachyOS**: Enhanced Proton with CachyOS optimizations
- **Lutris**: Open-source game manager for Wine/Proton games
- **Wine**: Windows compatibility layer with latest improvements
- **MangoHud**: Performance overlay for monitoring FPS/temps
- **GPU Detection**: Automatically installs correct drivers (AMD Mesa-git, NVIDIA utils, Intel)
- **CachyOS Gaming Meta**: Uses official CachyOS gaming package for Steam compatibility
- **GameMode**: Real-time system optimizations during gaming
- **Discord**: Communication platform for gamers
- **OBS Studio**: Streaming and recording software
- **Heroic Games Launcher**: Epic Games Store client (smart detection)
- **Gamescope**: Wayland compositor for gaming sessions
- **Goverlay**: GUI for MangoHud configuration

### **🎮 Why Gaming Mode is Always Enabled**
CachyOS is fundamentally a **gaming-focused distribution**. Unlike generic installers, CachyInstaller recognizes this and automatically includes the complete gaming stack in both Default and Minimal modes, because that's what you came to CachyOS for!

---

## 🛡️ CachyOS Integration Philosophy

CachyInstaller follows a **"Zero Conflict"** approach with CachyOS:

### **✅ What CachyInstaller Handles (Safe Zone)**
- 📦 **User Applications**: Steam, Discord, OBS, media tools
- 🐚 **Shell Configuration**: Fish/ZSH setup with Starship prompts
- 🎮 **Gaming Tools**: Lutris, Wine, MangoHud, GameMode
- 🛡️ **Security Setup**: Fail2ban, UFW firewall configuration
- 🔧 **User Configs**: Fastfetch, MangoHud, KDE shortcuts
- 📱 **Flatpak Apps**: Desktop applications via Flathub
- 🎯 **AUR Packages**: Community applications via paru
- 💾 **NTFS Support**: External drive compatibility

### **🚫 What CachyInstaller Avoids (CachyOS Territory)**
- 🚫 **Kernels**: CachyOS optimized kernels and headers
- 🚫 **Graphics Drivers**: NVIDIA/AMD/Intel driver management (system level)
- 🚫 **ZRAM**: Memory compression and swap optimization
- 🚫 **Plymouth**: Boot splash screen and themes
- 🚫 **Pacman Configuration**: Repository priorities and mirrors
- 🚫 **Microcode**: CPU microcode updates
- 🚫 **Performance Tweaks**: CachyOS-specific optimizations

**Result**: Zero conflicts with CachyOS native management! ✨

---

## 🎯 Installation Modes

### **🔥 Default Mode (Recommended)**
The complete CachyInstaller experience:
- All essential applications and tools
- Complete gaming stack with GPU drivers
- Full shell configuration (Fish enhancement or ZSH conversion)
- Security hardening (Fail2ban + UFW)
- Desktop environment optimizations
- Flatpak applications for enhanced functionality

**Perfect for**: New CachyOS users who want a fully-configured system

### **⚡ Minimal Mode (Fast Track)**
Streamlined installation for experienced users:
- Essential system tools and utilities
- Complete gaming stack (always included)
- Basic shell setup with minimal plugins
- Core security configuration
- Skip most Flatpak applications

**Perfect for**: Experienced users who prefer manual customization

### **❌ Exit Mode**
Cancel installation and keep your current CachyOS setup unchanged.

---

## 🐚 Intelligent Shell Management

CachyInstaller handles CachyOS's default **Fish shell** intelligently:

### **🐠 Fish Enhancement (Default Choice)**
- Preserves your existing CachyOS Fish configuration
- Adds CachyInstaller fastfetch configuration
- Maintains all Fish-specific CachyOS optimizations
- **Zero Risk**: Your current setup remains functional

### **🐚 Fish → ZSH Conversion (Advanced Option)**
- **Complete replacement**: Removes Fish entirely from system
- Installs Oh-My-Zsh framework with essential plugins
- Configures Starship prompt for beautiful terminal experience
- Replaces shell configuration with CachyInstaller's ZSH setup
- **⚠️ Warning**: This permanently removes Fish - choose wisely!

**Smart Detection**: CachyInstaller automatically detects your current shell and offers appropriate options.

---

## 📋 Installation Process Overview

### **Step 1: System Preparation** 📦
- Updates CachyOS package database
- Installs essential build tools and utilities
- Handles shell packages (ZSH if converting from Fish)

### **Step 2: Shell Setup** 🐚
- Fish users: Enhancement or complete ZSH conversion
- Installs Oh-My-Zsh framework and plugins (if ZSH chosen)
- Configures Starship prompt for beautiful terminal
- Replaces fastfetch config with CachyInstaller version

### **Step 3: Programs Installation** 🖥️
- Installs applications based on chosen mode and desktop environment
- Smart CachyOS package filtering (skips conflicts)
- Handles Pacman, AUR (paru), and Flatpak packages
- Includes NTFS-3G for external drive support

### **Step 4: Gaming Mode** 🎮
- Always runs (no choice needed - it's a gaming distro!)
- Uses CachyOS gaming meta package for optimal Mesa-git compatibility
- Includes: Steam, Wine, MangoHud, GameMode, Lutris, Gamescope, Goverlay
- Detects GPU type and installs appropriate drivers (AMD Mesa-git, NVIDIA utils, Intel)
- Installs ProtonCachyOS for enhanced Steam performance
- Configures MangoHud with custom performance overlay
- Smart Heroic Games Launcher detection (installs via AUR if needed)
- Additional tools: ProtonPlus (Flatpak) for Proton management

### **Step 5: Fail2ban Setup** 🛡️
- Installs and configures SSH protection
- Sets aggressive security: 3 attempts, 1-hour bans
- Enables automatic startup

### **Step 6: System Services** ⚙️
- Enables UFW firewall
- Configures essential system services
- Desktop environment specific tweaks (KDE shortcuts, etc.)

### **Step 7: Maintenance** 🧹
- System cleanup and optimization
- Updates desktop/font/MIME databases
- Generates installation summary

---

## 📊 Installation Summary & Tracking

CachyInstaller provides comprehensive installation tracking:

### **Real-Time Information** ⏱️
- ✅ Installation duration (hours, minutes, seconds)
- ✅ Package installation count
- ✅ Package removal count (Fish conversion)
- ✅ Error tracking and reporting
- ✅ Installation mode and date logging

### **Detailed Logging** 📝
- ✅ Complete log saved to `~/cachyinstaller.log`
- ✅ Step-by-step progress tracking
- ✅ Error messages and warnings
- ✅ Package installation verification
- ✅ Configuration file backup timestamps

### **Installation Summary Example**
```
╔══════════════════════════════════════════════════════════════╗
║                    INSTALLATION COMPLETE                     ║
╚══════════════════════════════════════════════════════════════╝

📊 Installation Summary:
   Duration: 0h 15m 32s
   Install Mode: default
   Date: 2024-01-15 14:30:25

📦 Packages Installed (45): cachyos-gaming-meta, proton-cachyos, discord...
🗑️  Packages Removed (1): fish (if ZSH conversion chosen)
⚠️  Errors: 0

🎮 Gaming Stack: ✅ Fully Configured
🛡️  Security: ✅ Fail2ban Active
🐚 Shell: ✅ ZSH with Oh-My-Zsh (or Fish Enhanced)
🖥️  Desktop: ✅ KDE Shortcuts Applied

🎯 CachyOS is ready for gaming! Reboot recommended for full effect.

📋 What's Next:
   • Reboot to activate all changes
   • Launch Steam to test gaming setup
   • Check MangoHud overlay in games (Shift+F12)
   • Verify Fail2ban: sudo fail2ban-client status
```

---

## 🎯 Desktop Environment Support

### **KDE Plasma** 🖥️ (Primary Support)
- Custom global shortcuts configuration
- KDE-specific applications and tools
- Plasma integration enhancements

### **GNOME** 🌟 (Full Support)
- GNOME-specific applications and extensions
- GTK theme optimizations
- GNOME Shell integration

### **COSMIC** 🚀 (Growing Support)
- System76's next-generation desktop environment
- Modern application stack
- Wayland-native experience

---

## 🔧 Configuration Files

CachyInstaller includes carefully curated configuration files:

```
configs/.zshrc          - Custom ZSH configuration with aliases
configs/starship.toml   - Starship prompt configuration
configs/MangoHud.conf   - Gaming performance overlay settings
configs/config.jsonc    - Fastfetch system information display
configs/kglobalshortcutsrc - KDE global shortcuts
configs/programs.yaml   - Complete package lists and desktop environment mappings
```

All configurations are **backed up** before replacement, ensuring you can always restore your original setup.

---

## 🚀 Advanced Features

### **🎮 GPU-Specific Driver Installation**
- **AMD GPUs**: Automatically installs `lib32-mesa-git` and `mesa-git` for bleeding-edge performance
- **NVIDIA GPUs**: Installs `lib32-nvidia-utils` and `nvidia-utils` for optimal compatibility
- **Intel GPUs**: Configures Intel graphics with Vulkan support
- **Detection**: Uses `lspci` for accurate hardware identification

### **📦 Smart Package Management**
- **CachyOS Awareness**: Skips packages already managed by CachyOS
- **Conflict Resolution**: Automatically handles Mesa-git compatibility issues
- **Multi-Source**: Seamlessly combines Pacman, AUR, and Flatpak packages
- **Smart Detection**: Heroic Games Launcher installed only if not included in meta package

### **🛡️ Comprehensive Security**
- **Fail2ban**: SSH brute-force protection with aggressive settings
- **UFW Firewall**: Simplified firewall management
- **Service Hardening**: Optimal security configurations

### **🎨 Desktop Integration**
- **KDE**: Global shortcuts, theme compatibility
- **GNOME**: Extensions and GTK optimizations
- **Universal**: Works across all major desktop environments

---

## 🌐 Community & Support

### **🐛 Found a Bug?**
Open an issue on our GitHub repository with:
- Your CachyOS version
- Installation mode used
- Complete error log from `~/cachyinstaller.log`
- Steps to reproduce

### **💡 Feature Requests**
We welcome suggestions for new features and improvements!

### **🤝 Contributing**
CachyInstaller is open-source and welcomes contributions:
- Code improvements
- New package suggestions
- Documentation updates
- Testing on different configurations

---

## ⚖️ License

CachyInstaller is released under the **MIT License** - see LICENSE file for details.

---

## 🎯 Final Words

**CachyInstaller isn't just another installation script** - it's a **carefully crafted transformation tool** specifically designed for CachyOS users who want to maximize their system's potential without breaking anything.

Whether you're a **gaming enthusiast**, **developer**, or **power user**, CachyInstaller respects CachyOS's philosophy while adding the applications and configurations you actually need.

### **Key Advantages:**

✅ **Mesa-git Compatible**: Steam works flawlessly with CachyOS bleeding-edge packages
✅ **GPU Optimized**: Automatic driver detection for AMD, NVIDIA, and Intel
✅ **Zero Conflicts**: Never interferes with CachyOS native management
✅ **Gaming Ready**: Complete gaming stack with all major platforms
✅ **Security Hardened**: Fail2ban and firewall protection out of the box
✅ **Shell Flexible**: Keep Fish or convert to ZSH - your choice
✅ **Desktop Optimized**: Special configurations for KDE, GNOME, and COSMIC
✅ **Smart Installation**: Detects existing packages to avoid duplicates

---

## 🔧 Recent Improvements & Technical Details

### **🎮 Gaming Stack Optimization**
- **CachyOS Gaming Meta Integration**: Uses official `cachyos-gaming-meta` package for Steam compatibility
- **Mesa-git Compatibility**: Resolves Steam installation conflicts with CachyOS bleeding-edge Mesa packages
- **GPU-Specific Drivers**: Automatic detection and installation of optimal drivers:
  - **AMD**: `lib32-mesa-git`, `mesa-git`, Vulkan Radeon drivers
  - **NVIDIA**: `lib32-nvidia-utils`, `nvidia-utils`
  - **Intel**: Mesa + Vulkan Intel drivers
- **ProtonCachyOS**: Enhanced Proton with CachyOS-specific optimizations
- **Smart Package Detection**: Heroic Games Launcher installed only if not included in meta package

### **📦 Package Management Intelligence**
- **NTFS-3G Support**: Automatic external drive compatibility for Windows filesystems
- **Duplicate Prevention**: Checks existing installations before adding packages
- **Multi-Source Integration**: Seamlessly combines Pacman, AUR, and Flatpak packages
- **Conflict Avoidance**: Skips packages already managed by CachyOS

### **🐚 Shell Configuration Streamlined**
- **Fastfetch Integration**: Configuration moved to shell setup for logical organization
- **Fish Enhancement**: Preserves CachyOS Fish configuration while adding improvements
- **ZSH Conversion**: Complete Oh-My-Zsh setup with essential plugins and Starship prompt
- **Zero Duplication**: Removed duplicate fastfetch functionality between scripts

### **🛡️ Security & System Integration**
- **Desktop Environment Awareness**: KDE shortcuts, GNOME optimizations, COSMIC support
- **Service Configuration**: UFW firewall + Fail2ban SSH protection
- **Configuration Backup**: All original configs backed up with timestamps
- **Clean Installation Flow**: Simplified 7-step process (removed redundant system configuration step)

---

**Ready to transform your CachyOS experience?** 🚀

```bash
git clone https://github.com/username/cachyinstaller.git
cd cachyinstaller
./install.sh
```

**Welcome to the ultimate CachyOS gaming experience!** 🎮✨

---

## 📋 Version & Credits

### **Version Information**
- **CachyInstaller**: v1.0 - CachyOS Gaming Edition
- **Target Platform**: CachyOS (Arch-based gaming distribution)
- **Supported Architectures**: x86_64

### **🙏 Acknowledgments**
- **CachyOS Team**: For creating an exceptional Arch-based gaming distribution with bleeding-edge optimizations
- **ArchInstaller Project**: Original foundation and architectural inspiration
- **CachyOS Community**: Testing, feedback, and real-world usage insights
- **Gaming Community**: Contributions to MangoHud, GameMode, and Proton compatibility

### **🔗 Related Projects**
- **CachyOS**: [cachyos.org](https://cachyos.org)
- **CachyOS Wiki**: [wiki.cachyos.org](https://wiki.cachyos.org)
- **CachyOS Gaming Guide**: [wiki.cachyos.org/configuration/gaming](https://wiki.cachyos.org/configuration/gaming/)

---

*CachyInstaller - Because your CachyOS deserves the best configuration* 💎
