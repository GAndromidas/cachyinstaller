# CachyInstaller
# CachyInstaller

A powerful post-installation script for CachyOS that transforms your system into an optimized gaming environment.

![CachyInstaller Logo](images/cachyinstaller.png)

---

## Demo
## Overview

![CachyInstaller Demo](images/demo.png)

## Features

- **Gaming Optimized**: Pre-configured for the best gaming experience
- **Easy to Use**: Simple installation process with clear options
- **Performance**: Automatic system optimization for gaming
- **Enhanced Fish**: Optimized Fish shell configuration with gaming features
- **Security**: Built-in protection with Fail2ban
- **Efficient**: Installs only what you need
- **Smart**: Tracks progress and provides clear feedback
- **Error Recovery**: Automatic state tracking and recovery from interruptions
- **Enhanced Security**: Improved system hardening and service protection
- **Robust Package Management**: Advanced retry logic and verification

---

## Installation

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

### Default Mode (Recommended)
Complete setup including:
- Gaming tools and optimizations
- Essential applications
- GPU driver configuration
- Fish shell optimization
- Security features
- Desktop improvements

### Minimal Mode
Basic setup with:
- Core gaming features
- Essential tools
- Basic security
- Minimal shell setup

---

## Smart System Optimization

### **Network Speed Detection**
- Automatic network speed measurement
- Dynamic package manager configuration
- Optimized parallel downloads
- Smart mirror selection using rate-mirrors

### **Package Manager Optimization**
- Parallel downloads based on network speed
- Enhanced progress bars and color output
- Intelligent mirror selection
- Paru optimization for AUR packages

### **Gaming Optimization**
- GPU-specific driver configuration
- Gaming mode tweaks
- MangoHud configuration
- Automatic hardware detection

### **Desktop Environment Integration**
- KDE/GNOME/COSMIC specific optimizations
- Custom shortcut configuration
- Theme compatibility
- Automatic backup of existing configs

---

## Installation Process

### **Step 1: System Preparation** 
- Network speed detection
- Package manager optimization
- Mirror list update
- System detection and configuration

### **Step 2: Shell Setup**
- Fish shell enhancement or ZSH conversion
- Custom shell configuration
- Starship prompt setup
- Shell utilities installation

### **Step 3: Programs Installation**
- Essential tools installation
- Development packages
- Media applications
- System utilities

### **Step 4: Gaming Mode**
- Steam and Proton setup
- GPU driver installation
- Gaming tools configuration
- Performance optimization

### **Step 5: Security Setup**
- Fail2ban configuration
- Firewall setup
- SSH hardening
- System protection

### **Step 6: System Services**
- Service optimization
- Desktop integration
- Performance tweaks
- Startup configuration

### **Step 7: Maintenance**
- System cleanup
- Configuration verification
- Performance check
- Final optimization

---

## Technical Features

### **System Detection**
- Hardware identification
- GPU vendor detection
- Laptop/Desktop recognition
- Environment detection

### **Performance Optimization**
- Network speed based configuration
- Parallel download optimization
- Package manager tuning
- System service optimization

### **Backup System**
- Automatic config backups
- State preservation
- Recovery options
- Configuration versioning

### **Error Handling**
- Comprehensive error detection
- Automatic recovery
- Detailed logging
- State preservation

---

## Btrfs Snapshot Management

### **Bootloader Integration**
- Automatic detection of GRUB or systemd-boot
- Optimized configuration for each bootloader type
- Boot menu integration for snapshot recovery
- Seamless bootloader updates with snapshots

### **Automated Snapshot System**
- Snapper integration for system snapshots
- btrfs-assistant GUI for easy management
- Automatic snapshots before and after package operations
- Intelligent snapshot cleanup and retention

### **Snapshot Features**
- Timeline snapshots (hourly, daily, weekly)
- Pre/post package installation snapshots
- Bootable snapshot recovery
- Space-aware snapshot management

### **Recovery Options**
- GRUB bootloader integration
- GUI-based snapshot restoration
- Command-line recovery tools
- Automatic space management

### **Configuration**
- Bootloader-specific optimizations
- Optimized retention policies
- Compressed snapshots with zstd
- Automatic cleanup of old snapshots
- Integration with pacman hooks

### **Bootloader-Specific Features**
GRUB:
- Direct boot menu entries for snapshots
- grub-btrfs integration
- Automatic menu updates
- Graphical snapshot selection

systemd-boot:
- Efficient boot entry integration
- Kernel parameter handling
- ESP partition management
- Boot entry auto-update

## Error Handling and Recovery

### **Automatic State Management**
- Continuous state tracking during installation
- Safe resumption from interruptions
- Automatic cleanup of temporary states
- Transaction-based operations

### **Package Installation Protection**
- Intelligent retry logic for failed installations
- Package verification after installation
- Dependency chain validation
- Automatic rollback of failed transactions

### **System Integrity**
- Critical package verification
- Service state validation
- Filesystem checks
- Configuration validation

### **Error Recovery**
- Granular step-by-step recovery
- Automatic detection of system state
- Safe restoration points
- Detailed error logging with stack traces

### **Performance Monitoring**
- Resource usage tracking
- Installation speed optimization
- Network connectivity validation
- System load management

---

## Installation Summary

The installer provides a comprehensive summary including:
- Installation duration
- Package statistics
- Configuration changes
- System optimizations
- Network performance
- Hardware detection results

Example Summary:
```
╔════════════════════════════════════╗
║     CACHYOS SETUP COMPLETE!        ║
╚════════════════════════════════════╝

Installation Details
   Duration: 0h 15m 32s
   Mode: Default
   Completed: 2024-01-15 14:30:25

System optimized for your hardware!
```

---

## FAQ
## Frequently Asked Questions

### Is it safe to use?
Yes, CachyInstaller is designed specifically for CachyOS and maintains system stability.

### Do I need to backup my files?
While the installer is safe, it's always good practice to backup important files.

### Will this modify my Fish shell?
Yes, it enhances the default CachyOS Fish shell with optimized gaming configurations and improved features.

### Will it improve gaming performance?
Yes, the installer includes optimizations specifically for gaming.

### What if something goes wrong?
The installer can safely recover from interruptions and includes automatic backup features.

### Do I need to reboot after installation?
Yes, a reboot is recommended to apply all optimizations.

---

## Contributing

We welcome contributions:
- Code improvements
- Package suggestions
- Documentation updates
- Testing feedback

---

## License

CachyInstaller is released under the MIT License.

---

**Ready to transform your CachyOS installation?** Let's begin!

```bash
git clone https://github.com/username/cachyinstaller.git
cd cachyinstaller
./install.sh
```
