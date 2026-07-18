# Moon OS Gaming Guide

## Overview

Moon OS is designed for gaming. This guide will help you get the most out of your gaming experience.

## Gaming Platforms

### Steam

Steam is the primary gaming platform on Moon OS.

#### Installation
```bash
sudo pacman -S steam
```

#### Configuration
1. Launch Steam
2. Go to Settings > Compatibility
3. Enable "Enable Steam Play for all other titles"
4. Select Proton version (Proton 9.0 recommended)

#### Optimization
```bash
# Enable GameMode
sudo systemctl enable gamemoded

# Configure MangoHud
mangohud --help

# Use Gamescope
gamescope --help
```

### Heroic Games Launcher

Heroic Games Launcher supports Epic Games Store, GOG, and Amazon Prime Gaming.

#### Installation
```bash
sudo pacman -S heroic
```

#### Configuration
1. Launch Heroic
2. Login to your accounts
3. Install games
4. Configure Wine/Proton for each game

### Lutris

Lutris is an open gaming platform that supports multiple game sources.

#### Installation
```bash
sudo pacman -S lutris
```

#### Configuration
1. Launch Lutris
2. Add games from various sources
3. Configure runners for each game

### Wine

Wine allows you to run Windows applications and games.

#### Installation
```bash
sudo pacman -S wine wine-mono wine-gecko
```

#### Configuration
```bash
# Configure Wine
winetricks

# Install Windows components
winetricks corefonts
winetricks d3dx9
winetricks d3dx11
```

## Gaming Optimizations

### GameMode

GameMode optimizes system performance when gaming.

#### Installation
```bash
sudo pacman -S gamemode lib32-gamemode
```

#### Usage
```bash
# Run game with GameMode
gamemoderun %command%

# Check GameMode status
gamemoded --status

# Kill GameMode
gamemoded -k
```

### MangoHud

MangoHud is a performance overlay for Vulkan and OpenGL.

#### Installation
```bash
sudo pacman -S mangohud lib32-mangohud
```

#### Usage
```bash
# Run game with MangoHud
mangohud %command%

# Configure MangoHud
nano ~/.config/MangoHud/MangoHud.conf
```

#### MangoHud Configuration
```bash
# ~/.config/MangoHud/MangoHud.conf
legacy_layout=0
fps
fps_limit=0,144,165,240,360
frame_timing
frametime
gpu_stats
gpu_temp
gpu_power
gpu_core_clock
gpu_mem_clock
cpu_stats
cpu_temp
cpu_power
cpu_mhz
ram
vram
swap
font_size=24
position=top-left
background_alpha=0.4
background_color=000000
text_color=FFFFFF
```

### Gamescope

Gamescope is a micro-compositor for SteamOS.

#### Installation
```bash
sudo pacman -S gamescope
```

#### Usage
```bash
# Run game in Gamescope
gamescope -- %command%

# Configure Gamescope
gamescope --help
```

#### Gamescope Options
```bash
gamescope \
  --width 1920 \
  --height 1080 \
  --refresh-rate 144 \
  --fs \
  -- %command%
```

### DXVK

DXVK is a Vulkan-based translation layer for Direct3D 9/10/11.

#### Installation
```bash
sudo pacman -S dxvk lib32-dxvk
```

#### Configuration
```bash
# Set environment variables
export DXVK_ASYNC=1
export DXVK_HUD=fps,frametimes,drawcalls,pipelines

# Run game with DXVK
DXVK_ASYNC=1 %command%
```

### VKD3D

VKD3D is a Direct3D 12 to Vulkan translation layer.

#### Installation
```bash
sudo pacman -S vkd3d lib32-vkd3d
```

## Gaming Performance Tips

### General Tips

1. **Close unnecessary applications** before gaming
2. **Update drivers** regularly
3. **Enable GameMode** for automatic optimization
4. **Use MangoHud** to monitor performance
5. **Configure Steam Play** for Windows games

### CPU Optimization

```bash
# Set CPU governor to performance
sudo cpupower frequency-set -g performance

# Enable Turbo Boost
echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

# Disable CPU idle states
for cpu in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    echo 1 | sudo tee "$cpu"
done
```

### Memory Optimization

```bash
# Set swappiness
echo 10 | sudo tee /proc/sys/vm/swappiness

# Clear cache
sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"

# Enable KSM
echo 1 | sudo tee /sys/kernel/kernel/ksm/run
```

