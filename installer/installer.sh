#!/bin/bash
# MoonOS Installer - Main Installation Script
# Version: 1.0.0

set -euo pipefail

INSTALLER_VERSION="1.0.0"
INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source installer modules
source "${INSTALLER_ROOT}/lib/interactive.sh"
source "${INSTALLER_ROOT}/lib/partition.sh"
source "${INSTALLER_ROOT}/lib/system.sh"
source "${INSTALLER_ROOT}/lib/bootloader.sh"
source "${INSTALLER_ROOT}/lib/configure.sh"
source "${INSTALLER_ROOT}/lib/locale.sh"

# Installation state
declare -A INSTALL_CONFIG=(
    [target_disk]=""
    [hostname]="moonos"
    [timezone]="UTC"
    [locale]="en_US.UTF-8"
    [keyboard]="us"
    [root_password]=""
    [username]=""
    [user_password]=""
    [desktop]="none"
    [packages]="base"
)

usage() {
    cat << EOF
MoonOS Installer v${INSTALLER_VERSION}

Usage: moonos-installer [options]

Options:
    --interactive       Run interactive installer (default)
    --auto              Run automated installation
    --config=<file>     Use configuration file
    --disk=<disk>       Target disk (e.g., /dev/sda)
    --hostname=<name>   System hostname
    --timezone=<tz>     System timezone
    --locale=<locale>   System locale
    --user=<user>       Create user account
    --help              Show this help

Examples:
    # Interactive installation
    moonos-installer

    # Automated installation
    moonos-installer --auto --disk=/dev/sda --hostname=myserver

    # Use configuration file
    moonos-installer --config=/path/to/install.conf

EOF
    exit 0
}

main() {
    local mode="interactive"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interactive)
                mode="interactive"
                shift
                ;;
            --auto)
                mode="auto"
                shift
                ;;
            --config=*)
                INSTALL_CONFIG[config_file]="${1#*=}"
                shift
                ;;
            --disk=*)
                INSTALL_CONFIG[target_disk]="${1#*=}"
                shift
                ;;
            --hostname=*)
                INSTALL_CONFIG[hostname]="${1#*=}"
                shift
                ;;
            --timezone=*)
                INSTALL_CONFIG[timezone]="${1#*=}"
                shift
                ;;
            --locale=*)
                INSTALL_CONFIG[locale]="${1#*=}"
                shift
                ;;
            --user=*)
                INSTALL_CONFIG[username]="${1#*=}"
                shift
                ;;
            --desktop=*)
                INSTALL_CONFIG[desktop]="${1#*=}"
                shift
                ;;
            --packages=*)
                INSTALL_CONFIG[packages]="${1#*=}"
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Run installer
    case "$mode" in
        interactive)
            interactive_install
            ;;
        auto)
            automated_install
            ;;
    esac
}

# Interactive installation
interactive_install() {
    echo "=========================================="
    echo "  MoonOS Installer v${INSTALLER_VERSION}"
    echo "=========================================="
    echo ""
    echo "Welcome to MoonOS!"
    echo "This installer will guide you through the installation process."
    echo ""

    # Select target disk
    select_disk

    # Configure system
    configure_hostname
    configure_timezone
    configure_locale
    configure_keyboard

    # Create user
    create_user

    # Select desktop
    select_desktop

    # Confirm installation
    confirm_install

    # Run installation
    perform_installation
}

# Automated installation
automated_install() {
    echo "=========================================="
    echo "  MoonOS Automated Installer v${INSTALLER_VERSION}"
    echo "=========================================="
    echo ""

    # Validate configuration
    if [[ -z "${INSTALL_CONFIG[target_disk]}" ]]; then
        echo "Error: Target disk not specified"
        echo "Use --disk=<device> to specify target disk"
        exit 1
    fi

    # Run installation
    perform_installation
}

# Perform the actual installation
perform_installation() {
    local disk="${INSTALL_CONFIG[target_disk]}"

    echo ""
    echo "Installing MoonOS to ${disk}..."
    echo ""

    # Step 1: Partition disk
    step_partition_disk "$disk"

    # Step 2: Format partitions
    step_format_partitions "$disk"

    # Step 3: Mount partitions
    step_mount_partitions "$disk"

    # Step 4: Install system
    step_install_system

    # Step 5: Configure system
    step_configure_system

    # Step 6: Install bootloader
    step_install_bootloader "$disk"

    # Step 7: Cleanup
    step_cleanup

    echo ""
    echo "=========================================="
    echo "  Installation Complete!"
    echo "=========================================="
    echo ""
    echo "MoonOS has been installed successfully."
    echo "Please remove the installation media and reboot."
    echo ""
    echo "Press Enter to reboot or Ctrl+C to exit..."
    read -r
    reboot
}

# Installation steps
step_partition_disk() {
    local disk="$1"

    echo "Step 1/7: Partitioning disk..."

    # Create GPT partition table
    parted -s "$disk" mklabel gpt

    # Create partitions
    parted -s "$disk" mkpart primary fat32 1MiB 512MiB
    parted -s "$disk" mkpart primary ext4 512MiB 100%
    parted -s "$disk" set 1 boot on

    echo "Partitioning complete."
}

step_format_partitions() {
    local disk="$1"

    echo "Step 2/7: Formatting partitions..."

    # Format EFI partition
    mkfs.fat -F32 "${disk}1"

    # Format root partition
    mkfs.ext4 -F -L "moonos" "${disk}2"

    echo "Formatting complete."
}

step_mount_partitions() {
    local disk="$1"

    echo "Step 3/7: Mounting partitions..."

    # Create mount point
    mkdir -p /mnt

    # Mount root partition
    mount "${disk}2" /mnt

    # Create and mount EFI partition
    mkdir -p /mnt/boot/efi
    mount "${disk}1" /mnt/boot/efi

    echo "Mounting complete."
}

step_install_system() {
    echo "Step 4/7: Installing system..."

    # Extract rootfs
    if [[ -f /cdrom/rootfs.squashfs ]]; then
        unsquashfs -d /mnt /cdrom/rootfs.squashfs
    else
        echo "Error: rootfs.squashfs not found"
        exit 1
    fi

    echo "System installation complete."
}

step_configure_system() {
    echo "Step 5/7: Configuring system..."

    # Configure fstab
    configure_fstab

    # Configure hostname
    configure_hostname_system

    # Configure timezone
    configure_timezone_system

    # Configure locale
    configure_locale_system

    # Configure keyboard
    configure_keyboard_system

    # Set root password
    set_root_password

    # Create user account
    create_user_account

    echo "Configuration complete."
}

step_install_bootloader() {
    local disk="$1"

    echo "Step 6/7: Installing bootloader..."

    # Install GRUB
    grub-install \
        --target=x86_64-efi \
        --efi-directory=/mnt/boot/efi \
        --boot-directory=/mnt/boot \
        --removable \
        --recheck

    # Generate GRUB config
    grub-mkconfig -o /mnt/boot/grub/grub.cfg

    echo "Bootloader installation complete."
}

step_cleanup() {
    echo "Step 7/7: Cleaning up..."

    # Unmount partitions
    umount /mnt/boot/efi
    umount /mnt

    echo "Cleanup complete."
}

main "$@"
