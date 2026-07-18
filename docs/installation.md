# Moon OS Installation Guide

## System Requirements

### Minimum Requirements

| Component | Minimum |
|-----------|---------|
| CPU | 64-bit x86_64, 2 cores, 2 GHz |
| RAM | 4 GB |
| Storage | 20 GB |
| GPU | DirectX 11 compatible |
| Network | Broadband Internet |

### Recommended Requirements

| Component | Recommended |
|-----------|-------------|
| CPU | 64-bit x86_64, 8+ cores, 4 GHz+ |
| RAM | 16+ GB |
| Storage | 100+ GB SSD/NVMe |
| GPU | NVIDIA RTX 3060+ / AMD RX 6600+ |
| Network | Gigabit Ethernet |

### Supported Hardware

#### CPUs
- **Intel**: Core i3/i5/i7/i9 (6th gen+)
- **AMD**: Ryzen 3/5/7/9
- **Intel**: Xeon (8th gen+)
- **AMD**: EPYC/Ryzen Threadripper

#### GPUs
- **NVIDIA**: GTX 1000+ / RTX 2000+ / RTX 3000+ / RTX 4000+
- **AMD**: RX 5000+ / RX 6000+ / RX 7000+
- **Intel**: UHD 600+ / Iris Xe / Arc

#### Storage
- SATA SSD
- NVMe SSD
- HDD (for storage, not recommended for OS)
- USB 3.0+ (for Live USB)

#### Laptops
- All major laptop brands supported
- Automatic power management
- Automatic brightness control
- Suspend/Resume support

#### Gaming Handhelds
- Steam Deck
- ROG Ally
- Legion Go
- Ayaneo

## Installation Methods

### 1. Live USB (Recommended for Testing)

#### Creating a Bootable USB

**Windows:**
1. Download Rufus from [rufus.ie](https://rufus.ie)
2. Select the Moon OS ISO
3. Select your USB drive
4. Click "Start"

**Linux:**
```bash
sudo dd if=moonos-*.iso of=/dev/sdX bs=4M status=progress
```

**macOS:**
```bash
sudo dd if=moonos-*.iso of=/dev/rdiskX bs=4m
```

#### Booting from USB
1. Insert USB drive
2. Restart computer
3. Press boot menu key (F12, F2, Del, Esc)
4. Select USB drive
5. Select "Moon OS Live"

### 2. Full Installation

#### Step 1: Boot from Live USB
1. Boot from Live USB
2. Select "Install Moon OS"

#### Step 2: Select Language
Choose your preferred language from the list.

#### Step 3: Select Keyboard Layout
Choose your keyboard layout.

#### Step 4: Select Timezone
Choose your timezone.

#### Step 5: Select Disk
Select the disk to install Moon OS on.

**WARNING: All data on the selected disk will be erased!**

#### Step 6: Select Partition Scheme
- **UEFI**: For modern systems (recommended)
- **Legacy BIOS**: For older systems
- **Dual Boot**: Install alongside Windows

#### Step 7: Create User
Enter your username and password.

#### Step 8: Select Desktop
Choose your preferred desktop environment:
- **COSMIC**: Modern, Rust-based (recommended)
- **GNOME**: Polished, macOS-like
- **KDE Plasma**: Feature-rich, Windows-like
- **Hyprland**: Wayland tiling, gaming-optimized

#### Step 9: Confirm Installation
Review your settings and confirm installation.

#### Step 10: Reboot
Remove the installation media and reboot.

### 3. Dual Boot with Windows

#### Prerequisites
- Windows 10/11 installed
- UEFI boot mode
- Secure Boot (can be left enabled)

#### Steps
1. Boot from Moon OS Live USB
2. Select "Install Moon OS"
3. Select "Dual Boot" partition scheme
4. Select the Windows partition
5. Follow the installation steps

#### Post-Installation
Moon OS will automatically detect Windows and add it to the GRUB menu.

### 4. Automated Installation

For unattended installation:

```bash
sudo ./mooninstaller automated \
    --disk=sda \
    --user=yourusername \
    --password=yourpassword \
    --hostname=moonos-gaming \
    --timezone=America/New_York \
    --keyboard=us \
    --language=en_US.UTF-8 \
    --desktop=cosmic \
    --partition=uefi
```

### 5. Persistent USB

To create a persistent USB installation:

1. Boot from Live USB
2. Open terminal
3. Run:
```bash
sudo mooninstaller persistent --disk=/dev/sdb
```

## Post-Installation

### First Boot

1. Login with your username and password
2. The hardware detection system will run automatically
3. Drivers will be installed automatically
4. Gaming optimizations will be applied

### Update System

```bash
sudo pacman -Syu
```

### Install Gaming Platform

```bash
# Install Steam
sudo pacman -S steam

# Install Heroic Games Launcher
sudo pacman -S heroic

# Install Lutris
sudo pacman -S lutris

# Install Wine
sudo pacman -S wine
```

### Enable Gaming Mode

```bash
# Enable GameMode
sudo systemctl enable gamemoded

# Enable MangoHud
mangohud --help
```

### Configure Graphics

```bash
# NVIDIA
sudo nvidia-settings

# AMD
sudo nvidia-settings  # For AMD with AMDGPU

# Intel
sudo intel-gpu-tools
```

### Configure Audio

```bash
# Restart PipeWire
systemctl --user restart pipewire
systemctl --user restart pipewire-pulse
systemctl --user restart wireplumber
```

## Troubleshooting

### Boot Issues

**Problem**: System doesn't boot
**Solution**: Check BIOS/UEFI settings:
- Enable UEFI boot mode
- Disable Secure Boot (if needed)
- Set correct boot order

**Problem**: GRUB not found
**Solution**: Boot from Live USB and reinstall GRUB:
```bash
sudo arch-chroot /mnt
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
```

### Graphics Issues

**Problem**: Black screen after boot
**Solution**: Boot withnomodeset:
1. Edit GRUB menu
2. Add `nomodeset` to kernel parameters
3. Boot and install correct drivers

**Problem**: Screen tearing
**Solution**: Enable compositing:
```bash
# For GNOME
gsettings set org.gnome.desktop.interface enable-animations true

# For KDE
# System Settings > Display > Compositor > Enable
```

### Network Issues

**Problem**: No internet connection
**Solution**:
```bash
# Restart NetworkManager
sudo systemctl restart NetworkManager

# Check connection
ip addr show

# Connect to WiFi
nmcli device wifi list
nmcli device wifi connect <SSID> password <password>
```

### Audio Issues

**Problem**: No sound
**Solution**:
```bash
# Check audio devices
aplay -l

# Restart PipeWire
systemctl --user restart pipewire
systemctl --user restart pipewire-pulse
systemctl --user restart wireplumber

# Check volume
alsamixer
```

### Gaming Issues

**Problem**: Games not launching
**Solution**:
```bash
# Check Proton version
ls ~/.steam/steam/compatibilitytools.d/

# Test with different Proton version
# Steam > Settings > Compatibility > Force specific Proton

# Check GameMode
gamemoded --version
```

**Problem**: Low FPS
**Solution**:
```bash
# Enable GameMode
gamemoded -r

# Check MangoHud
mangohud glxgears

# Optimize GPU
sudo nvidia-settings  # For NVIDIA
```

## Getting Help

- **Documentation**: docs.moonos.dev
- **Community**: discord.gg/moonos
- **Reddit**: reddit.com/r/moonos
- **GitHub**: github.com/moonos/moonos
