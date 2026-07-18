#!/bin/bash
# MoonOS Installer - Bootloader Installation
# GRUB installation and configuration

# Install GRUB bootloader
install_grub() {
    local disk="$1"
    local mount_point="${2:-/mnt}"
    local target="${3:-x86_64-efi}"

    echo "Installing GRUB bootloader..."

    case "$target" in
        x86_64-efi|aarch64-efi)
            install_grub_efi "$disk" "$mount_point" "$target"
            ;;
        i386-pc)
            install_grub_bios "$disk" "$mount_point"
            ;;
        *)
            echo "Unknown GRUB target: $target"
            return 1
            ;;
    esac
}

# Install GRUB for EFI
install_grub_efi() {
    local disk="$1"
    local mount_point="$2"
    local target="${3:-x86_64-efi}"

    # Determine partition naming
    local part_prefix
    if [[ "$disk" == *"nvme"* ]] || [[ "$disk" == *"mmcblk"* ]]; then
        part_prefix="p"
    else
        part_prefix=""
    fi

    # Install GRUB
    grub-install \
        --target="$target" \
        --efi-directory="${mount_point}/boot/efi" \
        --boot-directory="${mount_point}/boot" \
        --removable \
        --recheck

    # Generate GRUB configuration
    grub-mkconfig -o "${mount_point}/boot/grub/grub.cfg"

    echo "EFI GRUB installation complete."
}

# Install GRUB for BIOS
install_grub_bios() {
    local disk="$1"
    local mount_point="$2"

    # Determine disk without partition number
    local base_disk
    base_disk=$(echo "$disk" | sed 's/[0-9]*$//')

    # Install GRUB
    grub-install \
        --target=i386-pc \
        --boot-directory="${mount_point}/boot" \
        --modules="part_gpt part_msdos ext2 fat" \
        --recheck \
        "$base_disk"

    # Generate GRUB configuration
    grub-mkconfig -o "${mount_point}/boot/grub/grub.cfg"

    echo "BIOS GRUB installation complete."
}

# Generate GRUB configuration
generate_grub_config() {
    local mount_point="${1:-/mnt}"
    local root_uuid
    root_uuid=$(get_partition_uuid "${INSTALL_CONFIG[target_disk]}2")

    cat > "${mount_point}/boot/grub/grub.cfg" << EOF
# MoonOS GRUB Configuration

set default=0
set timeout=5

# Colors
set menu_color_normal=cyan/blue
set menu_color_highlight=white/blue

menuentry "MoonOS" {
    search --no-floppy --fs-uuid --set=root ${root_uuid}
    linux /boot/vmlinuz root=UUID=${root_uuid} rootwait rw quiet
    initrd /boot/initramfs.img
}

menuentry "MoonOS (Recovery)" {
    search --no-floppy --fs-uuid --set=root ${root_uuid}
    linux /boot/vmlinuz root=UUID=${root_uuid} rootwait rw single
    initrd /boot/initramfs.img
}

menuentry "MoonOS (Verbose)" {
    search --no-floppy --fs-uuid --set=root ${root_uuid}
    linux /boot/vmlinuz root=UUID=${root_uuid} rootwait rw debug
    initrd /boot/initramfs.img
}

menuentry "Memory Test (memtest86+)" {
    linux /boot/memtest86+
}
EOF
}

# Configure GRUB options
configure_grub() {
    local mount_point="${1:-/mnt}"
    local grub_config="${mount_point}/etc/default/grub"

    cat > "$grub_config" << 'EOF'
# MoonOS GRUB Defaults

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu

# Distribution info
GRUB_DISTRIBUTOR="MoonOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""

# Memory test
GRUB_MEMTEST=""

# Disable OS prober
GRUB_DISABLE_OS_PROBER=true

# Theme
GRUB_THEME="/boot/grub/themes/moonos/theme.txt"
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
EOF
}

# Create GRUB theme
create_grub_theme() {
    local mount_point="${1:-/mnt}"
    local theme_dir="${mount_point}/boot/grub/themes/moonos"

    mkdir -p "$theme_dir"

    # Create theme configuration
    cat > "${theme_dir}/theme.txt" << 'EOF'
# MoonOS GRUB Theme

title-text: "MoonOS"
title-color: "#ffffff"
title-font: "DejaVu Sans Bold 18"

message-font: "DejaVu Sans 14"
message-color: "#ffffff"

terminal-font: "DejaVu Sans Mono 14"
terminal-color: "#ffffff"

desktop-image: "background.png"
desktop-color: "#1a1a2e"

+ boot_menu {
    left = 30%
    top = 25%
    width = 40%
    height = 50%

    item_font = "DejaVu Sans 14"
    item_color = "#ffffff"
    selected_item_font = "DejaVu Sans Bold 14"
    selected_item_color = "#00ff00"

    item_height = 24
    item_spacing = 16

    menu_pixmap_style = "boot_menu.*"
}
EOF

    # Create background image (placeholder)
    if command -v convert &>/dev/null; then
        convert -size 1920x1080 xc:"#1a1a2e" "${theme_dir}/background.png"
    fi
}

# Install GRUB
install_grub() {
    local disk="$1"
    local mount_point="${2:-/mnt}"

    echo "Installing GRUB bootloader..."

    # Detect EFI or BIOS
    if [[ -d "/sys/firmware/efi" ]]; then
        install_grub_efi "$disk" "$mount_point" "x86_64-efi"
    else
        install_grub_bios "$disk" "$mount_point"
    fi

    # Create theme
    create_grub_theme "$mount_point"

    echo "GRUB installation complete."
}
