# CachyInstaller

**The definitive post-installation script for CachyOS** - Transform your fresh CachyOS installation into a fully-configured gaming powerhouse!

---

## Demo

<img width="820" height="444" alt="Screenshot_20250918_081412" src="https://github.com/user-attachments/assets/bb676b34-ae3f-4625-b8c9-7338c116c85e" />

## What Makes CachyInstaller Special?

- **CachyOS Native**: Built specifically for CachyOS with zero conflicts
- **Gaming-First**: Always includes gaming packages with GPU-specific drivers
- **Smart Optimization**: Automatic network speed detection and package manager tuning
- **Smart Shell Handling**: Fish enhancement or complete ZSH conversion
- **Security Ready**: Automatic Fail2ban SSH protection and system hardening
- **Zero Bloat**: Only installs what you actually need
- **Smart Tracking**: Real-time installation progress and comprehensive logging
- **Error Recovery**: Automatic state tracking and recovery from interruptions
- **Enhanced Security**: Improved system hardening and service protection
- **Robust Package Management**: Advanced retry logic and verification

---

## Quick Installation

```bash
git clone https://github.com/username/cachyinstaller.git
cd cachyinstaller
chmod +x install.sh
./install.sh
```

**That's it!** CachyInstaller handles everything else automatically.

---

## Installation Modes

### **Default Mode (Recommended)**
The complete CachyInstaller experience:
- All essential applications and tools
- Complete gaming stack with GPU drivers
- Full shell configuration (Fish enhancement or ZSH conversion)
- Security hardening (Fail2ban + UFW)
- Desktop environment optimizations
- Flatpak applications for enhanced functionality

### **Minimal Mode (Fast Track)**
Streamlined installation for experienced users:
- Essential system tools and utilities
- Complete gaming stack (always included)
- Basic shell setup with minimal plugins
- Core security configuration
- Skip most Flatpak applications

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

### Will this break my CachyOS setup?
No, CachyInstaller respects CachyOS's native package management.

### Can I keep using Fish shell?
Yes, you can choose between Fish enhancement or ZSH conversion.

### Is gaming support mandatory?
Yes, CachyOS is a gaming-focused distribution.

### What about NVIDIA GPUs?
Fully supported with automatic driver installation.

### How does error recovery work?
The installer uses a transaction-based system with automatic state tracking. If any step fails, it can safely roll back or retry operations while preserving system stability.

### What happens if installation is interrupted?
The installer can safely resume from the last successful state.

### How are failed installations handled?
Failed package installations are automatically retried and verified.

### Is the system validated after installation?
Yes, comprehensive checks verify system integrity and package installation.

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