### I/O Optimization

```bash
# Set I/O scheduler to none for SSDs
echo none | sudo tee /sys/block/sda/queue/scheduler

# Increase read-ahead
echo 256 | sudo tee /sys/block/sda/queue/read_ahead_kb
```

### Network Optimization

```bash
# Enable BBR congestion control
sudo modprobe tcp_bbr
echo bbr | sudo tee /proc/sys/net/ipv4/tcp_congestion_control

# Increase buffer sizes
echo 16777216 | sudo tee /proc/sys/net/core/rmem_max
echo 16777216 | sudo tee /proc/sys/net/core/wmem_max
```

### GPU Optimization

#### NVIDIA
```bash
# Enable persistence mode
sudo nvidia-smi -pm 1

# Set power limit
sudo nvidia-smi -pl 300

# Set GPU clock
sudo nvidia-smi -ac 5001,1800
```

#### AMD
```bash
# Set performance level
echo "manual" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level

# Set GPU clock
echo "s 1 1800" | sudo tee /sys/class/drm/card0/device/pp_od_clk_voltage
echo "c" | sudo tee /sys/class/drm/card0/device/pp_od_clk_voltage
```

### Audio Optimization

```bash
# Configure PipeWire for low latency
mkdir -p ~/.config/pipewire/pipewire.conf.d
cat > ~/.config/pipewire/pipewire.conf.d/99-gaming.conf << EOF
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 64
    default.clock.min-quantum = 32
    default.clock.max-quantum = 2048
}
EOF

# Restart PipeWire
systemctl --user restart pipewire
```

## Gaming Controllers

### Supported Controllers

- Xbox One/Series X/S
- PlayStation 4/5
- Nintendo Switch Pro
- Steam Controller
- Generic USB controllers

### Configuration

```bash
# Install controller support
sudo pacman -S steam-controller-udev-rules

# Test controllers
jstest /dev/input/js0

# Configure controllers
steam://controllerconfiguration
```

## VR Gaming

### SteamVR

```bash
# Install SteamVR
sudo pacman -S steamvr

# Launch SteamVR
steam steam://launch/250820
```

### OpenXR

```bash
# Install OpenXR
sudo pacman -S openxr
```

## Streaming

### Steam Remote Play

1. Enable Remote Play in Steam settings
2. Connect from another device
3. Stream games over network

### Moonlight

```bash
# Install Moonlight
sudo pacman -S moonlight-qt

# Launch Moonlight
moonlight-qt
```

## Anti-Cheat Compatibility

### Supported Anti-Cheat

- **EasyAntiCheat**: Full support (Proton)
- **BattlEye**: Full support (Proton)
- **Vanguard**: Limited support
- **FaceIt**: Limited support

### Troubleshooting Anti-Cheat

```bash
# Check Proton version
ls ~/.steam/steam/compatibilitytools.d/

# Force specific Proton version
# Steam > Settings > Compatibility > Force specific Proton

# Check game logs
tail -f ~/.steam/steam/logs/console_log.txt
```

## Game-Specific Settings

### Cyberpunk 2077

```bash
# Launch options
DXVK_ASYNC=1 gamemoderun mangohud %command%
```

### Elden Ring

```bash
# Launch options
PROTON_ENABLE_NVAPI=1 DXVK_ASYNC=1 gamemoderun mangohud %command%
```

### Baldur's Gate 3

```bash
# Launch options
DXVK_ASYNC=1 gamemoderun mangohud %command%
```

### Hogwarts Legacy

```bash
# Launch options
DXVK_ASYNC=1 gamemoderun mangohud %command%
```

## Troubleshooting

### Game Won't Launch

1. Check Proton version
2. Verify game files
3. Check game logs
4. Try different Proton version

### Low FPS

1. Enable GameMode
2. Check MangoHud overlay
3. Verify GPU drivers
4. Check power settings

### Crashes

1. Check system logs
2. Verify game files
3. Check memory usage
4. Update drivers

### Audio Issues

1. Check audio settings
2. Restart PipeWire
3. Check game audio settings
4. Verify audio devices

## Getting Help

- **Documentation**: docs.moonos.dev/gaming
- **Community**: discord.gg/moonos
- **Reddit**: reddit.com/r/moonos
- **GitHub**: github.com/moonos/moonos
